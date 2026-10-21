#!/usr/bin/env bash
# Report upstream drift for each forked skill in upstream.json: how the whole
# upstream skill folder changed between the entry's base commit and upstream HEAD.
#
#   scripts/upstream-drift.sh [--json]
#
# Prints one line per skill:
#
#   ok   <skill>
#   DRIFT <skill>: upstream <path> changed from <base> to <head>
#   MOVED <skill>: upstream <path> is now <new path> at <head>
#   GONE <skill>: upstream <path> no longer exists at <head>
#
# DRIFT and MOVED are followed by the changed (M), added (A) and deleted (D)
# files, relative to the skill folder. A move is found when a folder with the
# skill's name sits under another category at HEAD (in-progress/ to
# engineering/); a renamed skill shows as GONE.
#
# --json prints the same report as an array of {skill, skillPath, headPath,
# base, head, status, summary, files}: status is ok, drifted, moved or gone, and
# summary is the line's text after "<STATUS> <skill>: ".
#
# Exits 0 when nothing drifted, 1 when something did, and 2 on an error.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
manifest="$root/upstream.json"

die() {
  echo "upstream-drift: $*" >&2
  exit 2
}

json=false
case "${1:-}" in
  "") ;;
  --json) json=true ;;
  *) die "unknown argument: $1 (usage: upstream-drift.sh [--json])" ;;
esac

[ -f "$manifest" ] || die "no upstream.json at $root"
upstream="$(jq -r '.upstream // empty' "$manifest")" || die "can't read upstream.json"
[ -n "$upstream" ] || die "upstream.json names no upstream"
skills="$(jq -r '.skills | to_entries[] | [.key, (.value.skillPath // ""), (.value.base // "")] | @tsv' "$manifest")" ||
  die "can't read the skills from upstream.json"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git init --quiet "$work/upstream"
fetch() { git -C "$work/upstream" fetch --quiet --depth 1 "$upstream" "$1"; }

fetch HEAD || die "can't fetch $upstream"
head="$(git -C "$work/upstream" rev-parse FETCH_HEAD)"

# moved_to <skill path>: where a skill folder of the same name sits at upstream
# HEAD (skills/<category>/<name>), or nothing when there is none. A name found
# under two categories is an error: which one is the skill is a person's call.
moved_to() {
  local found
  found="$(git -C "$work/upstream" ls-tree -r --name-only "$head" -- skills |
    awk -F/ -v name="$(basename "$1")" \
      'NF == 4 && $3 == name && $4 == "SKILL.md" { print $1 "/" $2 "/" $3 }')"
  [ "$(grep -c . <<<"$found" || true)" -le 1 ] ||
    die "$1 moved, and its name is now in several places: $(tr '\n' ' ' <<<"$found")"
  echo "$found"
}

# drift <name> <skill path> <base>: the skill's report, as one JSON object.
drift() {
  local name="$1" skill_path="$2" base="$3" head_path="$2" status files=""
  git -C "$work/upstream" cat-file -e "$base:$skill_path" 2>/dev/null ||
    die "$name's skillPath $skill_path doesn't exist at its base ${base:0:7}"
  if ! git -C "$work/upstream" cat-file -e "$head:$skill_path" 2>/dev/null; then
    head_path="$(moved_to "$skill_path")"
  fi
  if [ -z "$head_path" ]; then
    status=gone
  else
    files="$(git -C "$work/upstream" diff --name-status --no-renames "$base:$skill_path" "$head:$head_path")"
    if [ "$head_path" != "$skill_path" ]; then
      status=moved
    elif [ -n "$files" ]; then
      status=drifted
    else
      status=ok
    fi
  fi
  jq -n --arg skill "$name" --arg skillPath "$skill_path" --arg headPath "$head_path" \
    --arg base "$base" --arg head "$head" --arg status "$status" --arg files "$files" '
    {skill: $skill, skillPath: $skillPath, headPath: (if $headPath == "" then null else $headPath end),
     base: $base, head: $head, status: $status,
     summary: (
       if $status == "drifted" then "upstream \($skillPath) changed from \($base[0:7]) to \($head[0:7])"
       elif $status == "moved" then "upstream \($skillPath) is now \($headPath) at \($head[0:7])"
       elif $status == "gone" then "upstream \($skillPath) no longer exists at \($head[0:7])"
       else null end),
     files: [$files | splits("\n") | select(. != "") | split("\t") | {status: .[0], path: .[1]}]}'
}

reports="$work/reports.json"
: >"$reports"
while IFS=$'\t' read -r name skill_path base; do
  [ -n "$name" ] || continue
  [ -n "$skill_path" ] && [ -n "$base" ] || die "$name has no skillPath or base in upstream.json"
  fetch "$base" || die "can't fetch $name's base $base"
  drift "$name" "$skill_path" "$base" >>"$reports"
done <<<"$skills"

if $json; then
  jq -s . "$reports"
else
  jq -r '
    if .status == "ok" then "ok   \(.skill)"
    else "\({drifted: "DRIFT", moved: "MOVED", gone: "GONE"}[.status]) \(.skill): \(.summary)"
    end,
    (.files[] | "  \(.status)\t\(.path)")
  ' "$reports"
fi

if jq -se 'all(.status == "ok")' "$reports" >/dev/null; then exit 0; else exit 1; fi

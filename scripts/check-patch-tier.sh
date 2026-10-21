#!/usr/bin/env bash
# Check that each patch-tier skill in upstream.json differs from upstream only
# in its listed edits.
#
# For each patch entry, the skill folder is taken from upstream at the entry's
# base commit, each edit's line is swapped from "from" to "to", and the result
# must match the repo's copy exactly: same files, same bytes. A sync that bumps
# a base must update the edits' line and from to match the new upstream.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
manifest="$root/upstream.json"

die() {
  echo "check-patch-tier: $*" >&2
  exit 1
}

[ -f "$manifest" ] || die "no upstream.json at $root"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

upstream="$(jq -r '.upstream' "$manifest")"
git init --quiet "$work/upstream"

# apply_edit <file> <line> <from> <to>: swap one line, after checking it reads <from>.
apply_edit() {
  local actual
  actual="$(sed -n "$2p" "$1")"
  if [ "$actual" != "$3" ]; then
    echo "  line $2 of upstream $(basename "$1") doesn't match the edit's from:" >&2
    echo "    expected: $3" >&2
    echo "    actual:   $actual" >&2
    return 1
  fi
  # perl keeps the line's own newline, so a file without a final one stays so.
  LINE="$2" TO="$4" perl -pi -e 'if ($. == $ENV{LINE}) { $_ = $ENV{TO} . (/\n\z/ ? "\n" : "") }' "$1"
}

# check_skill <name>: 0 when the repo copy matches upstream plus its edits.
# Runs as an if condition, where set -e is off, so every step checks itself.
check_skill() {
  local name="$1" entry skill_path base extract_dir expected edit
  entry="$(jq -c --arg name "$name" '.skills[$name]' "$manifest")"
  skill_path="$(jq -r '.skillPath' <<<"$entry")"
  base="$(jq -r '.base' <<<"$entry")"
  jq -e '.edits | type == "array" and length > 0' <<<"$entry" >/dev/null || {
    echo "  no edits listed" >&2
    return 1
  }

  git -C "$work/upstream" fetch --quiet --depth 1 "$upstream" "$base" || return 1
  extract_dir="$work/expected/$name"
  mkdir -p "$extract_dir"
  git -C "$work/upstream" archive "$base" "$skill_path" | tar -x -C "$extract_dir" || return 1
  expected="$extract_dir/$skill_path"

  while IFS= read -r edit; do
    apply_edit "$expected/$(jq -r '.file' <<<"$edit")" \
      "$(jq -r '.line' <<<"$edit")" \
      "$(jq -r '.from' <<<"$edit")" \
      "$(jq -r '.to' <<<"$edit")" || return 1
  done < <(jq -c '.edits[]' <<<"$entry")

  diff -r "$expected" "$root/$skill_path" | sed 's/^/  /'
  return "${PIPESTATUS[0]}"
}

status=0
while IFS= read -r name; do
  if out="$(check_skill "$name" 2>&1)"; then
    echo "ok   $name"
  else
    echo "FAIL $name differs from upstream beyond its listed edits:"
    echo "$out"
    status=1
  fi
done < <(jq -r '.skills | to_entries[] | select(.value.tier == "patch") | .key' "$manifest")
exit "$status"

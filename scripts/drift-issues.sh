#!/usr/bin/env bash
# Keep one open needs-triage issue per drifted skill, from a drift report.
#
#   scripts/upstream-drift.sh --json >drift.json
#   scripts/drift-issues.sh drift.json
#
# A skill that drifted, moved or is gone gets a needs-triage issue titled
# "Upstream drift: <skill>". Its report sits between two markers in the body.
# When an open issue already carries the skill's start marker, whatever its
# labels after triage, only that report section is replaced, so anything people
# wrote around it stays. Skills that are ok are left alone: closing a drift issue
# is the sync commit's job. Needs gh, authenticated for this repo.
set -euo pipefail

die() {
  echo "drift-issues: $*" >&2
  exit 1
}

[ $# -eq 1 ] || die "usage: drift-issues.sh <drift report json>"
report="$1"
[ -f "$report" ] || die "no drift report at $report"
jq -e 'type == "array"' "$report" >/dev/null 2>&1 || die "$report is not a drift report (a JSON array)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# marker <skill>: the hidden line that ties an issue to its skill and starts its report.
marker() { echo "<!-- upstream-drift: $1 -->"; }
end_marker='<!-- end of upstream drift report -->'

# report_section <skill>: one skill's report, between its markers.
report_section() {
  marker "$1"
  jq -r --arg skill "$1" '
    .[] | select(.skill == $skill) |
    "**\({drifted: "Drifted", moved: "Moved", gone: "Gone"}[.status]):** \(.summary).",
    "",
    (if (.files | length) > 0 then
      "| | File |", "|---|---|", (.files[] | "| \(.status) | `\(.path)` |"), ""
    else empty end),
    "Sync by hand as described in `CONTRIBUTING.md`, then close this issue from the `sync(\(.skill)): upstream <short-sha>` commit.",
    "",
    "_Updated by the weekly upstream drift check._"
  ' "$report"
  echo "$end_marker"
}

# replace_section <body file> <section file> <skill>: the body with the skill's
# report section swapped for the new one. A start marker without an end marker
# is replaced to the end of the body.
replace_section() {
  START="$(marker "$3")" END="$end_marker" SECTION="$(cat "$2")" perl -0777 -pe '
    my ($start, $end) = (quotemeta $ENV{START}, quotemeta $ENV{END});
    s/$start.*?(?:$end|\z)/$ENV{SECTION}/s;
  ' "$1"
}

open_issues="$(gh issue list --state open --limit 1000 --json number,title,body)" ||
  die "can't list open issues"

while IFS= read -r skill; do
  [ -n "$skill" ] || continue
  section="$work/$skill.section.md"
  body="$work/$skill.md"
  report_section "$skill" >"$section"
  number="$(jq -r --arg marker "$(marker "$skill")" \
    'first(.[] | select(.body | contains($marker)) | .number) // empty' <<<"$open_issues")"
  if [ -n "$number" ]; then
    jq -r --argjson number "$number" '.[] | select(.number == $number) | .body' <<<"$open_issues" >"$work/current.md"
    replace_section "$work/current.md" "$section" "$skill" >"$body"
    gh issue edit "$number" --body-file "$body" >/dev/null
    echo "updated #$number for $skill"
  else
    cp "$section" "$body"
    url="$(gh issue create --title "Upstream drift: $skill" --label needs-triage --body-file "$body")"
    echo "opened $url for $skill"
  fi
done < <(jq -r '.[] | select(.status != "ok") | .skill' "$report")

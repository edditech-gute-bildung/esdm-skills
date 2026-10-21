#!/usr/bin/env bash
# drift-issues.sh, run against a stub gh that keeps issues in a JSON file.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The stub gh: issue list, create and edit, on $GH_STUB_ISSUES. It honours
# --state open and --label, like the real list does.
mkdir -p "$work/bin"
cat >"$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
issues="$GH_STUB_ISSUES"
[ "$1" = issue ] || { echo "stub gh: unsupported: $*" >&2; exit 1; }
action="$2"
shift 2
title="" label="" body_file="" state="" number=""
while [ $# -gt 0 ]; do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --label) label="$2"; shift 2 ;;
    --body-file) body_file="$2"; shift 2 ;;
    --state) state="$2"; shift 2 ;;
    --json | --limit) shift 2 ;;
    *) number="$1"; shift ;;
  esac
done
case "$action" in
  list)
    jq --arg state "$state" --arg label "$label" '
      [.[] | select(($state == "" or .state == $state) and ($label == "" or (.labels | index($label))))
       | {number, title, body}]' "$issues"
    ;;
  create)
    jq --arg title "$title" --arg label "$label" --rawfile body "$body_file" '
      . + [{number: (length + 1), title: $title, body: $body, state: "open", labels: [$label]}]' \
      "$issues" >"$issues.new" && mv "$issues.new" "$issues"
    echo "https://github.com/example/repo/issues/$(jq length "$issues")"
    ;;
  edit)
    jq --argjson number "$number" --rawfile body "$body_file" '
      map(if .number == $number then .body = $body else . end)' \
      "$issues" >"$issues.new" && mv "$issues.new" "$issues"
    ;;
  *) echo "stub gh: unsupported: issue $action" >&2; exit 1 ;;
esac
STUB
chmod +x "$work/bin/gh"

# report <file> <status of demo> [file status and path of demo...]: a drift
# report as upstream-drift.sh --json writes it, with demo in the given status
# and other ok.
report() {
  local file="$1" status="$2"
  shift 2
  jq -n --arg status "$status" --args '
    [{skill: "demo",
      skillPath: (if $status == "moved" then "skills/in-progress/demo" else "skills/engineering/demo" end),
      headPath: (if $status == "gone" then null else "skills/engineering/demo" end),
      base: ("a" * 40), head: ("b" * 40), status: $status,
      summary: {
        drifted: "upstream skills/engineering/demo changed from aaaaaaa to bbbbbbb",
        moved: "upstream skills/in-progress/demo is now skills/engineering/demo at bbbbbbb",
        gone: "upstream skills/engineering/demo no longer exists at bbbbbbb",
        ok: null
      }[$status],
      files: [$ARGS.positional | _nwise(2) | {status: .[0], path: .[1]}]},
     {skill: "other", skillPath: "skills/engineering/other", headPath: "skills/engineering/other",
      base: ("a" * 40), head: ("a" * 40), status: "ok", files: []}]' "$@" >"$file"
}

# new_issues <json>: a fresh stub issue store holding <json>.
new_issues() {
  export GH_STUB_ISSUES="$work/issues.json"
  echo "$1" >"$GH_STUB_ISSUES"
}

# run_sync <report>: drift-issues.sh on the report, with the stub gh first on PATH.
run_sync() {
  PATH="$work/bin:$PATH" bash "$REPO_ROOT/scripts/drift-issues.sh" "$1" >"$work/out.log" 2>&1
}

# issue_count: how many issues the stub holds, open or closed.
issue_count() { jq length "$GH_STUB_ISSUES"; }
# stored_body <number>: the body of the stub's issue <number>.
stored_body() { jq -r --argjson n "$1" '.[] | select(.number == $n) | .body' "$GH_STUB_ISSUES"; }

new_issues '[]'
report "$work/first.json" drifted M SKILL.md A NEW.md
check "the first run succeeds" run_sync "$work/first.json"
check "opens one issue, for the drifted skill only" test "$(issue_count)" -eq 1
check "labels it needs-triage" \
  test "$(jq -r '.[0].labels[0]' "$GH_STUB_ISSUES")" = needs-triage
check "titles it after the skill" test "$(jq -r '.[0].title' "$GH_STUB_ISSUES")" = "Upstream drift: demo"
check "lists the drifted files in the body" bash -c 'grep -q "NEW.md" <<<"$0"' "$(stored_body 1)"

report "$work/second.json" drifted M SKILL.md A NEW.md A LATER.md
check "a second run succeeds" run_sync "$work/second.json"
check "a second run opens no duplicate" test "$(issue_count)" -eq 1
check "a second run updates the existing issue" bash -c 'grep -q "LATER.md" <<<"$0"' "$(stored_body 1)"

new_issues '[]'
report "$work/drift.json" drifted M SKILL.md
run_sync "$work/drift.json"
jq 'map(.labels = ["ready-for-human"])' "$GH_STUB_ISSUES" >"$GH_STUB_ISSUES.new" && mv "$GH_STUB_ISSUES.new" "$GH_STUB_ISSUES"
report "$work/drift.json" drifted M SKILL.md A LATER.md
run_sync "$work/drift.json"
check "updates a drift issue that was triaged away from needs-triage" \
  bash -c 'test "$1" -eq 1 && grep -q LATER.md <<<"$2"' _ "$(issue_count)" "$(stored_body 1)"

new_issues '[]'
report "$work/drift.json" drifted M SKILL.md
run_sync "$work/drift.json"
jq 'map(.body = "Triage note: sync after the ESDM release.\n\n" + .body + "\nKeep the hold-on rule.")' \
  "$GH_STUB_ISSUES" >"$GH_STUB_ISSUES.new" && mv "$GH_STUB_ISSUES.new" "$GH_STUB_ISSUES"
report "$work/drift.json" drifted M SKILL.md A LATER.md
run_sync "$work/drift.json"
check "keeps what people wrote around the report" \
  bash -c 'grep -q "Triage note" <<<"$0" && grep -q "hold-on rule" <<<"$0"' "$(stored_body 1)"
check "replaces the report itself" \
  bash -c 'grep -q LATER.md <<<"$0" && test "$(grep -c "upstream-drift: demo" <<<"$0")" -eq 1' "$(stored_body 1)"

new_issues '[{"number": 1, "title": "Something else", "body": "Unrelated.", "state": "open", "labels": ["needs-triage"]}]'
report "$work/drift.json" drifted M SKILL.md
run_sync "$work/drift.json"
check "leaves other needs-triage issues alone" test "$(stored_body 1)" = "Unrelated."
check "opens the drift issue next to them" test "$(issue_count)" -eq 2

new_issues '[]'
report "$work/drift.json" drifted M SKILL.md
run_sync "$work/drift.json"
jq 'map(.state = "closed")' "$GH_STUB_ISSUES" >"$GH_STUB_ISSUES.new" && mv "$GH_STUB_ISSUES.new" "$GH_STUB_ISSUES"
run_sync "$work/drift.json"
check "opens a new issue once the old one is closed" test "$(issue_count)" -eq 2

new_issues '[]'
report "$work/moved.json" moved
run_sync "$work/moved.json"
check "opens an issue for a moved skill, saying where it went" \
  bash -c 'grep -q "skills/engineering/demo" <<<"$0" && grep -qi "moved" <<<"$0"' "$(stored_body 1)"

new_issues '[]'
report "$work/ok.json" ok
check "a run with nothing drifted succeeds" run_sync "$work/ok.json"
check "opens no issue when nothing drifted" test "$(issue_count)" -eq 0

new_issues '[]'
printf '{"skills":' >"$work/broken.json"
check_fails "fails on a report that isn't a JSON array" run_sync "$work/broken.json"

finish

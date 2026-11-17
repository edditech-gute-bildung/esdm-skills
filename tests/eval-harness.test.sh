#!/usr/bin/env bash
# The behavioural eval harness in tests/eval/, driven with a fake claude
# (EVAL_CLAUDE) so no agent runs: the scratch repo it builds, the runs it
# repeats, the threshold it applies and the artefacts it keeps. Needs network:
# it fetches the fixture, esdm and the companion skills.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

eval_dir="$REPO_ROOT/tests/eval"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The fake claude records its arguments and environment, then writes a report
# into $TMPDIR as the skill would. The runs listed in $work/passing (one number
# per line) write a report that finds the planted defects; the others don't.
mkdir -p "$work/bin"
cat >"$work/bin/claude" <<'FAKE'
#!/usr/bin/env bash
count_file="$FAKE_STATE/count"
run=$(( $(cat "$count_file" 2>/dev/null || echo 0) + 1 ))
echo "$run" >"$count_file"
printf '%s\n' "$@" >"$FAKE_STATE/args-$run"
pwd >"$FAKE_STATE/cwd-$run"
command -v open >"$FAKE_STATE/open-$run"
echo "edited by the agent" >>package.json
if grep -qx "$run" "$FAKE_STATE/passing"; then
  body='<p>src/lending/returning.js: Unit cut across the copy module.</p>
<p>Reaction without a module: placeHold instead of the hold-for-next-in-line Policy.</p>
<p>Code ahead of model: damage-reported.</p>'
else
  body='<p>All good.</p>'
fi
echo "<html>$body</html>" >"$TMPDIR/architecture-review-1.html"
echo '{"type":"system","subtype":"init"}'
printf '{"type":"result","subtype":"success","result":"Report at %s"}\n' "$TMPDIR/architecture-review-1.html"
FAKE
chmod +x "$work/bin/claude"

# harness <name> <passing runs...>: runs the improve-codebase-architecture eval
# with the fake, into $work/<name>; its output lands in $work/<name>.log.
harness() {
  local name="$1"
  shift
  mkdir -p "$work/$name/state"
  printf '%s\n' "$@" >"$work/$name/state/passing"
  FAKE_STATE="$work/$name/state" EVAL_CLAUDE="$work/bin/claude" EVAL_OUT="$work/$name/out" \
    bash "$eval_dir/run.sh" improve-codebase-architecture >"$work/$name.log" 2>&1
}

check "2 of 3 passing runs pass the eval" harness two 1 3
check "the eval runs 3 times" test "$(cat "$work/two/state/count")" = 3
check "each run is reported" grep -qE 'run 2: FAIL' "$work/two.log"
check "the overall result is reported" grep -qE 'improve-codebase-architecture: PASS \(2/3\)' "$work/two.log"
check "the output dir is printed" grep -qF "$work/two/out" "$work/two.log"

check_fails "1 of 3 passing runs fails the eval" harness one 2
check "the overall failure is reported" grep -qE 'improve-codebase-architecture: FAIL \(1/3\)' "$work/one.log"

run1="$work/two/out/improve-codebase-architecture/run-1"
check "the transcript is kept" grep -q '"type":"result"' "$run1/transcript.jsonl"
check "the diff is kept" grep -qF '+edited by the agent' "$run1/diff.patch"
check "the report is kept" grep -qF 'returning.js' "$run1/tmp/architecture-review-1.html"

repo="$(cat "$work/two/state/cwd-1")"
in_scratch_repo() { [ "$repo" = "$run1/repo" ] || [ "$repo" = "$(cd "$run1/repo" && pwd -P)" ]; }
check "claude runs in the run's scratch repo" in_scratch_repo
check "the scratch repo is its own git repo" test -d "$run1/repo/.git"
check "the scratch repo holds the fixture's model" test -f "$run1/repo/model/domain.esdm.yaml"
check "the scratch repo holds the fixture's GLOSSARY.md" test -f "$run1/repo/GLOSSARY.md"
check "the scratch repo holds the sample" test -f "$run1/repo/src/lending/returning.js"
check_fails "the scratch repo leaves out the sample's README, which names the defects" test -e "$run1/repo/README.md"
check "domain.md names model/ as the model dir" grep -qF '`model/`' "$run1/repo/docs/agents/domain.md"
check "the pinned esdm is installed" quietly "$run1/repo/.tools/esdm" version
check "the forks are installed from the working tree" \
  diff -r "$REPO_ROOT/skills/engineering/improve-codebase-architecture" "$run1/repo/.claude/skills/improve-codebase-architecture"
check "the codebase-design companion is installed" test -f "$run1/repo/.claude/skills/codebase-design/SKILL.md"
check "the grilling companion is installed" test -f "$run1/repo/.claude/skills/grilling/SKILL.md"
check "the scratch repo lies outside this repo" test "${repo#"$REPO_ROOT"}" = "$repo"

args="$work/two/state/args-1"
check "claude runs headless" grep -qx -- '-p' "$args"
check "the prompt invokes the skill with the preamble" \
  grep -qE '^/improve-codebase-architecture Non-interactive run: wherever you would ask, take your recommended answer and note it\.' "$args"
check "the model is pinned" grep -qx 'claude-sonnet-5-5' "$args"
check "permissions are bypassed" grep -qx 'bypassPermissions' "$args"
check "the transcript is stream-json" grep -qx 'stream-json' "$args"
check "turns are capped" grep -qx -- '--max-turns' "$args"
check "the budget is capped" grep -qx -- '--max-budget-usd' "$args"
check "open is stubbed out" grep -qF "$work/two/out" "$work/two/state/open-1"

check "tests/run.sh doesn't run the evals" test -z "$(find "$REPO_ROOT/tests" -maxdepth 1 -name '*.eval.sh')"
check "the evals don't match tests/run.sh's glob" test -z "$(find "$eval_dir" -name '*.test.sh')"

finish

#!/usr/bin/env bash
# The judge of tests/eval/tdd.eval.sh, driven with a fake claude (EVAL_CLAUDE)
# that leaves the scratch repo as a run of each kind would. Needs network, node
# and ruby: it fetches the fixture, esdm and the companion skills.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The fake claude changes the scratch repo as $FAKE_MODE says: a test for the
# Scenario under its esdm: comment and the code that passes it, then one thing
# wrong.
mkdir -p "$work/bin"
cat >"$work/bin/claude" <<'FAKE'
#!/usr/bin/env bash
REFERENCE='esdm:domain=library/bounded-context=lending/aggregate=copy/feature=borrowing-a-copy'
SCENARIO='reminding-about-a-returned-copy-does-nothing'

# add_test <reference> <scenario> [<test name>]: appends the Scenario's test,
# named after the Scenario unless <test name> says otherwise.
add_test() {
  cat >>test/lending/copy.test.js <<JS

// $1 scenario=$2
test('${3:-$2}', () => {
  const history = [
    { type: 'stocked', data: { 'copy-id': '11111111-1111-1111-1111-111111111111', isbn: '978-0201616224' } },
    {
      type: 'borrowed',
      data: {
        'copy-id': '11111111-1111-1111-1111-111111111111',
        isbn: '978-0201616224',
        borrower: 'card-4711',
        'due-on': '2026-09-14',
      },
    },
    {
      type: 'returned',
      data: { 'copy-id': '11111111-1111-1111-1111-111111111111', isbn: '978-0201616224', 'returned-on': '2026-09-10' },
    },
  ];

  const events = decide(
    { type: 'remind', data: { 'copy-id': '11111111-1111-1111-1111-111111111111', 'final-reminder': false } },
    history,
  );

  assert.deepEqual(events, []);
});
JS
}
# implement: decide accepts remind and emits nothing.
implement() {
  perl -0pi -e "s/    default:\n      throw/    case 'remind':\n      return [];\n    default:\n      throw/" src/lending/copy.js
}

# add_scenario: a new Scenario at the end of borrowing-a-copy.
add_scenario() {
  cat >>model/lending/borrowing-a-copy.feature.esdm.yaml <<YAML

  - name: reminding-about-a-copy-never-lent-does-nothing
    given:
      - event: stocked
        data:
          copy-id: 11111111-1111-1111-1111-111111111111
          isbn: "978-0201616224"
    when:
      command: remind
      data:
        copy-id: 11111111-1111-1111-1111-111111111111
        final-reminder: false
      actor: overdue-scheduler
    then:
      events: []
YAML
}

case "$FAKE_MODE" in
  pass) add_test "$REFERENCE" "$SCENARIO"; implement ;;
  added) add_test "$REFERENCE" "$SCENARIO"; implement; add_scenario ;;
  red) add_test "$REFERENCE" "$SCENARIO" ;;
  nothing) implement ;;
  misnamed) add_test "$REFERENCE" "$SCENARIO" 'reminding after return does nothing'; implement ;;
  other) add_test "$REFERENCE" returning-late-incurs-a-fee; implement ;;
  feature) add_test "${REFERENCE%/feature=*}/feature=lending-a-copy" "$SCENARIO"; implement ;;
  edited) add_test "$REFERENCE" "$SCENARIO"; implement
    perl -0pi -e 's/returned-on: "2026-07-30"/returned-on: "2026-08-01"/' model/lending/borrowing-a-copy.feature.esdm.yaml ;;
esac
echo '{"type":"result","subtype":"success","result":"Done."}'
FAKE
chmod +x "$work/bin/claude"

# eval_with <mode>: one run of the tdd eval with the fake in <mode>, its output
# in $work/<mode>.log; passes when the eval does. The runs share one output
# dir, so the fixture is fetched once.
eval_with() {
  rm -rf "$work/out/tdd"
  FAKE_MODE="$1" EVAL_RUNS=1 EVAL_PASS=1 EVAL_CLAUDE="$work/bin/claude" EVAL_OUT="$work/out" \
    bash "$REPO_ROOT/tests/eval/run.sh" tdd >"$work/$1.log" 2>&1
}

# fails_on <mode> <check>: the eval fails with the fake in <mode>, at <check>.
fails_on() {
  ! eval_with "$1" && grep -qF "FAIL $2" "$work/$1.log"
}

check "a passing test for the Scenario under its esdm: comment passes" eval_with pass
check "a Scenario added to the Feature passes" eval_with added
check "a failing test fails" fails_on red 'node --test passes'
check "a run that adds no test fails" fails_on nothing 'a test for reminding-about-a-returned-copy-does-nothing'
check "a test not named after the Scenario fails" fails_on misnamed 'a test for reminding-about-a-returned-copy-does-nothing'
check "a test for another Scenario fails" fails_on other 'a test for reminding-about-a-returned-copy-does-nothing'
check "a reference to a Feature the model lacks fails" fails_on feature 'a test for reminding-about-a-returned-copy-does-nothing'
check "an edited Scenario fails" fails_on edited 'no Scenario of the fixture was edited'

finish

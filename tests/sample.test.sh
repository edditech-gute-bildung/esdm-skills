#!/usr/bin/env bash
# The sample codebase dry runs use: its tests pass, and each esdm: test comment
# names a Scenario in the fixture and sits right above the test named after it,
# as the tdd skill writes them. Needs network, node and ruby.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

sample="$REPO_ROOT/sample"

# sample_tests_pass: node's test runner passes in the sample.
sample_tests_pass() { (cd "$sample" && node --test >/dev/null); }
check "the sample's tests pass" sample_tests_pass

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

check "the pinned fixture is fetched" fetch_fixture "$work/root"
model="$work/root/.fixture/model"

# Each esdm: comment in the sample's tests, as "<file>:<line>\t<reference>\t<scenario>\t<next line>".
comments() {
  find "$sample/test" -name '*.test.js' -print0 | xargs -0 awk '
    pending { print pending "\t" $0; pending = "" }
    match($0, /esdm:[^ ]+ scenario=[^ ]+/) {
      split(substr($0, RSTART, RLENGTH), parts, " scenario=")
      pending = FILENAME ":" FNR "\t" parts[1] "\t" parts[2]
    }
  '
}

# named_after <scenario> <line>: the line opens a test named after the Scenario.
named_after() { grep -qF "test('$1'," <<<"$2"; }

count=0
while IFS=$'\t' read -r at reference scenario next; do
  count=$((count + 1))
  where="${at#"$REPO_ROOT"/}"
  check "$where names a fixture Scenario" scenario_in_model "$model" "$reference" "$scenario"
  check "$where sits above the test named after $scenario" named_after "$scenario" "$next"
done < <(comments)
check "the sample's tests carry esdm: comments" test "$count" -gt 0

check_fails "a test named differently from its Scenario is caught" \
  named_after available-copy-can-be-borrowed "test('borrowing works', () => {"

finish

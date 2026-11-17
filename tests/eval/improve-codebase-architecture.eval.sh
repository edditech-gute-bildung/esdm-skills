#!/usr/bin/env bash
# /improve-codebase-architecture on the sample. Passes when the report names
# src/lending/returning.js and at least 2 of the 3 defects planted there (see
# sample/README.md, which the scratch repo leaves out). Each defect needs its
# term and its finding on one line, so a passing mention doesn't count.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

judge() {
  local report found=0
  report="$(report_text "$1")"
  expect "an HTML report was written" test -n "$(find "$1/tmp" -name '*.html' 2>/dev/null)" || return 1
  expect "the report names returning.js" grep -qF 'returning.js' <<<"$report" || return 1

  # copy's return handled outside copy.js
  expect "finds the return outside the copy module" \
    eval_line "$report" -iE 'unit cut across|command=return' -i 'copy' && found=$((found + 1))
  # a hold placed in returning instead of by the hold-for-next-in-line Policy
  expect "finds the inlined hold-for-next-in-line Policy" \
    eval_line "$report" -F 'hold-for-next-in-line' -iE 'reaction without a module|placeHold' && found=$((found + 1))
  # damage reported though the model doesn't know damage
  expect "finds the unmodeled damage report" \
    eval_line "$report" -i 'damage' \
    -iE "code ahead of model|not modell?ed|unmodell?ed|no model|model (doesn't|does not) know|no .*element" &&
    found=$((found + 1))

  expect "at least 2 of the 3 planted defects found ($found)" test "$found" -ge 2
}

# eval_line <text> <grep flags> <pattern> <grep flags> <pattern>: some line of
# <text> matches both patterns.
eval_line() {
  grep "$2" -- "$3" <<<"$1" | grep -q "$4" -- "$5"
}

run_scenario improve-codebase-architecture improve-codebase-architecture "Stop once the report is written."

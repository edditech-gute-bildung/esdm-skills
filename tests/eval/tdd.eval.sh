#!/usr/bin/env bash
# /tdd implements a fixture Scenario the sample has no test for yet. Passes when
# `node --test` passes in the sample, a test carries an esdm: comment that names
# the Scenario's Feature and the Scenario and sits right above the test named
# after it, and no Scenario the fixture has was edited (adding one is fine).
#
# The Scenario: of the fixture's Scenarios, the ones no esdm: comment in
# sample/test names are borrowing-a-copy's reminding-about-a-returned-copy-
# does-nothing, returning-on-time-incurs-no-fee and returning-late-incurs-a-fee,
# and every Scenario of availability, overdue-recovery and reservation-limit,
# whose units the sample doesn't have. The first of borrowing-a-copy's is the
# one the skill would pick itself, and it needs no clock.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

SCENARIO='reminding-about-a-returned-copy-does-nothing'

judge() {
  local repo="$1/repo"
  expect "node --test passes" quietly_in "$repo" node --test || return 1
  expect "a test for $SCENARIO sits under its esdm: comment" scenario_tested "$repo" || return 1
  expect "no Scenario of the fixture was edited" scenarios_kept "$repo" || return 1
}

# quietly_in <dir> <command...>: the command, run in <dir>, its stdout and
# stderr dropped.
quietly_in() { (cd "$1" && shift && "$@" >/dev/null 2>&1); }

# scenario_tested <repo>: some esdm: comment under test/ names $SCENARIO, its
# reference names the Feature in the model that has it, and the line below
# opens the test named after it.
scenario_tested() {
  local at reference scenario next
  while IFS=$'\t' read -r at reference scenario next; do
    [ "$scenario" = "$SCENARIO" ] &&
      scenario_in_model "$1/model" "$reference" "$scenario" &&
      named_after "$scenario" "$next" &&
      return 0
  done < <(esdm_comments "$1/test")
  return 1
}

# scenarios_kept <repo>: every Scenario of the fixture commit's Features is
# still in the model, unchanged, under the same Feature. The fixture commit is
# the root one, in case the run committed. Prints the ones that aren't.
scenarios_kept() {
  (
    cd "$1" || exit 1
    ruby -ryaml -e '
      def scenarios(texts)
        texts.flat_map { |text| YAML.load_stream(text).compact }
          .select { |doc| doc.is_a?(Hash) && doc["kind"] == "feature" }
          .flat_map do |doc|
            Array(doc["scenarios"]).map { |s| [[doc["scope"], doc["name"], s["name"]], s] }
          end.to_h
      end
      fixture = `git rev-list --max-parents=0 HEAD`.split.last
      files = `git ls-tree -r --name-only #{fixture} model/`.split("\n").grep(/\.feature\.esdm\.yaml$/)
      old = scenarios(files.map { |file| `git show #{fixture}:#{file}` })
      now = scenarios(Dir.glob("model/**/*.feature.esdm.yaml").map { |file| File.read(file) })
      changed = old.reject { |key, scenario| now[key] == scenario }
      changed.each_key { |scope, feature, name| puts "#{scope.inspect} #{feature}: #{name}" }
      exit(changed.empty? ? 0 : 1)
    '
  )
}

run_scenario tdd tdd "implement Scenario $SCENARIO"

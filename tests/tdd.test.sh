#!/usr/bin/env bash
# The rewrite-tier tdd skill: its files, its Scenario section, and the esdm:
# test comment it shows, which must name a real Feature and Scenario in the
# fixture. Needs network and ruby: it fetches the fixture.
# tests/upstream-manifest.test.sh checks the rest of the text against upstream.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

skill="$REPO_ROOT/skills/engineering/tdd"
skill_md="$skill/SKILL.md"

check "the skill holds upstream's files" \
  has_files "$skill" SKILL.md tests.md mocking.md agents/openai.yaml
check "every link in the skill resolves" links_resolve "$skill"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# dropped <name> <line>: a copy of SKILL.md without every line equal to <line>.
dropped() {
  mkdir -p "$work/$1"
  grep -vxF "$2" "$skill_md" >"$work/$1/SKILL.md"
  echo "$work/$1/SKILL.md"
}

# added <name> <line>: a copy of the skill with <line> appended to SKILL.md.
added() {
  cp -R "$skill" "$work/$1"
  printf '%s\n' "$2" >>"$work/$1/SKILL.md"
  echo "$work/$1"
}

section='## Scenarios: the agreed slices'
check "SKILL.md has the Scenario section" grep -qxF "$section" "$skill_md"

# seam_row <file> <variant>: the seam table has a row for the variant.
seam_row() { grep -qE "^\| *$2 *\|" "$1"; }
for variant in 'Aggregate / DCB' 'Process Manager' 'Read Model'; do
  check "the seam table covers $variant" seam_row "$skill_md" "$variant"
done
check_fails "a missing seam row is caught" \
  seam_row "$(dropped no-row "$(grep -E '^\| *Read Model *\|' "$skill_md")")" 'Read Model'

# scenario_wins <file>: the text says never to edit a Scenario to match the code.
scenario_wins() { grep -qF 'Never edit a Scenario to match the code.' "$1"; }
check "the text says never to edit a Scenario to match the code" scenario_wins "$skill_md"
check_fails "a missing guardrail is caught" \
  scenario_wins "$(dropped no-guardrail "$(grep -F 'Never edit a Scenario' "$skill_md")")"

check "a gap is proposed to domain-modeling" grep -qiF 'call the Skill tool with "domain-modeling"' "$skill_md"

check "no text uses a features/ folder" no_folder features "$skill"
check_fails "a features/ folder is caught" \
  quietly no_folder features "$(added features-folder 'Features live in `<bc>/features/`.')"

check "the pinned fixture is fetched" fetch_fixture "$work/root"
model="$work/root/.fixture/model"

# The test comment the skill shows: "<comment> esdm:<reference> scenario=<name>".
comment="$(grep -oE 'esdm:[^ `]+ scenario=[^ `]+' "$skill_md" | head -1)"
check "SKILL.md shows a test comment with an esdm: reference and scenario=" test -n "$comment"
reference="${comment%% *}"
scenario="${comment##*scenario=}"
check "the example comment names a fixture Feature and one of its Scenarios" \
  scenario_in_model "$model" "$reference" "$scenario"
check_fails "a reference to a Feature not in the fixture is caught" \
  scenario_in_model "$model" "${reference/copy/reader-account}" "$scenario"
check_fails "a Scenario not in the Feature is caught" \
  scenario_in_model "$model" "$reference" "invented-scenario"

finish

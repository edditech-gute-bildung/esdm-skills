#!/usr/bin/env bash
# The rewrite-tier to-spec skill: its files, the template's Testing Decisions
# (cite Features and Scenarios, never copy them), step 2's seams from Feature
# scopes, and the example citation, which must name a real Feature and Scenario
# in the fixture. Needs network and ruby: it fetches the fixture.
# scripts/check-text.sh checks the esdm-command introduction.
# tests/upstream-manifest.test.sh checks the rest of the text against upstream.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

skill="$REPO_ROOT/skills/engineering/to-spec"
skill_md="$skill/SKILL.md"

check "the skill holds upstream's files" has_files "$skill" SKILL.md agents/openai.yaml
check "every link in the skill resolves" links_resolve "$skill"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# dropped <name> <line>: a copy of SKILL.md without every line equal to <line>.
dropped() {
  mkdir -p "$work/$1"
  grep -vxF -e "$2" "$skill_md" >"$work/$1/SKILL.md"
  echo "$work/$1/SKILL.md"
}

# added <name> <line>: a copy of the skill with <line> appended to SKILL.md.
added() {
  cp -R "$skill" "$work/$1"
  printf '%s\n' "$2" >>"$work/$1/SKILL.md"
  echo "$work/$1"
}

# testing_decisions <file>: the template's Testing Decisions section.
testing_decisions() { awk '/^## / { on = ($0 == "## Testing Decisions") } on' "$1"; }

# cites_by_reference <file>: Testing Decisions has Features and Scenarios cited
# by esdm: reference as acceptance criteria.
cites_by_reference() {
  testing_decisions "$1" | grep -qiF 'acceptance criteria' &&
    testing_decisions "$1" | grep -qF '`esdm:`'
}
check "Testing Decisions cites Features and Scenarios by esdm: reference" cites_by_reference "$skill_md"
check_fails "a missing citation rule is caught" \
  cites_by_reference "$(dropped no-citation "$(testing_decisions "$skill_md" | grep -F 'acceptance criteria')")"

# forbids_copying <file>: Testing Decisions forbids copying given, when, then and data.
forbids_copying() {
  local line
  line="$(testing_decisions "$1" | grep -F 'never copy')" || return 1
  for key in given when then data; do
    grep -qF "\`$key\`" <<<"$line" || return 1
  done
}
check "Testing Decisions forbids copying given, when, then and data" forbids_copying "$skill_md"
check_fails "a missing copy ban is caught" \
  forbids_copying "$(dropped no-ban "$(grep -F 'never copy' "$skill_md")")"

# step_2 <file>: step 2 of the process, up to step 3.
step_2() { awk '/^2\. / { on = 1 } /^3\. / { on = 0 } on' "$1"; }

# seams_from_scopes <file>: step 2 takes seams from a Feature's scope.
seams_from_scopes() { step_2 "$1" | grep -qE 'Feature.*scope'; }
check "step 2 takes its seams from Feature scopes" seams_from_scopes "$skill_md"
check_fails "a missing Feature-scope seam rule is caught" \
  seams_from_scopes "$(dropped no-scopes "$(step_2 "$skill_md" | grep -E 'Feature.*scope' | head -1)")"

check "no text uses a features/ folder" no_folder features "$skill"
check_fails "a features/ folder is caught" \
  quietly no_folder features "$(added features-folder 'Features live in `<bc>/features/`.')"

check "the pinned fixture is fetched" fetch_fixture "$work/root"
model="$work/root/.fixture/model"

# The citation the template shows: "esdm:<reference> scenario=<name>".
citation="$(testing_decisions "$skill_md" | grep -oE 'esdm:[^ `]+ scenario=[^ `]+' | head -1)"
check "Testing Decisions shows a citation with an esdm: reference and scenario=" test -n "$citation"
reference="${citation%% *}"
scenario="${citation##*scenario=}"
check "the example citation names a fixture Feature and one of its Scenarios" \
  scenario_in_model "$model" "$reference" "$scenario"
check_fails "a reference to a Feature not in the fixture is caught" \
  scenario_in_model "$model" "${reference/copy/reader-account}" "$scenario"
check_fails "a Scenario not in the Feature is caught" \
  scenario_in_model "$model" "$reference" "invented-scenario"

finish

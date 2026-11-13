#!/usr/bin/env bash
# The rewrite-tier improve-codebase-architecture skill: its files, the model
# kinds it maps onto seam candidates, its finding kinds, its writes (all through
# domain-modeling), its agnostic text, the report's model additions, and its
# esdm: references, which must name real elements in the fixture. Needs network
# and ruby: it fetches the fixture.
# scripts/check-text.sh checks GLOSSARY.md writes and the esdm-command introduction.
# tests/upstream-manifest.test.sh checks HTML-REPORT.md against upstream.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

skill="$REPO_ROOT/skills/engineering/improve-codebase-architecture"
skill_md="$skill/SKILL.md"
report_md="$skill/HTML-REPORT.md"

check "the skill holds upstream's files" has_files "$skill" SKILL.md HTML-REPORT.md agents/openai.yaml
check "every link in the skill resolves" links_resolve "$skill"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# dropped <name> <file> <line>: a copy of <file> without every line equal to <line>.
dropped() {
  mkdir -p "$work/$1"
  grep -vxF -e "$3" "$2" >"$work/$1/$(basename "$2")"
  echo "$work/$1/$(basename "$2")"
}

# added <name> <line>: a copy of the skill with <line> appended to SKILL.md.
added() {
  cp -R "$skill" "$work/$1"
  printf '%s\n' "$2" >>"$work/$1/SKILL.md"
  echo "$work/$1"
}

# section <file> <heading>: the lines under a Markdown heading of any level, up
# to the next heading of the same or a higher level.
section() {
  awk -v heading="$2" '
    /^#+ / { level = index($0, " ") - 1 }
    $0 == heading { on = 1; depth = level; next }
    on && /^#+ / && level <= depth { on = 0 }
    on
  ' "$1"
}

# kind_row <file> <kind>: the seam-candidate table has a row for the model kind.
kind_row() { section "$1" '#### Model kinds as seam candidates' | grep -qE "^\| *$2 *\|"; }
for kind in 'Bounded Context' 'Aggregate / DCB' 'Context Mapping' 'Read Model \+ Query' 'Event' \
  'Policy / Event Handler' 'Process Manager' 'External System'; do
  check "the seam-candidate table covers ${kind//\\/}" kind_row "$skill_md" "$kind"
done
check_fails "a missing kind row is caught" \
  kind_row "$(dropped no-row "$skill_md" "$(grep -E '^\| *Process Manager *\|' "$skill_md")")" 'Process Manager'

# finding <file> <section> <name>: the section names the finding kind in bold.
finding() { section "$1" "$2" | grep -qF "**$3**"; }
for kind in 'Unit cut across' 'Unit shattered' 'Unmapped coupling' 'Reaction without a module' 'Style violation'; do
  check "a deepening finding: $kind" finding "$skill_md" '#### Findings' "$kind"
done
for kind in 'Code ahead of model' 'Model ahead of code'; do
  check "a Model drift item: $kind" finding "$skill_md" '#### Findings' "$kind"
done
check_fails "a missing finding kind is caught" \
  finding "$(dropped no-finding "$skill_md" "$(grep -F '**Unit shattered**' "$skill_md")")" '#### Findings' 'Unit shattered'
check_fails "a missing drift item is caught" \
  finding "$(dropped no-drift "$skill_md" "$(grep -F '**Code ahead of model**' "$skill_md")")" '#### Findings' 'Code ahead of model'

# model_wins <file>: the text says code changes to match the model, and a model
# change goes through domain-modeling first.
model_wins() { grep -qF '**The model wins.**' "$1"; }
check "the text says the model wins" model_wins "$skill_md"
check_fails "a missing model-wins rule is caught" \
  model_wins "$(dropped no-model-wins "$skill_md" "$(grep -F '**The model wins.**' "$skill_md")")"

# no_style_skill_note <file>: a style no installed skill covers is skipped, with
# a one-line note: the line that says so names installed skills and one line.
no_style_skill_note() {
  section "$1" '#### Architecture style' | grep -F 'installed' | grep -qF 'one line'
}
check "an uncovered style is skipped with a one-line note" no_style_skill_note "$skill_md"
check_fails "a missing skip note is caught" \
  no_style_skill_note "$(dropped no-skip-note "$skill_md" "$(grep -F 'say so in one line' "$skill_md")")"

# adr_writes_delegated <dir>: every line that has an ADR recorded, written or
# created hands the write to domain-modeling.
adr_writes_delegated() {
  local found
  found="$(grep -rniE '\b(record|writ|creat|add)[a-z]*\b[^.]{0,40}\bADRs?\b' "$1" --include='*.md' |
    grep -vF 'domain-modeling' || true)"
  [ -z "$found" ] || { printf '  %s\n' "$found"; return 1; }
}
check "ADR writes go through domain-modeling" adr_writes_delegated "$skill"
check_fails "a direct ADR write is caught" \
  quietly adr_writes_delegated "$(added adr-write 'Write an ADR to `docs/adr/` yourself.')"

# model_writes_delegated <dir>: no text writes a *.esdm.yaml file itself.
model_writes_delegated() {
  local found
  found="$(grep -rniE '\b(edit|writ|updat|append)[a-z]*\b[^.]{0,40}\.esdm\.yaml' "$1" --include='*.md' |
    grep -vF 'domain-modeling' || true)"
  [ -z "$found" ] || { printf '  %s\n' "$found"; return 1; }
}
check "model writes go through domain-modeling" model_writes_delegated "$skill"
check_fails "a direct model write is caught" \
  quietly model_writes_delegated "$(added model-write 'Edit `copy.esdm.yaml` to add the term.')"

# only_known_skills <dir>: the skill calls or names no skill but its own
# collaborators. `/tmp` is the temp-dir fallback, not a skill.
only_known_skills() {
  local named
  named="$(grep -rhoE 'Skill tool with "[^"]+"|`/[a-z][a-z0-9-]+`' "$1" --include='*.md' |
    sed -E 's/^Skill tool with "//; s/"$//; s/^`\///; s/`$//' | sort -u |
    grep -vxE 'codebase-design|grilling|domain-modeling|tdd|tmp' || true)"
  [ -z "$named" ] || { printf '  names %s\n' $named; return 1; }
}
check "the skill names no skill beyond its collaborators" only_known_skills "$skill"
check_fails "a named style skill is caught" \
  quietly only_known_skills "$(added style-skill 'Call the Skill tool with "event-sourcing" to judge style.')"

# no_technology <dir>: the skill names no architecture technology.
no_technology() { ! grep -rniwE 'kurrent(db)?|eventstore(db)?|rabbitmq|kafka|nats|axon|marten|postgres(ql)?' "$1" --include='*.md'; }
check "the skill names no technology" no_technology "$skill"
check_fails "a named technology is caught" quietly no_technology "$(added technology 'Prefer KurrentDB for events.')"

# The report's model additions.
check "a candidate card has a Model row" grep -qF '**Model**' "$report_md"
check "a candidate card has a finding-kind badge" grep -qiF 'finding-kind' "$report_md"
check "a Bounded Context is drawn as a labelled region" grep -qiE 'Bounded Context.*region' "$report_md"
check "a Context Mapping is drawn as a dashed seam" grep -qiE 'Context Mapping.*dashed seam' "$report_md"
check "the scaffold has the Model drift section" grep -qF '<section id="model-drift">' "$report_md"

# drift_before_top <file>: the Model drift section comes before Top recommendation.
drift_before_top() {
  local drift top
  drift="$(grep -nF '<section id="model-drift">' "$1" | cut -d: -f1)"
  top="$(grep -nF '<section id="top-recommendation">' "$1" | cut -d: -f1)"
  [ -n "$drift" ] && [ -n "$top" ] && [ "$drift" -lt "$top" ]
}
check "Model drift comes before Top recommendation" drift_before_top "$report_md"

check "no text uses a features/ folder" no_folder features "$skill"
check_fails "a features/ folder is caught" \
  quietly no_folder features "$(added features-folder 'Features live in `<bc>/features/`.')"

check "the pinned fixture is fetched" fetch_fixture "$work/root"
model="$work/root/.fixture/model"

# references <dir>: each distinct esdm: reference in the skill's text.
references() { grep -rhoE 'esdm:[a-z-]+=[^ `)"]+' "$1" --include='*.md' | sort -u; }

# references_resolve <dir>: each esdm: reference names an element in the fixture.
references_resolve() {
  local reference status=0 count=0
  while IFS= read -r reference; do
    count=$((count + 1))
    element_in_model "$model" "$reference" || { echo "  no element $reference"; status=1; }
  done < <(references "$1")
  [ "$count" -gt 0 ] && return "$status"
}
check "every esdm: reference in the skill names a fixture element" references_resolve "$skill"
check_fails "a reference to an element not in the fixture is caught" \
  quietly references_resolve "$(added bad-reference 'See `esdm:domain=library/bounded-context=lending/aggregate=loan`.')"

finish

#!/usr/bin/env bash
# This repo's upstream.json and its patch-tier copies, checked against the real
# mattpocock/skills. Needs network.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

manifest="$REPO_ROOT/upstream.json"

# is_entry <tier> <name>: listed as <tier> at its mirrored path, with a full SHA.
is_entry() {
  jq -e --arg tier "$1" --arg name "$2" '
    .skills[$name]
    | .tier == $tier
      and .skillPath == "skills/engineering/\($name)"
      and (.base | test("^[0-9a-f]{40}$"))
  ' "$manifest" >/dev/null
}

check "upstream.json points at mattpocock/skills" \
  test "$(jq -r '.upstream' "$manifest")" = "https://github.com/mattpocock/skills"
for name in triage grill-with-docs; do
  check "upstream.json lists $name as patch tier" is_entry patch "$name"
  check "$name sits at its upstream path, agents/openai.yaml included" \
    test -f "$REPO_ROOT/skills/engineering/$name/agents/openai.yaml"
done

check "patch-tier skills differ from upstream only in their listed edits" \
  bash "$REPO_ROOT/scripts/check-patch-tier.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# upstream_file <name> <file>: <file> of the skill, as upstream has it at the
# entry's base. Upstream is fetched once per base.
upstream_file() {
  local base skill_path
  base="$(jq -r --arg name "$1" '.skills[$name].base' "$manifest")"
  skill_path="$(jq -r --arg name "$1" '.skills[$name].skillPath' "$manifest")"
  if [ ! -d "$work/$base" ]; then
    git init --quiet "$work/$base" &&
      git -C "$work/$base" fetch --quiet --depth 1 "$(jq -r '.upstream' "$manifest")" "$base" || return 1
  fi
  git -C "$work/$base" show "$base:$skill_path/$2"
}

# matches_base <name> <file>: <file> is byte-identical to upstream at the entry's base.
matches_base() {
  local skill_path
  skill_path="$(jq -r --arg name "$1" '.skills[$name].skillPath' "$manifest")"
  diff <(upstream_file "$1" "$2") "$REPO_ROOT/$skill_path/$2"
}

for name in domain-modeling setup-matt-pocock-skills; do
  check "upstream.json lists $name as rewrite tier" is_entry rewrite "$name"
  check "$name's agents/openai.yaml is upstream's at the base" matches_base "$name" agents/openai.yaml
done

setup=setup-matt-pocock-skills
for file in issue-tracker-github.md issue-tracker-gitlab.md issue-tracker-local.md triage-labels.md; do
  check "$setup's $file is upstream's at the base" matches_base "$setup" "$file"
done

# sections_a_b: the Section A and Section B paragraphs of a SKILL.md on stdin,
# from "**Section A" up to "**Section C".
sections_a_b() { awk '/^\*\*Section A/ { on = 1 } /^\*\*Section C/ { on = 0 } on'; }
setup_sections_match() {
  local ours="$REPO_ROOT/skills/engineering/$setup/SKILL.md"
  grep -q '^\*\*Section A' "$ours" &&
    diff <(upstream_file "$setup" SKILL.md | sections_a_b) <(sections_a_b <"$ours")
}
check "$setup's Sections A and B are upstream's at the base" setup_sections_match

finish

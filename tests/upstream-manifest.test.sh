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

# openai_yaml_matches_base <name>: agents/openai.yaml is byte-identical to upstream at the entry's base.
openai_yaml_matches_base() {
  local base skill_path work
  base="$(jq -r --arg name "$1" '.skills[$name].base' "$manifest")"
  skill_path="$(jq -r --arg name "$1" '.skills[$name].skillPath' "$manifest")"
  work="$(mktemp -d)"
  git init --quiet "$work" &&
    git -C "$work" fetch --quiet --depth 1 "$(jq -r '.upstream' "$manifest")" "$base" &&
    diff <(git -C "$work" show "$base:$skill_path/agents/openai.yaml") "$REPO_ROOT/$skill_path/agents/openai.yaml"
  local status=$?
  rm -rf "$work"
  return "$status"
}

for name in domain-modeling; do
  check "upstream.json lists $name as rewrite tier" is_entry rewrite "$name"
  check "$name's agents/openai.yaml is upstream's at the base" openai_yaml_matches_base "$name"
done

finish

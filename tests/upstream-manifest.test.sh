#!/usr/bin/env bash
# This repo's upstream.json and its patch-tier copies, checked against the real
# mattpocock/skills. Needs network.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

manifest="$REPO_ROOT/upstream.json"

# is_patch_entry <name>: listed as patch tier at its mirrored path, with a full SHA.
is_patch_entry() {
  jq -e --arg name "$1" '
    .skills[$name]
    | .tier == "patch"
      and .skillPath == "skills/engineering/\($name)"
      and (.base | test("^[0-9a-f]{40}$"))
  ' "$manifest" >/dev/null
}

check "upstream.json points at mattpocock/skills" \
  test "$(jq -r '.upstream' "$manifest")" = "https://github.com/mattpocock/skills"
for name in triage grill-with-docs; do
  check "upstream.json lists $name as patch tier" is_patch_entry "$name"
  check "$name sits at its upstream path, agents/openai.yaml included" \
    test -f "$REPO_ROOT/skills/engineering/$name/agents/openai.yaml"
done

check "patch-tier skills differ from upstream only in their listed edits" \
  bash "$REPO_ROOT/scripts/check-patch-tier.sh"

finish

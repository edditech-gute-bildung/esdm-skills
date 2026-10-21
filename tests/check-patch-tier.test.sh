#!/usr/bin/env bash
# check-patch-tier.sh, run in a temp repo whose upstream.json points at a local
# git repo standing in for mattpocock/skills.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The fake upstream: one skill, committed.
upstream="$work/upstream"
mkdir -p "$upstream/skills/engineering/demo/agents"
printf -- '---\nname: demo\ndescription: Writes `GLOSSARY.md` inline.\n---\n\nStep one.\nStep two.\n' \
  >"$upstream/skills/engineering/demo/SKILL.md"
printf 'interface:\n  display_name: "Demo"\n' >"$upstream/skills/engineering/demo/agents/openai.yaml"
git -C "$upstream" init --quiet
git -C "$upstream" add .
git -C "$upstream" -c user.name=test -c user.email=test@example.com commit --quiet -m demo
base="$(git -C "$upstream" rev-parse HEAD)"

# new_repo: a temp repo with the check, an upstream.json listing one edit on
# line 3 of demo's SKILL.md, and a copy of demo with exactly that edit.
new_repo() {
  local repo
  repo="$(mktemp -d "$work/repo.XXXXXX")"
  mkdir -p "$repo/scripts" "$repo/skills/engineering"
  cp "$REPO_ROOT/scripts/check-patch-tier.sh" "$repo/scripts/"
  cp -R "$upstream/skills/engineering/demo" "$repo/skills/engineering/"
  sed -i.bak 's/Writes `GLOSSARY.md` inline./Writes the ESDM model inline./' \
    "$repo/skills/engineering/demo/SKILL.md"
  rm "$repo/skills/engineering/demo/SKILL.md.bak"
  cat >"$repo/upstream.json" <<EOF
{
  "upstream": "$upstream",
  "skills": {
    "demo": {
      "tier": "patch",
      "skillPath": "skills/engineering/demo",
      "base": "$base",
      "edits": [
        {
          "file": "SKILL.md",
          "line": 3,
          "from": "description: Writes \`GLOSSARY.md\` inline.",
          "to": "description: Writes the ESDM model inline."
        }
      ]
    }
  }
}
EOF
  echo "$repo"
}

run_check() {
  bash "$1/scripts/check-patch-tier.sh" >"$1/out.log" 2>&1
}

repo="$(new_repo)"
check "passes when a copy differs from upstream only in its listed edits" run_check "$repo"

repo="$(new_repo)"
echo "Step three." >>"$repo/skills/engineering/demo/SKILL.md"
check_fails "fails when an extra line is changed" run_check "$repo"
check "names the skill and file that drifted" grep -q "demo.*SKILL.md" "$repo/out.log"

repo="$(new_repo)"
cp "$upstream/skills/engineering/demo/SKILL.md" "$repo/skills/engineering/demo/SKILL.md"
check_fails "fails when a listed edit is missing" run_check "$repo"

repo="$(new_repo)"
echo "extra" >"$repo/skills/engineering/demo/EXTRA.md"
check_fails "fails when a file is added" run_check "$repo"

repo="$(new_repo)"
rm "$repo/skills/engineering/demo/agents/openai.yaml"
check_fails "fails when an upstream file is missing" run_check "$repo"

repo="$(new_repo)"
# other shares demo's folder, so only its unfetchable base can fail it.
jq '.skills.other = (.skills.demo | .base = ("0" * 40))' \
  "$repo/upstream.json" >"$repo/upstream.json.new" && mv "$repo/upstream.json.new" "$repo/upstream.json"
check_fails "fails when a skill's base can't be fetched, even after another skill's fetch" run_check "$repo"
check "names the skill whose base can't be fetched" grep -q "FAIL other" "$repo/out.log"

repo="$(new_repo)"
jq 'del(.skills.demo.edits)' "$repo/upstream.json" >"$repo/upstream.json.new" &&
  mv "$repo/upstream.json.new" "$repo/upstream.json"
check_fails "fails when a patch entry lists no edits" run_check "$repo"

repo="$(new_repo)"
jq '.skills.demo.edits[0].line = 6' "$repo/upstream.json" >"$repo/upstream.json.new" &&
  mv "$repo/upstream.json.new" "$repo/upstream.json"
check_fails "fails when an edit's from line doesn't match upstream" run_check "$repo"
check "says which edit doesn't match" grep -q "line 6" "$repo/out.log"

# Last: this commits to the shared upstream, which new_repo copies from.
repo="$(new_repo)"
printf 'no final newline' >>"$upstream/skills/engineering/demo/agents/openai.yaml"
git -C "$upstream" -c user.name=test -c user.email=test@example.com commit --quiet -am "no final newline"
printf -- '---\nname: demo\ndescription: Writes `GLOSSARY.md` inline.\n---\n\nStep one.\nStep two.' \
  >"$upstream/skills/engineering/demo/SKILL.md"
git -C "$upstream" -c user.name=test -c user.email=test@example.com commit --quiet -am "no final newline"
cp "$upstream/skills/engineering/demo/agents/openai.yaml" "$repo/skills/engineering/demo/agents/"
cp "$upstream/skills/engineering/demo/SKILL.md" "$repo/skills/engineering/demo/"
sed -i.bak 's/Writes `GLOSSARY.md` inline./Writes the ESDM model inline./' "$repo/skills/engineering/demo/SKILL.md"
rm "$repo/skills/engineering/demo/SKILL.md.bak"
jq --arg base "$(git -C "$upstream" rev-parse HEAD)" '.skills.demo.base = $base' \
  "$repo/upstream.json" >"$repo/upstream.json.new" && mv "$repo/upstream.json.new" "$repo/upstream.json"
check "keeps a missing final newline when applying an edit" run_check "$repo"

finish

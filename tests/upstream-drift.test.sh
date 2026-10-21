#!/usr/bin/env bash
# upstream-drift.sh, run in temp repos whose upstream.json points at a local git
# repo standing in for mattpocock/skills.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The fake upstream: two skills, committed. Its first commit is every entry's base.
upstream="$work/upstream"
mkdir -p "$upstream/skills/engineering/demo/agents" "$upstream/skills/in-progress/other"
printf -- '---\nname: demo\n---\n\nStep one.\n' >"$upstream/skills/engineering/demo/SKILL.md"
printf 'interface:\n  display_name: "Demo"\n' >"$upstream/skills/engineering/demo/agents/openai.yaml"
printf 'Notes.\n' >"$upstream/skills/engineering/demo/NOTES.md"
printf -- '---\nname: other\n---\n' >"$upstream/skills/in-progress/other/SKILL.md"
git -C "$upstream" init --quiet
git -C "$upstream" add .
git -C "$upstream" -c user.name=test -c user.email=test@example.com commit --quiet -m base
base="$(git -C "$upstream" rev-parse HEAD)"

# new_repo: a temp repo with the drift script, its own copy of the fake upstream
# in <repo>/upstream, and an upstream.json listing both skills at the base.
new_repo() {
  local repo
  repo="$(mktemp -d "$work/repo.XXXXXX")"
  mkdir -p "$repo/scripts"
  cp "$REPO_ROOT/scripts/upstream-drift.sh" "$repo/scripts/"
  cp -R "$upstream" "$repo/upstream"
  cat >"$repo/upstream.json" <<EOF
{
  "upstream": "$repo/upstream",
  "skills": {
    "demo": { "tier": "patch", "skillPath": "skills/engineering/demo", "base": "$base", "edits": [] },
    "other": { "tier": "rewrite", "skillPath": "skills/in-progress/other", "base": "$base" }
  }
}
EOF
  echo "$repo"
}

# run_drift <repo> [flags...]: the drift script's exit status; output in <repo>/out.log.
run_drift() {
  local repo="$1"
  shift
  bash "$repo/scripts/upstream-drift.sh" "$@" >"$repo/out.log" 2>"$repo/err.log"
}

# exits_with <status> <command...>: the command exits with exactly <status>.
exits_with() {
  local want="$1"
  shift
  "$@"
  [ "$?" -eq "$want" ]
}

# commit_upstream <repo> <message> <command...>: run the command in the repo's
# fake upstream, then commit everything it changed.
commit_upstream() {
  local repo="$1" message="$2"
  shift 2
  (cd "$repo/upstream" && "$@") &&
    git -C "$repo/upstream" add -A &&
    git -C "$repo/upstream" -c user.name=test -c user.email=test@example.com commit --quiet -m "$message"
}

repo="$(new_repo)"
check "exits 0 when upstream hasn't moved past the bases" exits_with 0 run_drift "$repo"
check "reports each skill as ok" grep -q "^ok   demo" "$repo/out.log"

repo="$(new_repo)"
commit_upstream "$repo" "change elsewhere" sh -c 'echo readme >README.md'
check "exits 0 when upstream only changed outside the skill folders" exits_with 0 run_drift "$repo"

repo="$(new_repo)"
commit_upstream "$repo" "change demo" sh -c '
  echo "Step two." >>skills/engineering/demo/SKILL.md
  echo new >skills/engineering/demo/NEW.md
  rm skills/engineering/demo/NOTES.md'
check "exits 1 when a skill drifted" exits_with 1 run_drift "$repo"
check "reports the drifted skill" grep -q "^DRIFT demo" "$repo/out.log"
check "lists a changed file" grep -qE "^  M[[:space:]]+SKILL.md$" "$repo/out.log"
check "lists an added file" grep -qE "^  A[[:space:]]+NEW.md$" "$repo/out.log"
check "lists a deleted file" grep -qE "^  D[[:space:]]+NOTES.md$" "$repo/out.log"
check "reports the skill that didn't drift as ok" grep -q "^ok   other" "$repo/out.log"

# As upstream does when a skill graduates from in-progress/ to engineering/.
repo="$(new_repo)"
commit_upstream "$repo" "move other" sh -c '
  mkdir -p skills/engineering && git mv skills/in-progress/other skills/engineering/other'
check "exits 1 when a skill's upstream path moved" exits_with 1 run_drift "$repo"
check "flags the move and names the new path" \
  grep -q "^MOVED other: upstream skills/in-progress/other is now skills/engineering/other" "$repo/out.log"

repo="$(new_repo)"
commit_upstream "$repo" "move and change other" sh -c '
  mkdir -p skills/engineering && git mv skills/in-progress/other skills/engineering/other &&
  echo more >>skills/engineering/other/SKILL.md'
run_drift "$repo"
check "lists what changed in a moved skill, against its new path" \
  grep -qE "^  M[[:space:]]+SKILL.md$" "$repo/out.log"

repo="$(new_repo)"
commit_upstream "$repo" "delete other" git rm --quiet -r skills/in-progress/other
check "exits 1 when a skill's upstream path is gone" exits_with 1 run_drift "$repo"
check "flags the deleted path" grep -q "^GONE other: upstream skills/in-progress/other no longer exists" "$repo/out.log"

# json_has <repo> <jq filter>: the --json report in <repo>/out.log satisfies the filter.
json_has() { jq -e "$2" "$1/out.log" >/dev/null; }

repo="$(new_repo)"
commit_upstream "$repo" "change demo, move other" sh -c '
  echo new >skills/engineering/demo/NEW.md
  mkdir -p skills/engineering && git mv skills/in-progress/other skills/engineering/other'
head="$(git -C "$repo/upstream" rev-parse HEAD)"
check "exits 1 with --json when a skill drifted" exits_with 1 run_drift "$repo" --json
check "--json reports a drifted skill with its files, base and head" json_has "$repo" "
  .[] | select(.skill == \"demo\")
  | .status == \"drifted\" and .skillPath == \"skills/engineering/demo\"
    and .base == \"$base\" and .head == \"$head\"
    and .files == [{\"status\": \"A\", \"path\": \"NEW.md\"}]"
check "--json reports a moved skill with its new path" json_has "$repo" '
  .[] | select(.skill == "other") | .status == "moved" and .headPath == "skills/engineering/other"'
check "--json gives each skill the summary the plain report prints" json_has "$repo" '
  .[] | select(.skill == "other") | .summary | startswith("upstream skills/in-progress/other is now skills/engineering/other")'

repo="$(new_repo)"
run_drift "$repo" --json
check "--json reports a skill that didn't drift as ok, with no files" json_has "$repo" '
  [.[] | .status == "ok" and .files == []] | all'

repo="$(new_repo)"
commit_upstream "$repo" "delete other" git rm --quiet -r skills/in-progress/other
run_drift "$repo" --json
check "--json reports a deleted path as gone" json_has "$repo" '.[] | select(.skill == "other") | .status == "gone"'

repo="$(new_repo)"
jq '.skills.demo.base = ("0" * 40)' "$repo/upstream.json" >"$repo/upstream.json.new" &&
  mv "$repo/upstream.json.new" "$repo/upstream.json"
check "exits 2 when a base can't be fetched" exits_with 2 run_drift "$repo"
check "says which skill's base can't be fetched" grep -q "demo" "$repo/err.log"

repo="$(new_repo)"
check "exits 2 on an unknown flag" exits_with 2 run_drift "$repo" --jsno

repo="$(new_repo)"
commit_upstream "$repo" "add other elsewhere" sh -c 'mkdir -p skills/engineering/typo && echo x >skills/engineering/typo/SKILL.md'
jq '.skills.demo.skillPath = "skills/engineering/typo"' "$repo/upstream.json" >"$repo/upstream.json.new" &&
  mv "$repo/upstream.json.new" "$repo/upstream.json"
check "exits 2 when a skillPath doesn't exist at its base" exits_with 2 run_drift "$repo"
check "says which skill's path is missing at its base" grep -q "demo" "$repo/err.log"

# A name with a regex character must not match another skill's folder.
repo="$(new_repo)"
commit_upstream "$repo" "add a.b and a lookalike" sh -c '
  mkdir -p skills/in-progress/a.b skills/aaa/aXb && echo x >skills/in-progress/a.b/SKILL.md &&
  echo y >skills/aaa/aXb/SKILL.md'
jq --arg base "$(git -C "$repo/upstream" rev-parse HEAD)" \
  '.skills = {"a.b": {tier: "rewrite", skillPath: "skills/in-progress/a.b", base: $base}}' \
  "$repo/upstream.json" >"$repo/upstream.json.new" && mv "$repo/upstream.json.new" "$repo/upstream.json"
commit_upstream "$repo" "move a.b" sh -c 'mkdir -p skills/engineering && git mv skills/in-progress/a.b skills/engineering/a.b'
run_drift "$repo"
check "matches a moved skill's name literally" grep -q "is now skills/engineering/a.b" "$repo/out.log"

repo="$(new_repo)"
commit_upstream "$repo" "move other into two places" sh -c '
  mkdir -p skills/engineering skills/misc && cp -R skills/in-progress/other skills/misc/other &&
  git mv skills/in-progress/other skills/engineering/other'
check "exits 2 when a moved skill's name exists in two places" exits_with 2 run_drift "$repo"
check "names both places" bash -c 'grep -q skills/engineering/other "$0" && grep -q skills/misc/other "$0"' "$repo/err.log"

finish

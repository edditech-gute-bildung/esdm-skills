#!/usr/bin/env bash
# The rewrite-tier setup-matt-pocock-skills skill: its files, its domain.md seed,
# and the pin it carries, which this repo's own .esdm-version is.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

skill="$REPO_ROOT/skills/engineering/setup-matt-pocock-skills"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# has_files <dir> <file...>: the dir holds exactly these files.
has_files() {
  local dir="$1"
  shift
  diff <(cd "$dir" && find . -type f ! -name .DS_Store | sed 's|^\./||' | sort) <(printf '%s\n' "$@" | sort)
}
check "the skill holds upstream's files, plus its pin and fetch script" \
  has_files "$skill" SKILL.md domain.md issue-tracker-github.md issue-tracker-gitlab.md \
  issue-tracker-local.md triage-labels.md agents/openai.yaml esdm-version scripts/fetch-esdm.sh

# placeholders <file>: each distinct [bracketed] value in the file.
placeholders() { grep -oE '`[^`]*\[[^]`]+\][^`]*`' "$1" | grep -oE '\[[^]]+\]' | sort -u; }
# seed_placeholders: the seed's placeholders are the model dir and esdm command.
seed_placeholders() { diff <(placeholders "$skill/domain.md") <(printf '%s\n' '[esdm | .tools/esdm]' '[esdm/]'); }
check "domain.md leaves exactly the model dir and esdm command to fill in" seed_placeholders

# same_file <path> <file>: <path>, symlinks resolved, is <file>.
same_file() { [ "$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")" -ef "$2" ]; }
check "this repo's .esdm-version is the skill's pin" same_file "$REPO_ROOT/.esdm-version" "$skill/esdm-version"
cp "$skill/esdm-version" "$work/esdm-version"
check_fails "a copy of the pin is caught" same_file "$work/esdm-version" "$skill/esdm-version"
check "this repo's scripts/fetch-esdm.sh is the skill's" same_file "$REPO_ROOT/scripts/fetch-esdm.sh" "$skill/scripts/fetch-esdm.sh"

# pins_every_os_arch: the pin names a version and a SHA256 for every os-arch esdm releases.
pins_every_os_arch() {
  local key
  grep -qE '^version: [0-9]+\.[0-9]+\.[0-9]+$' "$skill/esdm-version" || return 1
  for key in darwin-amd64 darwin-arm64 linux-amd64 linux-arm64 windows-amd64 windows-arm64; do
    grep -qE "^$key: [0-9a-f]{64}$" "$skill/esdm-version" || { echo "  no SHA256 for $key"; return 1; }
  done
}
check "the pin has a version and a SHA256 per os-arch" pins_every_os_arch

check "SKILL.md points to the pin" grep -qF '](./esdm-version)' "$skill/SKILL.md"
check "SKILL.md points to the fetch script" grep -qF '](./scripts/fetch-esdm.sh)' "$skill/SKILL.md"

finish

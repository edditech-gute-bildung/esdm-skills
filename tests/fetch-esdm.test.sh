#!/usr/bin/env bash
# fetch-esdm.sh, run as a consumer repo runs it: copied to scripts/ in a temp
# repo, downloading from a local release directory instead of GitHub.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

os_arch="$(host_os_arch)"

# A local release: <base>/v9.9.9/esdm-<os>-<arch>, a script standing in for esdm.
release="$work/release"
mkdir -p "$release/v9.9.9"
printf '#!/bin/sh\necho "esdm 9.9.9"\n' >"$release/v9.9.9/esdm-$os_arch"
good_sha="$(sha256_of "$release/v9.9.9/esdm-$os_arch")"

# new_repo <sha for this host>: a temp repo with the script and a .esdm-version.
new_repo() {
  local repo
  repo="$(mktemp -d "$work/repo.XXXXXX")"
  mkdir -p "$repo/scripts"
  cp "$FETCH_ESDM_TEMPLATE" "$repo/scripts/fetch-esdm.sh"
  printf 'version: 9.9.9\n%s: %s\n' "$os_arch" "$1" >"$repo/.esdm-version"
  echo "$repo"
}

fetch() {
  ESDM_DOWNLOAD_BASE="file://$release" bash "$1/scripts/fetch-esdm.sh" >"$1/out.log" 2>&1
}

# A binary whose SHA256 doesn't match the pin is rejected and leaves nothing behind.
repo="$(new_repo 0000000000000000000000000000000000000000000000000000000000000000)"
check_fails "rejects a binary whose SHA256 doesn't match" fetch "$repo"
check "says why it rejected the binary" grep -q "SHA256 mismatch" "$repo/out.log"
check "leaves nothing in .tools after a mismatch" test -z "$(ls -A "$repo/.tools" 2>/dev/null)"

# A binary matching the pin lands in .tools/esdm, ready to run.
repo="$(new_repo "$good_sha")"
check "accepts a binary whose SHA256 matches" fetch "$repo"
check "installs a runnable .tools/esdm" test "$("$repo/.tools/esdm" 2>/dev/null)" = "esdm 9.9.9"
check "leaves only the binary in .tools" test "$(ls -A "$repo/.tools")" = esdm

# A pin without this host's os-arch is refused before anything is downloaded.
repo="$(new_repo "$good_sha")"
printf 'version: 9.9.9\n' >"$repo/.esdm-version"
check_fails "refuses a pin without this host's os-arch" fetch "$repo"
check "names the missing os-arch" grep -q "no SHA256 for $os_arch" "$repo/out.log"

# ESDM_PIN and ESDM_INSTALL_DIR point the script at another pin and install
# directory, as setup's PATH install runs it from the skill folder.
repo="$(new_repo "$good_sha")"
mkdir -p "$work/elsewhere" "$work/bin"
mv "$repo/.esdm-version" "$work/elsewhere/.esdm-version"
fetch_to_bin() {
  ESDM_PIN="$work/elsewhere/.esdm-version" ESDM_INSTALL_DIR="$work/bin" fetch "$1"
}
check "fetches with the pin and install directory given" fetch_to_bin "$repo"
check "installs a runnable esdm in the install directory" test "$("$work/bin/esdm" 2>/dev/null)" = "esdm 9.9.9"
check "leaves no .tools behind" test ! -e "$repo/.tools"

finish

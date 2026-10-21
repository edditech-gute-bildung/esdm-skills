#!/usr/bin/env bash
# Fetch the test fixture pinned in .esdm-fixture into .fixture.
#
# .esdm-fixture holds the fixture repository and the commit to check out:
#
#   repo: https://github.com/edditech-gute-bildung/esdm-library-example
#   sha: <commit sha>
#
# To bump the fixture, edit the sha.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pin="$root/.esdm-fixture"
fixture="$root/.fixture"

die() {
  echo "fetch-fixture: $*" >&2
  exit 1
}

[ -f "$pin" ] || die "no .esdm-fixture at $root"

# pinned <key>: the value of "<key>: <value>" in .esdm-fixture.
pinned() {
  awk -v key="$1" 'index($0, key ":") == 1 { sub(/^[^:]*: */, ""); print; exit }' "$pin"
}

repo="$(pinned repo)"
sha="$(pinned sha)"
[ -n "$repo" ] || die "no repo in .esdm-fixture"
[ -n "$sha" ] || die "no sha in .esdm-fixture"

if [ ! -d "$fixture/.git" ]; then
  rm -rf "$fixture"
  git init --quiet "$fixture"
fi

echo "fetch-fixture: fetching $repo at $sha"
git -C "$fixture" fetch --quiet --depth 1 "$repo" "$sha"
git -C "$fixture" checkout --quiet --force --detach FETCH_HEAD
git -C "$fixture" clean --quiet -fdx
echo "fetch-fixture: $fixture is at $(git -C "$fixture" rev-parse HEAD)"

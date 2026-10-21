#!/usr/bin/env bash
# Fetch the esdm binary pinned in .esdm-version into .tools/esdm, or wherever
# ESDM_PIN and ESDM_INSTALL_DIR say.
# Lives at scripts/fetch-esdm.sh; the repo root is the script's parent directory.
#
# .esdm-version holds the version and one SHA256 per os-arch:
#
#   version: 0.15.0
#   darwin-arm64: <sha256>
#   linux-amd64: <sha256>
#   ...
#
# The download is verified against the pin before it is installed.
# ESDM_DOWNLOAD_BASE overrides where releases are downloaded from, ESDM_PIN which
# pin is read, and ESDM_INSTALL_DIR where esdm lands.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pin="${ESDM_PIN:-$root/.esdm-version}"
install_dir="${ESDM_INSTALL_DIR:-$root/.tools}"
base="${ESDM_DOWNLOAD_BASE:-https://github.com/thenativeweb/esdm/releases/download}"

die() {
  echo "fetch-esdm: $*" >&2
  exit 1
}

[ -f "$pin" ] || die "no pin at $pin"

# pinned <key>: the value of "<key>: <value>" in the pin.
pinned() {
  awk -v key="$1" 'index($0, key ":") == 1 { sub(/^[^:]*: */, ""); print; exit }' "$pin"
}

case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  *) die "unsupported OS: $(uname -s)" ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  arm64 | aarch64) arch=arm64 ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

version="$(pinned version)"
expected="$(pinned "$os-$arch")"
[ -n "$version" ] || die "no version in .esdm-version"
[ -n "$expected" ] || die "no SHA256 for $os-$arch in .esdm-version"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

mkdir -p "$install_dir"
download="$(mktemp "$install_dir/esdm.download.XXXXXX")"
trap 'rm -f "$download"' EXIT

url="$base/v$version/esdm-$os-$arch"
echo "fetch-esdm: downloading esdm $version for $os-$arch"
curl --fail --silent --show-error --location --output "$download" "$url" ||
  die "download failed: $url"

actual="$(sha256 "$download")"
[ "$actual" = "$expected" ] ||
  die "SHA256 mismatch for $url: expected $expected, got $actual"

chmod +x "$download"
if [ "$os" = darwin ]; then
  xattr -d com.apple.quarantine "$download" 2>/dev/null || true
fi
mv "$download" "$install_dir/esdm"
echo "fetch-esdm: installed $install_dir/esdm"

# Shared helpers for the shell tests. Source it; don't run it.
# Tests run without set -e so check/check_fails can observe failures.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FETCH_ESDM_TEMPLATE="$REPO_ROOT/skills/engineering/setup-matt-pocock-skills/scripts/fetch-esdm.sh"

failures=0

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }

# check <description> <command...>: passes when the command exits 0.
check() {
  local description="$1"
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

# check_fails <description> <command...>: passes when the command exits non-zero.
check_fails() {
  local description="$1"
  shift
  if "$@"; then fail "$description"; else pass "$description"; fi
}

# os-arch of this machine, as esdm names its release assets.
host_os_arch() {
  local os arch
  case "$(uname -s)" in
    Darwin) os=darwin ;;
    Linux) os=linux ;;
    *) os=unknown ;;
  esac
  case "$(uname -m)" in
    x86_64 | amd64) arch=amd64 ;;
    arm64 | aarch64) arch=arm64 ;;
    *) arch=unknown ;;
  esac
  echo "$os-$arch"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

finish() {
  if [ "$failures" -gt 0 ]; then
    printf '%d check(s) failed\n' "$failures"
    exit 1
  fi
}

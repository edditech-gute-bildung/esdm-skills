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

# quietly <command...>: the command, its output dropped.
quietly() { "$@" >/dev/null; }

# no_folder <folder> <dir>: no text in the skill puts documents in a <folder>/
# folder; Features and stories live next to their unit or context as
# <name>.feature.esdm.yaml or <name>.story.esdm.yaml.
no_folder() { ! grep -rnF "$1/" "$2"; }

# fetch_fixture <root>: fetch the pinned fixture into <root>/.fixture, so the
# working tree's .fixture stays as it is.
fetch_fixture() {
  mkdir -p "$1/scripts" &&
    cp "$REPO_ROOT/.esdm-fixture" "$1/" &&
    cp -L "$REPO_ROOT/scripts/fetch-fixture.sh" "$1/scripts/" &&
    bash "$1/scripts/fetch-fixture.sh" >/dev/null
}

# has_files <dir> <file...>: the dir holds exactly these files.
has_files() {
  local dir="$1"
  shift
  diff <(cd "$dir" && find . -type f ! -name .DS_Store | sed 's|^\./||' | sort) <(printf '%s\n' "$@" | sort)
}

# links_resolve <dir>: every relative Markdown link in the skill's files names a file that exists.
links_resolve() {
  local file target status=0
  while IFS= read -r file; do
    while IFS= read -r target; do
      [ -e "$(dirname "$file")/$target" ] || { echo "  $(basename "$file") links to missing $target"; status=1; }
    done < <(grep -oE '\]\([^)#:]+' "$file" | sed 's/^](//')
  done < <(find "$1" -name '*.md')
  return "$status"
}

# scenario_in_model <model dir> <esdm: reference> <scenario>: the reference
# names a Feature in the model, and the Feature has a Scenario of that name. A
# reference stops at the Feature, so the Scenario is passed on its own. Needs ruby.
scenario_in_model() {
  ruby -ryaml -e '
    model, ref, scenario = ARGV
    path = ref.delete_prefix("esdm:").split("/").to_h { |segment| segment.split("=", 2) }
    feature = path.delete("feature") or exit 1
    scope = path.transform_keys { |key| key.gsub(/-(\w)/) { $1.upcase } }
    found = Dir.glob(File.join(model, "**", "*.feature.esdm.yaml")).any? do |file|
      YAML.load_stream(File.read(file)).compact.any? do |doc|
        doc["kind"] == "feature" && doc["name"] == feature && doc["scope"] == scope &&
          Array(doc["scenarios"]).any? { |s| s["name"] == scenario }
      end
    end
    exit(found ? 0 : 1)
  ' "$@"
}

# element_in_model <model dir> <esdm: reference>: the reference names an element
# in the model. Its last segment is the element's kind and name; the segments
# before it are its scope. Needs ruby.
element_in_model() {
  ruby -ryaml -e '
    model, ref = ARGV
    segments = ref.delete_prefix("esdm:").split("/").map { |segment| segment.split("=", 2) }
    kind, name = segments.pop
    scope = segments.to_h.transform_keys { |key| key.gsub(/-(\w)/) { $1.upcase } }
    found = Dir.glob(File.join(model, "**", "*.esdm.yaml")).any? do |file|
      YAML.load_stream(File.read(file)).compact.any? do |doc|
        doc["kind"] == kind && doc["name"] == name &&
          (doc["scope"] ? doc["scope"] == scope : scope.keys == ["domain"])
      end
    end
    exit(found ? 0 : 1)
  ' "$@"
}

finish() {
  if [ "$failures" -gt 0 ]; then
    printf '%d check(s) failed\n' "$failures"
    exit 1
  fi
}

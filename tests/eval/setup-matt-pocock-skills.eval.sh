#!/usr/bin/env bash
# /setup-matt-pocock-skills on the glossary-only variant: the fixture's
# GLOSSARY.md, hand-written, and no model, domain.md or esdm pin. The skill's
# recommended path migrates the glossary into a new model. Passes when
# docs/agents/domain.md names a model dir, `esdm lint` passes on it, esdm is
# pinned (.esdm-version as this skill ships it, and either
# scripts/fetch-esdm.sh for the repo-local install or `esdm` on PATH recorded
# as the command), and GLOSSARY.md is now generated from the model.
#
# The scratch repo has no remote, so the task picks the local-markdown tracker:
# a GitHub tracker would stop the run for want of a repo.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

judge() {
  local repo="$1/repo" model_dir
  model_dir="$(model_dir "$repo")"
  expect "docs/agents/domain.md names a model dir" test -n "$model_dir" || return 1
  # On an empty model dir, esdm lint fails with "no esdm files found".
  expect "esdm lint passes on the model dir" quietly "$(eval_esdm)" lint -d "$repo/$model_dir" || return 1
  expect "esdm is pinned" esdm_pinned "$repo" || return 1
  expect "GLOSSARY.md is generated from the model" quietly diff -q "$repo/GLOSSARY.md" \
    <(echo "$EVAL_GLOSSARY_MARKER"; "$(eval_esdm)" glossary -d "$repo/$model_dir") || return 1
}

# esdm_pinned <repo>: .esdm-version is the skill's pin, and domain.md records
# either the repo-local .tools/esdm, fetched by scripts/fetch-esdm.sh, or esdm
# on PATH as the esdm command.
esdm_pinned() {
  cmp -s "$1/.esdm-version" "$EVAL_REPO_ROOT/skills/engineering/setup-matt-pocock-skills/esdm-version" ||
    return 1
  case "$(sed -nE 's/.*\*\*esdm command\*\*: `([^`]+)`.*/\1/p' "$1/docs/agents/domain.md" | head -1)" in
    .tools/esdm) test -f "$1/scripts/fetch-esdm.sh" ;;
    esdm) true ;;
    *) false ;;
  esac
}

# model_dir <repo>: the model dir domain.md names, without a trailing slash.
model_dir() {
  sed -nE 's/.*The \*\*ESDM model\*\* in `([^`]+)`.*/\1/p' "$1/docs/agents/domain.md" 2>/dev/null |
    head -1 | sed 's|/*$||'
}

EVAL_FIXTURE=glossary-only
run_scenario setup-matt-pocock-skills setup-matt-pocock-skills "Track issues as local markdown."

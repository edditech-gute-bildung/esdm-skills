#!/usr/bin/env bash
# Run every tests/eval/*.eval.sh, or the ones named (improve-codebase-architecture
# runs improve-codebase-architecture.eval.sh); exit non-zero if any fails.
# Runs are kept under EVAL_OUT, a fresh dir under $TMPDIR by default; see lib.sh.
set -uo pipefail

eval_dir="$(cd "$(dirname "$0")" && pwd)"
# All evals of one invocation share an output dir, so the fixture is fetched once.
export EVAL_OUT="${EVAL_OUT:-$(mktemp -d "${TMPDIR:-/tmp}/esdm-evals.XXXXXX")}"

if [ "$#" -gt 0 ]; then
  evals=()
  for name in "$@"; do
    name="$(basename "$name" .eval.sh)"
    file="$eval_dir/$name.eval.sh"
    [ -f "$file" ] || { echo "run.sh: no eval $name" >&2; exit 2; }
    evals+=("$file")
  done
else
  shopt -s nullglob
  evals=("$eval_dir"/*.eval.sh)
  [ "${#evals[@]}" -gt 0 ] || { echo "run.sh: no evals in $eval_dir" >&2; exit 2; }
fi

status=0
for eval_file in "${evals[@]}"; do
  echo "== $(basename "$eval_file")"
  bash "$eval_file" || status=1
done
echo "runs kept in $EVAL_OUT"
exit "$status"

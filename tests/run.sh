#!/usr/bin/env bash
# Run every tests/*.test.sh; exit non-zero if any fails.
set -uo pipefail

status=0
for test_file in "$(dirname "$0")"/*.test.sh; do
  echo "== $(basename "$test_file")"
  bash "$test_file" || status=1
done
exit "$status"

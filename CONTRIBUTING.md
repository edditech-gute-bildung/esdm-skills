# Contributing

Run `tests/run.sh` before you push. It needs network, `jq`, `ruby` and `node`. CI runs it on every push and pull request.

## Running the behavioural evals

`tests/run.sh` checks that the forks are well-formed; the evals in `tests/eval/` check that an agent following a fork does the right thing ([ADR-0001](docs/adr/0001-behavioural-skill-tests.md)). They run `claude -p` and cost tokens, so they never run in CI on push. Run them on demand:

```sh
tests/eval/run.sh                                # every tests/eval/*.eval.sh
tests/eval/run.sh improve-codebase-architecture  # the ones named
```

Each scenario runs 3 times in a fresh scratch repo (the pinned fixture, `sample/`, the pinned `esdm`, the forks from your working tree and the companion skills pinned in `tests/eval/companions`) and passes when 2 runs pass. It needs `claude` logged in, network, `git`, `curl` and `jq`. Every run keeps its scratch repo, `$TMPDIR` (where reports land), `transcript.jsonl`, `result.txt` and `diff.patch`; the output prints where. Override with `EVAL_MODEL`, `EVAL_RUNS`, `EVAL_PASS`, `EVAL_MAX_TURNS`, `EVAL_MAX_BUDGET_USD` and `EVAL_OUT`.

To add a scenario, write `tests/eval/<name>.eval.sh`: source `lib.sh`, define `judge <run dir>` with deterministic checks on what the run left behind, and call `run_scenario <name> <skill> [<task>]`.

## Syncing a forked skill with upstream

Each forked skill records the `mattpocock/skills` commit it is based on as its `base` in `upstream.json`. Every Monday, the `upstream-drift` workflow compares each skill's whole upstream folder between its base and upstream HEAD. It keeps one open `needs-triage` issue per skill that drifted, moved or disappeared upstream. Run `scripts/upstream-drift.sh` to check by hand.

Syncs are done by hand, one skill at a time:

1. **Read the upstream diff** from the skill's base to the target commit, in a clone of `mattpocock/skills`: `git diff <base> <target> -- <skillPath>`. For a skill that moved upstream, compare the two folders instead: `git diff <base>:<old path> <target>:<new path>`.
2. **Apply what fits. ESDM wins.** Drop or adapt any upstream change that conflicts with an ESDM decision.
3. **Bump the base in the same commit.** Set the skill's `base` in `upstream.json` to the target commit.
   - For a patch-tier skill, also update each edit's `line` and `from` to match the new upstream. `scripts/check-patch-tier.sh` checks them.
   - If upstream moved the folder, move the fork's folder to the same path and update `skillPath`. Forked skills mirror upstream's layout.
4. **Commit** as `sync(<skill>): upstream <short-sha>`.
   - List each hunk you rejected on purpose in the body, with the reason.
   - Close the drift issue from the commit (`Closes #<n>`).

There are no stored patches and no separate changelog. The commit history is the sync record.

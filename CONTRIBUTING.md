# Contributing

Run `tests/run.sh` before you push. CI runs it on every push and pull request.

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

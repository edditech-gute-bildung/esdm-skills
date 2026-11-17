# Behavioural skill tests run headless on the library fixture, off the per-push path

`tests/run.sh` only checks that the forked skills are well-formed; it never shows that an agent following a skill does the right thing. We test that with behavioural evals in `tests/eval/`: a script builds a scratch repo from the pinned `esdm-library-example` fixture plus `sample/` (the dry-run recipe in `sample/README.md`), copies the forks from the working tree, runs the skill headless with `claude -p "/<skill> <task>"`, and judges the result by deterministic checks on what the run leaves behind (`esdm lint`, `node --test`, resolving `esdm:` references, expected names in the report). Agent runs cost tokens and are non-deterministic, so they stay out of `checks.yml`: they run on demand locally and in a `workflow_dispatch` / pre-release workflow, each scenario N=3 times with a pass threshold of 2/3.

## Considered Options

- **`claude plugin eval` suites**: rejected for now; it ties the tests to the plugin format while the forks ship via `npx skills`.
- **LLM judge on the transcript**: only for properties no file check can see (e.g. "asked before writing"); deterministic checks come first.
- **Running on every push**: rejected for cost and flakiness; a single flaky run would block unrelated changes.

## Consequences

- Runs pin the model (`claude-sonnet-5-5`, override with `EVAL_MODEL`) so pass rates compare across runs, and use `--permission-mode bypassPermissions` confined to the scratch dir.
- Headless runs can't answer questions, so the prompt carries a preamble: "Non-interactive run: wherever you would ask, take your recommended answer and note it." Skills whose value is the interview (`grill-with-docs`, `to-spec`, `triage`) need an Agent SDK driver with canned answers before they can be tested.
- Each run keeps its `stream-json` transcript and the scratch repo's diff for diagnosis.

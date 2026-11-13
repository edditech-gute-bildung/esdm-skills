# Sample codebase

A small library codebase that implements part of the fixture's model ([esdm-library-example](https://github.com/edditech-gute-bildung/esdm-library-example), pinned in `.esdm-fixture`). Dry runs of the forked skills use it as the code side of the fixture. Plain JavaScript, no dependencies: run `npm test` (Node's built-in test runner).

To set up a dry run, copy this folder into a scratch repo next to the fixture's `model/` and `GLOSSARY.md`, with a `docs/agents/domain.md` naming `model/` as the model dir.

Each test that pins a Scenario carries its `esdm:` comment, as the `tdd` skill writes it. `tests/sample.test.sh` checks that every such comment names a Scenario in the fixture, and that the test below it is named after that Scenario.

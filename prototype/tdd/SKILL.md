---
name: tdd
description: Test-driven development. Use when the user wants to build features or fix bugs test-first, mentions "red-green-refactor", or wants integration tests.
---

# Test-Driven Development

TDD is the red → green loop. This skill is the reference that makes that loop produce tests worth keeping: what a good test is, where tests go, the anti-patterns, and the rules of the loop. Every section applies on every cycle: consult them before and during the loop, not after.

<!-- PROTOTYPE for "How should GWT-WRITING.md read?" (#12). Upstream tdd plus the Scenario sections. Throwaway. -->

When exploring the codebase, read `GLOSSARY.md` so test names and interface vocabulary match the project's domain language, and respect ADRs in the area you're touching. `GLOSSARY.md` is generated from the ESDM model in the dir `docs/agents/domain.md` names; the model is what you change.

## Scenarios: the agreed slices

When the unit you're building has a Given-When-Then Feature (`esdm view -d <model dir> --with-details` lists them under their unit), its Scenarios drive the loop.

**At the start,** list the unit's Scenarios and mark the ones that already have a test (search for their `esdm:` comment). The untested ones are the slice list, in Feature order. The user can reorder or skip.

**One Scenario is one red → green slice,** at the seam its variant fixes. Scenarios are already agreed seams; a test at any other seam still needs confirming, as below.

| Variant | Seam | Arrange (given) | Act (when) | Assert (then) |
|---|---|---|---|---|
| Aggregate / DCB | Command handling | past Events | the Command | the Events, or the rejection's invariant |
| Process Manager | Reaction | past Events | the Event or Timer | emitted Commands, timers, state, ended |
| Read Model | Projection + Query | project the Events | the Query | the result |

- Expected values come **straight from the Scenario**. It is the independent source of truth the anti-patterns below ask for.
- The **test name** is the Scenario `name`, word for word. The line above the test carries the Feature's `esdm:` reference, then the Scenario name (references stop at the Feature):
  `// esdm:domain=library/bounded-context=lending/aggregate=reader-account/feature=borrowing-a-book scenario=reader-with-five-loans-is-refused-a-sixth`

**A gap:** when you meet behaviour no Scenario covers, stop and propose the Scenario (given, when, then, with the values you'd assert). Call the Skill tool with "domain-modeling" to write it once the user confirms, then carry on with it as the next slice. If the user declines, test it at a confirmed seam as below.

**When the code and a Scenario disagree,** the Scenario wins: fix the code. If the user decides the Scenario is wrong, it changes first, through "domain-modeling"; then update the test from the changed Scenario. A test never drifts from its Scenario.

## What a good test is

Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't. A good test reads like a specification: "user can checkout with valid cart" tells you exactly what capability exists, and it survives refactors because it doesn't care about internal structure.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking guidelines.

## Seams: where tests go

A **seam** is the public boundary you test at: the interface where you observe behavior without reaching inside. Tests live at seams, never against internals.

**Test only at pre-agreed seams.** Before writing any test, write down the seams under test and confirm them with the user. No test is written at an unconfirmed seam. You can't test everything, so agreeing the seams up front is how testing effort lands on the critical paths and complex logic instead of every edge case.

Ask: "What's the public interface, and which seams should we test?" Give each proposed seam a one-line note on what it catches and what it misses.

When the shape of that interface is itself in question (how deep the module is, where the seam belongs, what the interface should expose), call the Skill tool with "codebase-design" for the vocabulary. It is the shared source of the module, interface, depth, seam, adapter, leverage and locality terms, and it is a reference to consult, not a session to run.

## Anti-patterns

- **Implementation-coupled**: mocks internal collaborators, tests private methods, or verifies through a side channel (querying the database instead of using the interface). The tell: the test breaks when you refactor but behavior hasn't changed.
- **Tautological**: the assertion recomputes the expected value the way the code does (`expect(add(a, b)).toBe(a + b)`, a snapshot derived by hand the same way, a constant asserted equal to itself), so it passes by construction and can never disagree with the code. Expected values must come from an independent source of truth: a known-good literal, a worked example, the spec.
- **Horizontal slicing**: writing all tests first, then all implementation. Bulk tests verify _imagined_ behavior: you test the _shape_ of things rather than user-facing behavior, the tests go insensitive to real changes, and you commit to test structure before understanding the implementation. Work in **vertical slices** instead: one test → one implementation → repeat, each test a **tracer bullet** that responds to what the last cycle taught you.

## Rules of the loop

- **Red before green.** Write the failing test first, then only enough code to pass it. Don't anticipate future tests or add speculative features.
- **One slice at a time.** One seam, one test, one minimal implementation per cycle.
- **Refactoring is not part of the loop.** It belongs to the review stage (see the `code-review` skill), not the red → green implementation cycle.

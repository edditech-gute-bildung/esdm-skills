<!-- PROTOTYPE for "How should GWT-WRITING.md read?" (#12). Throwaway. -->

# Writing Given-When-Then Features

Rules for writing Features (`apiVersion: schema.esdm.io/given-when-then/v1`, kind `feature`). For fields, read `schemas/given-when-then/v1.yaml`.

A Scenario is a **worked example** that `tdd` turns into one test, word for word. Its values become the test's expected values, so every value is one the user stands behind.

## When a unit gets a Feature

Features are opt-in **per unit** (Aggregate or DCB):

- **First invariant on a unit without a Feature:** offer to pin it with a Scenario. Say what accepting means: the first Feature turns on `uncovered-invariant`, so every invariant on the unit then needs a Scenario, and CI fails on the gap.
- **Declined:** the unit stays without Features for the rest of the session. Write one later only when the user asks.
- **Unit with a Feature:** every new invariant gets a Scenario, and every new Command a success Scenario, without asking.
- **Process Managers and Read Models** have no invariants: write their Features when the user asks, or when `tdd` proposes one.

## Set up the Feature

- **File:** `<bc>/features/<feature-name>.esdm.yaml`, one Feature per file. A Process Manager's Features go in `<domain>/features/`.
- **One Feature per capability**, usually one Command or Query, named after it: `borrow-book`. Merge Features only when the user asks.
- **`scope`** names the unit. Its variant fixes the shape of every Scenario (see the schema).

## Write a Scenario, one at a time

1. **Read it back** in prose:
   `<name>: given <events>, when <trigger>, then <outcome>`, with every value spelled out.
2. Once the user confirms it, write it and run the lint gate.

### Name

Kebab-case, saying the behaviour, not the mechanics: `reader-with-five-loans-is-refused-a-sixth`. The name becomes the test name, so make it read as a specification.

### Values

- Every `data`, `parameters`, `state`, `result` and `readModel` is **concrete**: literal values, as in a worked example. Write `data: {}` only for an empty payload.
- **Infer** what follows from the Scenario itself, like an id that carries over from `given` to `when`.
- **Ask** for every other value. A value you made up becomes an assertion the user never agreed to.
- Use **one cast** across a Feature's Scenarios (the same reader, the same book ids), so they read as variations of one story.

### Outcome

- **A rejection** names the invariant it protects. A refusal with no invariant behind it means the invariant is missing: settle and write it first. A refusal that is really about who may act belongs on the Command's `actors`, not in a rejection.
- **`events: []`** means the trigger is idempotent. Write it only when the user says so.
- **Read Models:** assert `result`, the consumer's view. Use `readModel` only when the user wants the projection itself checked.
- **Process Managers:** list only the effects that happen. `ended: true` when the reaction retires the instance; otherwise leave it out.

```yaml
apiVersion: schema.esdm.io/given-when-then/v1
kind: feature
name: borrow-book
scope: { domain: library, boundedContext: lending, aggregate: reader-account }
scenarios:
  - name: reader-with-five-loans-is-refused-a-sixth
    given:
      - { event: book-borrowed, data: { readerId: r-17, bookId: b-1 } }
      # … b-2 to b-5
    when: { command: borrow-book, data: { readerId: r-17, bookId: b-6 } }
    then:
      rejection: { invariant: loan-limit }
```

## A Scenario proposed by `tdd`

`tdd` stops when it meets behaviour no Scenario covers and proposes one. Treat the proposal as a draft:

1. Read it back and settle its values with the user, as above.
2. If the unit has no Feature yet, this is its opt-in: say what accepting means.
3. Once written and through the lint gate, hand back to `tdd`.

If the user declines, `tdd` carries on without a Scenario.

## Changing a Scenario

A Scenario changes only when the user decides it is wrong, never to match the code.

1. Change it here, through the lint gate.
2. `tdd` then updates the test from the changed Scenario.

A **rename** is one step: rename the Scenario, then rename the test that carries its name in its `esdm:` comment.

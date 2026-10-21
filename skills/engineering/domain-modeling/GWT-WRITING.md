# Writing Given-When-Then Features

Rules for writing Features (`apiVersion: schema.esdm.io/given-when-then/v1`, kind `feature`). For fields, read `schemas/given-when-then/v1.yaml`; this file only adds what the schema leaves open.

A Scenario is a **worked example** that `tdd` turns into one test, word for word. Its values become the test's expected values, so every value is one the user stands behind.

## When a unit gets a Feature

Features are opt-in **per unit** (Aggregate or DCB):

- **First invariant on a unit without a Feature:** offer to pin it with a Scenario. Say what accepting means: the first Feature turns on `uncovered-invariant`, so every invariant on the unit then needs a Scenario. Lint warns on the gap, and CI fails on it under `--warnings-as-errors`.
- **Declined:** the unit stays without Features for the rest of the session. Write one later only when the user asks.
- **Unit with a Feature:** every new invariant gets a Scenario, and every new Command a success Scenario, without asking.
- **Process Managers and Read Models** have no invariants: write their Features when the user asks, or when `tdd` proposes one.

## Set up the Feature

- **File:** `<bc>/<feature-name>.feature.esdm.yaml`, next to the Bounded Context's core files, one Feature per file, named after the Feature: `lending/borrowing-a-copy.feature.esdm.yaml`. A Process Manager's Features go in the folder where the Process Manager lives: `integration/<feature-name>.feature.esdm.yaml`.
- **One Feature per capability**, usually one Command or Query, named as a gerund phrase: `borrowing-a-copy` for `borrow`. Merge Features only when the user asks.
- **`scope`** names the unit. Its variant fixes the shape of every Scenario (see the schema).

The Feature for the `borrow` Command on the `copy` Aggregate, with its first Scenario:

```yaml
apiVersion: schema.esdm.io/given-when-then/v1
kind: feature
name: borrowing-a-copy
description: >-
  Pins down the one rule the lending context exists to protect: a copy that is
  already out cannot be borrowed again. Note the shape — an aggregate feature
  names events by bare name, because `scope` already fixes the producer.
scope:
  domain: library
  boundedContext: lending
  aggregate: copy
scenarios:
  - name: available-copy-can-be-borrowed
    given:
      - event: stocked
        data:
          copy-id: 11111111-1111-1111-1111-111111111111
          isbn: "978-0201616224"
    when:
      command: borrow
      data:
        copy-id: 11111111-1111-1111-1111-111111111111
        borrower: card-4711
        due-on: "2026-09-14"
      actor: borrower
    then:
      events:
        - event: borrowed
          data:
            copy-id: 11111111-1111-1111-1111-111111111111
            isbn: "978-0201616224"
            borrower: card-4711
            due-on: "2026-09-14"
```

## Write a Scenario, one at a time

1. **Read it back** in prose:
   `<name>: given <events>, when <trigger>, then <outcome>`, with every value spelled out.
2. Once the user confirms it, write it and run the lint gate.

### Name

Kebab-case, saying the behaviour, not the mechanics: `copy-already-on-loan-is-refused`. The name becomes the test name, so make it read as a specification.

### Values

- Every `data`, `parameters`, `state`, `result` and `readModel` is **concrete**: literal values, as in a worked example. Write `data: {}` only for an empty payload.
- **Infer** what follows from the Scenario itself, like an id that carries over from `given` to `when`.
- **Ask** for every other value. A value you made up becomes an assertion the user never agreed to.
- Use **one cast** across a Feature's Scenarios (the same copy, the same borrowers), so they read as variations of one story.

### Outcome

- **A rejection** names the invariant it protects. A refusal with no invariant behind it means the invariant is missing: settle and write it first. A refusal that is really about who may act belongs on the Command's `actors`, not in a rejection.
- **`events: []`** means the trigger is idempotent. Write it only when the user says so.
- **Read Models:** assert `result`, the consumer's view. Use `readModel` only when the user wants the projection itself checked.
- **Process Managers:** list only the effects that happen. `ended: true` when the reaction retires the instance; otherwise leave it out.

A later Scenario in the same Feature, a rejection naming the invariant it protects:

```yaml
  - name: copy-already-on-loan-is-refused
    description: >-
      The second request is rejected outright rather than queued — a waiting
      list would be a different decision, and is not modelled.
    given:
      - event: stocked
        data:
          copy-id: 11111111-1111-1111-1111-111111111111
          isbn: "978-0201616224"
      - event: borrowed
        data:
          copy-id: 11111111-1111-1111-1111-111111111111
          isbn: "978-0201616224"
          borrower: card-4711
          due-on: "2026-09-14"
    when:
      command: borrow
      data:
        copy-id: 11111111-1111-1111-1111-111111111111
        borrower: card-0815
        due-on: "2026-09-21"
      actor: borrower
    then:
      rejection:
        invariant: only-available-copies-can-be-borrowed
```

## A Scenario proposed by `tdd`

`tdd` stops when it meets behaviour no Scenario covers and proposes one. Treat the proposal as a draft:

1. Read it back and settle its values with the user, as above.
2. If the unit has no Feature yet, this is its opt-in: say what accepting means.
3. Once written and through the lint gate, hand back to `tdd`.

If the user declines, `tdd` carries on without a Scenario, testing at a seam the user confirms.

## Changing a Scenario

A Scenario changes only when the user decides it is wrong, never to match the code.

1. Change it here, through the lint gate.
2. `tdd` then updates the test from the changed Scenario.

A **rename** is one step: rename the Scenario, then rename the test whose `esdm:` comment names it.

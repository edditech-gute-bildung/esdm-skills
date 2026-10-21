# Domain Docs

How the engineering skills consume this repo's domain model.

## The model

- The **ESDM model** in `[esdm/]` (the **model dir**) is the single source of truth for domain language.
- **esdm command**: `[esdm | .tools/esdm]`, pinned in `.esdm-version`. Always pass `-d [esdm/]`.

## Before exploring, read these

- **`GLOSSARY.md`** at the repo root: generated from the model by `esdm glossary`, one section per Bounded Context. **Never edit it**; language changes go through `/domain-modeling`, which writes the model and regenerates this file.
- **`esdm view -d [esdm/]`** when you need structure (aggregates, commands, events, invariants), not just vocabulary.
- **`docs/adr/`**: ADRs that touch the area you're working in. ADRs hold the *why*; the model holds the *what*.

If any of these don't exist yet, **proceed silently**. `/domain-modeling` creates them lazily.

## Use the model's vocabulary

When your output names a domain concept (issue title, refactor proposal, hypothesis, test name), use the term as `GLOSSARY.md` defines it. Never use a term listed under _Avoid_. A missing term is a signal: you're inventing language, or there's a real gap to note for `/domain-modeling`.

## Point at elements with `esdm:` references

When your output refers to a specific model element, cite it as an `esdm:` reference (e.g. `esdm:domain=library/bounded-context=lending/aggregate=loan/command=borrow-book`).

## Flag conflicts

If your output contradicts the model (a command that doesn't exist, an invariant your change breaks) or an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders), but worth reopening because…_

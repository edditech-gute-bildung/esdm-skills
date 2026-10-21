<!-- PROTOTYPE for "How should the rewritten domain-modeling skill read?" (#11). Throwaway. -->

# Writing the ESDM core model

Rules for writing core model documents (`apiVersion: schema.esdm.io/core/v1`). For kinds and fields, read `schemas/core/v1.yaml`; this file only adds what the schema leaves open.

## Placement

- Write inside the model dir, following the schema's `x-esdm-project-layout`.
- Create Domain and Bounded Context documents **lazily**, when the first thing inside them is written.
- **Infer** the Bounded Context from the conversation; ask when unclear. Creating a new Bounded Context is always the user's call.

## Terms and elements

Terms and elements are written independently. Many Commands and Events never get a term; some terms never become an element.

### Terms

A term goes into the Bounded Context's `ubiquitousLanguage[]` once its **meaning** is settled.

- **Only terms specific to this domain.** General programming concepts (timeouts, error types, utility patterns) stay out, however often the project uses them.
- **Be opinionated.** Pick one canonical term. Every rejected synonym goes into `avoid[]`, always with a `reason`.
- **Keep definitions tight.** One or two sentences: what it _is_, not what it does.
- **`language`** (BCP 47) is asked once per Bounded Context, when its first term is written. It may differ from the language of the session.
- **`translations`** only when the user asks.
- **Across contexts**, when two Bounded Contexts use different terms for one concept, pair them in the Context Mapping's `terms`, creating the mapping if it's missing.

### Elements

Any core kind is written once its **shape** is settled.

- **Required fields not yet discussed** get the smallest value the schema accepts: `data: {}`, `state: {type: object}`.
- **Required fields with no neutral value are asked about, never made up:**
  - `identifiedBy.field`, which must exist in `state`
  - `deliveryGuarantee`, plus `idempotency` when it is `at-least-once`
  - `correlatedBy`
- **`description`** only when the purpose isn't obvious from name and kind: one sentence about the domain, free of implementation detail.

## Linking ADRs

- An element names its ADR in `metadata.annotations.adr: docs/adr/NNNN-slug.md`, comma-separated for several.
- The ADR cites the element by its `esdm:` reference, e.g. `esdm:domain=library/bounded-context=lending/aggregate=loan`.

## Renames

A rename is one step:

1. Rename in the model.
2. Search the repo for `esdm:` references and `adr` annotations naming the old element, and fix them.
3. Move the old term into `avoid[]` with a reason.

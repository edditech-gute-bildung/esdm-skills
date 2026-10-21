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

A Bounded Context's first term, with its `language` and a rejected synonym:

```yaml
language: en
ubiquitousLanguage:
  - term: Copy
    definition: >-
      One physical volume on the shelf. A title with three copies is one book in
      cataloging and three copies here.
    avoid:
      - term: Book
        reason: >-
          In cataloging a book is a title. Reusing the word here would blur the
          exact distinction this context exists to make.
```

### Elements

Any core kind is written once its **shape** is settled.

- **Required fields not yet discussed** get the smallest value the schema accepts: `data: {}`, `state: {type: object}`.
- **Required fields with no neutral value are asked about, never made up:**
  - `identifiedBy.field`, which must exist in `state`
  - `deliveryGuarantee`, plus `idempotency` when it is `at-least-once`
  - `correlatedBy`

  An Aggregate identified by a field the user named, which `state` holds:

  ```yaml
  identifiedBy:
    source: state
    field: isbn
  state:
    type: object
    properties:
      title: { type: string }
      author: { type: string }
      isbn: { type: string }
    required: [title, author, isbn]
  ```

  A Process Manager's delivery, idempotency and correlation, each as the user decided it:

  ```yaml
  deliveryGuarantee: at-least-once
  idempotency:
    owner: self
    strategy: >-
      Each instance records which reminders it has sent in `reminders-sent`, so a
      redelivered `borrowed` neither starts a second chase nor re-sends a notice.
  correlatedBy:
    source: event-field
    field: copy-id
  ```

- **`description`** only when the purpose isn't obvious from name and kind: one sentence about the domain, free of implementation detail.

## Linking ADRs

- An element names its ADR in `metadata.annotations.adr: docs/adr/NNNN-slug.md`, comma-separated for several.
- The ADR cites the element by its `esdm:` reference, e.g. `esdm:domain=library/bounded-context=lending/aggregate=copy`.

## Renames

A rename is one step:

1. Rename in the model.
2. Search the repo for `esdm:` references and `adr` annotations naming the old element, and fix them.
3. Move the old term into `avoid[]` with a reason.

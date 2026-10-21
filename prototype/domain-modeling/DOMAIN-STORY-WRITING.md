<!-- PROTOTYPE for "How should the rewritten domain-modeling skill read?" (#11). Throwaway. -->

# Writing Domain Stories

Rules for capturing a Domain Story (`apiVersion: schema.esdm.io/domain-storytelling/v1`, kind `domain-story`). For fields, read `schemas/domain-storytelling/v1.yaml`.

## Set up the story

- **File:** `<model dir>/stories/<story-name>.esdm.yaml`, one story per file. When the model dir holds several Domains: `<domain>/stories/`.
- **Scope:** the Domain only. If its Domain document doesn't exist, ask for the name and create it. A story never creates a Bounded Context.
- **`pointInTime`:** always ask: `as-is` or `to-be`.
- `granularity`, `domainPurity`, groups and annotations: only when the user brings them up.

## Capture, Sentence by Sentence

The **user tells** the story; you transcribe.

1. Read each Sentence back as `<n>. <actor> – <activity> – <work object> – to <actor>`.
2. Once the user confirms it, write that Sentence to the file and run the lint gate.
3. Repeat until the user says the story is complete.

A Sentence becomes two edges, with the activity as the first edge's `label`:

```yaml
# "1. librarian – lends – book – to reader"
sentences:
  - sequenceNumber: 1
    edges:
      - from: { actor: librarian }
        to: { workObject: book }
        label: lends
      - from: { workObject: book }
        to: { actor: reader }
        label: to
```

- Names are the user's words, kebab-cased: `Head Librarian` → `head-librarian`.
- Declare an Actor in `actors[]` or a Work Object in `workObjects[]` only when it carries an annotation or groups; otherwise the edge names it directly.
- Two Sentences with the same `sequenceNumber` happen in parallel.

**Check the vocabulary** of every Actor and Work Object against the Domain's ubiquitous language and its `avoid[]` lists:

- **An avoided term**: challenge it on the spot, as in _challenge against the model_.
- **An unknown noun**: keep it, and add it to the list of candidates for graduation.

Everything else stays in the user's words.

## Graduate, proposal by proposal

Once the story is complete, offer a **graduation** pass. It is a separate pass, never folded into capture.

1. Walk the Sentences in order and propose one candidate at a time:
   - story Actors → `actor` documents
   - activities → Commands, plus the Events they cause
   - Work Objects → terms, or structural elements (Aggregate, Entity, Value Object)
2. Run each candidate through _sharpen fuzzy kinds_, then write it following [ESDM-WRITING.md](./ESDM-WRITING.md).
3. Add the element's `esdm:` reference to the story's `metadata.annotations.graduated-to`, comma-separated.

## After graduation

The story stays as told. A changed workflow is a new story, or a `to-be` story against the old one.

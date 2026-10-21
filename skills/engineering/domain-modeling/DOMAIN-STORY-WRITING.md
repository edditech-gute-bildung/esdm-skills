# Writing Domain Stories

Rules for capturing a Domain Story (`apiVersion: schema.esdm.io/domain-storytelling/v1`, kind `domain-story`). For fields, read `schemas/domain-storytelling/v1.yaml`; this file only adds what the schema leaves open.

## Set up the story

- **File:** one story per file, named after the story:
  - A story that stays within one Bounded Context goes in that context's folder as `<bc>/<story-name>.story.esdm.yaml`: `reservations/collecting-a-hold.story.esdm.yaml`.
  - A story that spans several contexts goes in the model root as `<story-name>.story.esdm.yaml`, next to the other domain-level documents.
  - If it isn't clear whether the story spans contexts, ask the user where it belongs.
- **Scope:** the Domain only; the folder is just a convention. If the Domain document doesn't exist, ask for its name and create it. A story never creates a Bounded Context.
- **`pointInTime`:** always ask: `as-is` or `to-be`.
- `granularity`, `domainPurity`, groups and annotations: only when the user brings them up.

## Capture, Sentence by Sentence

The **user tells** the story; you transcribe.

1. Read each Sentence back as `<n>. <actor> – <activity> – <work object> – <link> <actor>`, with its sequence number. Leave out `– <link> <actor>` when the work object goes to no one.
2. Once the user confirms it, write that Sentence to the file and run the lint gate. Never batch Sentences.
3. Repeat until the user says the story is complete.

The activity is the first edge's `label`. When the work object goes on to an actor, a second edge carries it there, labelled with the link (`to`, unless the user says otherwise). The Sentence read back as `3. librarian – prints for – due-date-slip – goes home with borrower`:

```yaml
  - sequenceNumber: 3
    workObjects:
      - name: due-date-slip
        annotation: >-
          Printed and tucked into the copy. The borrower treats this, not any
          email, as the real record.
    edges:
      - from:
          actor: librarian
        to:
          workObject: due-date-slip
        label: prints for
      - from:
          workObject: due-date-slip
        to:
          actor: borrower
        label: goes home with
```

- Names are the user's words, kebab-cased: `Due Date Slip` → `due-date-slip`.
- Declare an Actor in `actors[]` or a Work Object in the Sentence's `workObjects[]` only when it carries an annotation or groups; otherwise the edge names it directly.
- Two Sentences with the same `sequenceNumber` happen in parallel.

**Check the vocabulary** of every Actor and Work Object against the Domain's ubiquitous language and its `avoid[]` lists. Lint doesn't connect story names to the core model, so you do:

- **An avoided term**: challenge it on the spot, as in _challenge against the model_.
- **An unknown noun**: keep it, and add it to the list of candidates for graduation.

Everything else stays in the user's words.

## Graduate, proposal by proposal

Once the story is complete, offer a **graduation** pass. It is a separate pass, never folded into capture, and never automatic.

1. Walk the Sentences in order and propose one candidate at a time:
   - story Actors → `actor` documents
   - activities → Commands, plus the Events they cause
   - Work Objects → terms, or structural elements (Aggregate, Entity, Value Object)
2. Run each candidate through _sharpen fuzzy kinds_. Ask for every required field with no neutral value; never make one up.
3. Write it following [ESDM-WRITING.md](./ESDM-WRITING.md), through the lint gate.
4. Add the element's `esdm:` reference to the story's `metadata.annotations.graduated-to`, comma-separated, e.g. `esdm:domain=library/bounded-context=lending/aggregate=copy`. Run the lint gate again.

## After graduation

The story stays as told. A changed workflow is a new story, or a `to-be` story against the old one.

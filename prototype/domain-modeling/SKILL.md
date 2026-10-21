---
name: domain-modeling
description: Build and sharpen a project's ESDM domain model. Use when discussing domain terminology, writing or editing `*.esdm.yaml` model files or Domain Stories, or recording or editing an ADR.
---

<!-- PROTOTYPE for "How should the rewritten domain-modeling skill read?" (#11). Throwaway. -->

# Domain Modeling

Actively build and sharpen the project's ESDM model as you design: challenge terms, probe edge cases with scenarios, and write the model and decisions down the moment they settle. Merely _reading_ the model or `GLOSSARY.md` for vocabulary is not this skill; this skill is for _changing_ the model.

The ESDM model is the single source of truth for domain language. `docs/agents/domain.md` names the **model dir**. ESDM's vocabulary (what each kind means, which fields it takes) lives in the schemas under `schemas/`; read their descriptions rather than guessing.

## Start of session

1. **Get your bearings.** Run `esdm view -d <model dir>` for the shape, and `esdm glossary -d <model dir> <domain>/<bc>` for the language of the context you're in.
2. **Offer a Domain Story, once.** Before writing anything, ask whether the user wants to tell a Domain Story. If the Domain already has stories, list them by name and `pointInTime` and offer: a new story, a `to-be` story against an existing `as-is` one, or skip. On yes, follow [DOMAIN-STORY-WRITING.md](./DOMAIN-STORY-WRITING.md). A skip holds for the rest of the session: tell a story later only when the user asks for one.

## During the session

### Challenge against the model

When the user says something that conflicts with the model, call it out immediately. Conflicts with terms count: "Your model defines 'cancellation' as X, but you seem to mean Y." So do conflicts with structure: "You said partial cancellation, but `order` only has a `cancel` command. Which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account': do you mean the Customer or the User? Those are different things."

### Sharpen fuzzy kinds

When a concept could be modeled as more than one kind (Aggregate or Dynamic Consistency Boundary; Policy, Process Manager or Event Handler; Entity or Value Object), put the choice to the user with a recommendation drawn from the schema descriptions. The user picks the kind.

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees with them and with the model's commands, events and invariants. Surface any contradiction.

### Write the model inline

When a term's meaning or an element's shape is settled, write it right there, following [ESDM-WRITING.md](./ESDM-WRITING.md). Capture as it happens, one write at a time.

Every write, to the core model or to a story, ends with the **lint gate**:

1. Run `esdm lint -d <model dir> --format json`.
2. **Errors** block: fix them before the conversation moves on. **Warnings** are noted for the end of the session.
3. Once lint passes, regenerate the glossary: `esdm glossary -d <model dir> > GLOSSARY.md`. `GLOSSARY.md` is generated output for readers; the model is where you write.

### Offer ADRs sparingly

The model records _what_; ADRs record _why_. Only offer to create an ADR when all three are true:

1. **Hard to reverse**: the cost of changing your mind later is meaningful
2. **Surprising without context**: a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off**: there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).

## End of session

List the lint warnings left in the model, so the user can fix them before CI runs `esdm lint --warnings-as-errors`.

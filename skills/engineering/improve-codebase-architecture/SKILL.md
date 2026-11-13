---
name: improve-codebase-architecture
description: Scan a codebase for deepening opportunities against its ESDM model, present them as a visual HTML report, then grill through whichever one you pick.
disable-model-invocation: true
---

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities**: refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

This command reads the project's ESDM model as the **intended structure** and is built on a shared design vocabulary:

- Call the Skill tool with "codebase-design" for the architecture vocabulary (**module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality**) and its principles (the deletion test, "the interface is the test surface", "one adapter = hypothetical seam, two = real"). Use these terms exactly in every suggestion, and don't drift into "component," "service," "API," or "boundary."
- The ESDM model in the model dir (named in `docs/agents/domain.md`) says what the domain's parts are and how they connect; the code is compared against it. `GLOSSARY.md`, generated from the model, gives names to good seams; ADRs in `docs/adr/` record decisions this command should not re-litigate.
- **Two vocabularies, one per side.** ESDM kind names (Bounded Context, consistency unit, Context Mapping, Policy, …) name domain things; the `codebase-design` terms name code things. A **consistency unit** is an Aggregate or a dynamic consistency boundary (DCB).
- **The model wins.** Where code and model disagree, the code is what changes. A candidate may argue the model is wrong; if the user agrees, the model changes first, through "domain-modeling", before any decision on the code's shape.

## Process

### 1. Explore

Read the model first. `esdm` (the command named in `docs/agents/domain.md`) gives its structure: `esdm view -d <model dir> --with-details`, and its vocabulary: `esdm glossary -d <model dir>`. Then read any ADRs in the area you're touching.

**Scope before you scan: YAGNI.** Deepening a module pays off by making future changes to it easier, so put extra weight on the parts of the codebase that have recently changed. Decide *where* to look before you look:

- If the user named a direction (a module, a subsystem, a pain point, or an ESDM element such as a Bounded Context, a consistency unit or an `esdm:` reference), take it, and skip the inference below.
- Otherwise, walk back a good stretch of the commit history (`git log --oneline`) to find the codebase's hot spots, the files and areas that keep coming up, and let those paths pull your attention first. If the changes are scattered with no clear hot spot, widen the net.
- Report the scope in model terms: "most churn is in the lending Bounded Context's `copy` Aggregate".

**Map the code onto the model's elements** in the scope by:

- element names;
- ubiquitous-language terms, where a term the model lists under `avoid` is a smell;
- the `esdm:` comments above Scenario tests, which name a Feature and so its consistency unit.

An element in the scope that you can't locate in the code is a **Model ahead of code** drift item.

Then spawn a sub-agent to walk the codebase. Hand it the `esdm view` output as the intended structure, the mapping, and the [model kinds](#model-kinds-as-seam-candidates) and [findings](#findings) below. Don't follow rigid heuristics; explore organically and note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow**, with an interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?
- Where does the code's shape disagree with the model's?

Apply the **deletion test** to anything you suspect is shallow: would deleting it concentrate complexity, or just move it? A "yes, concentrates" is the signal you want.

#### Model kinds as seam candidates

Each kind suggests a module or a seam. These are candidates, not mandates: the `codebase-design` principles still decide.

| Kind | Candidate |
|---|---|
| Bounded Context | The outermost module; its seam is where other contexts touch it. |
| Aggregate / DCB | A deep module: its interface is its Commands and published Events, with its Invariants behind it. |
| Context Mapping | Names the seam between two context modules. Its type says where an adapter belongs and who owns it: anti-corruption layer on the downstream side, open host service and published language on the upstream side. |
| Read Model + Query | A module whose interface is the Query. |
| Event | The interface between publisher and consumers. Consumers depend on the Event, never on the publishing unit's module. |
| Policy / Event Handler | Its own module: its interface is the Events it handles plus the Commands or side effects it emits, and the subscription is its seam. |
| Process Manager | A strong deep-module candidate: correlation, state and timers sit behind "Events in, Commands out". |
| External System | Outbound or bidirectional: the seam where an adapter belongs. |

Published Events and Queries of an open host service or published-language mapping are the contract other contexts code against.

#### Findings

Deepening candidates, each a card in the report:

1. **Unit cut across**: one consistency unit's Invariants or Command handling spread over several modules.
2. **Unit shattered**: one consistency unit implemented as many shallow pass-through modules.
3. **Unmapped coupling**: one context's code reaches into another's with no Context Mapping between them, or against the mapping's type (a modeled anti-corruption layer with no adapter, a supplier depending on its customer).
4. **Reaction without a module**: a modeled Policy, Event Handler or Process Manager inlined into the publishing unit's Command handling.
5. **Style violation**: judged only as [Architecture style](#architecture-style) says.

Model drift, one line each in its own report section:

6. **Code ahead of model**: a domain concept, or a reaction to an Event, in the code with no modeled element.
7. **Model ahead of code**: a modeled element with no code, reported only within the scope.

#### Architecture style

The skill judges no architecture style or technology on its own. When an ADR declares one, look among the **installed** skills for one whose description covers it, and call it to judge **Style violation** and to shape the After side of each candidate. When none covers it, skip **Style violation** and say so in one line of the report: _"ADR-0003 declares a functional core; no installed skill covers it, so style isn't judged."_

A style evident in the code that no ADR declares stays unjudged and becomes one drift line: _"The code decides from past Events, but no ADR records that style. Record one?"_

Work within the declared style, and leave finding or installing skills to the user.

### 2. Present candidates as an HTML report

Write a self-contained HTML file to the OS temp directory so nothing lands in the repo. Resolve the temp dir from `$TMPDIR`, falling back to `/tmp` (or `%TEMP%` on Windows), and write to `<tmpdir>/architecture-review-<timestamp>.html` so each run gets a fresh file. Open it for the user (`xdg-open <path>` on Linux, `open <path>` on macOS, `start <path>` on Windows) and tell them the absolute path.

The report uses **Tailwind via CDN** for layout and styling, and **Mermaid via CDN** for diagrams where a graph/flow/sequence reliably communicates the structure. Mix Mermaid with hand-crafted CSS/SVG visuals: use Mermaid when relationships are graph-shaped (call graphs, dependencies, sequences), and hand-built divs/SVG when you want something more editorial (mass diagrams, cross-sections, collapse animations). Each candidate gets a **before/after visualisation**. Be visual.

For each candidate, render a card with:

- **Files**: which files/modules are involved
- **Model**: the `esdm:` references of the elements involved, e.g. `esdm:domain=library/bounded-context=lending/aggregate=copy`
- **Finding kind**: one of the five deepening findings, rendered as a badge
- **Problem**: why the current architecture is causing friction
- **Solution**: plain English description of what would change
- **Benefits**: explained in terms of locality and leverage, and how tests would improve
- **Before / After diagram**: side-by-side, custom-drawn, illustrating the shallowness and the deepening
- **Recommendation strength**: one of `Strong`, `Worth exploring`, `Speculative`, rendered as a badge

After the candidates, a short **Model drift** section: one line per drift item, with its `esdm:` reference or file, plus the style lines from [Architecture style](#architecture-style). End the report with a **Top recommendation** section: which candidate you'd tackle first and why.

**Use the model's vocabulary for the domain, and the `/codebase-design` vocabulary for the architecture.** If the model has a `copy` Aggregate, talk about "the copy module," not "the CopyManager," and not "the Book service."

**ADR conflicts**: if a candidate contradicts an existing ADR, only surface it when the friction is real enough to warrant revisiting the ADR. Mark it clearly in the card (e.g. a warning callout: _"contradicts ADR-0007, but worth reopening because…"_). Don't list every theoretical refactor an ADR forbids.

See [HTML-REPORT.md](HTML-REPORT.md) for the full HTML scaffold, diagram patterns, and styling guidance.

Do NOT propose interfaces yet. After the file is written, ask the user: "Which of these would you like to explore?"

### 3. Grilling loop

Once the user picks a candidate, call the Skill tool with "grilling" to walk the decision tree with them: constraints, dependencies, the shape of the deepened module, what sits behind the seam, what tests survive.

Side effects happen inline as decisions crystallize. The model, `GLOSSARY.md` and ADRs all change through "domain-modeling": call the Skill tool with "domain-modeling" for each one.

- **Naming a deepened module after a concept the model lacks?** `/domain-modeling` adds the term, and the element if one is needed. Code names follow the model.
- **Sharpening a fuzzy term during the conversation?** `/domain-modeling` sharpens it in the model right there.
- **User picks a drift item?** `/domain-modeling` settles it: model the concept, or mark the code as wrong.
- **User rejects the candidate with a load-bearing reason?** Offer an ADR, framed as: _"Want me to record this as an ADR so future architecture reviews don't re-suggest it?"_ Only offer when the reason would actually be needed by a future explorer to avoid re-suggesting the same thing; skip ephemeral reasons ("not worth it right now") and self-evident ones. On yes, `/domain-modeling` records the ADR and links it from the elements involved, in their `metadata.annotations.adr`.
- **What tests survive?** When the consistency unit has a Feature, its Scenarios are the deepened module's test surface: one Scenario per test, at the seam its variant fixes.
- **Want to explore alternative interfaces for the deepened module?** Call the Skill tool with "codebase-design" and use its design-it-twice parallel sub-agent pattern.

# Skill dependency inventory: GLOSSARY.md, ADRs, domain language

Answers [#6](https://github.com/edditech-gute-bildung/esdm-skills/issues/6) (map: #1).

**Source:** the skill files installed in `.agents/skills/` at commit `3aef03c` of this repo (all from `mattpocock/skills`, pinned in `skills-lock.json`). Every SKILL.md and supporting `.md` was searched for `GLOSSARY`, `GLOSSARY-MAP`, `adr`, `docs/agents/domain`, `domain-modeling`, `grilling`/`grill-*`, `glossary`, `vocabulary`, `domain language`, `ubiquitous`, and for skill invocations (`Skill tool with "…"`, `` `/skill-name` ``). Quotes are verbatim; the citation is `skill/file:line`.

## Classes

| Class | Meaning |
|---|---|
| **W** writes the model | Creates or edits `GLOSSARY.md` / `GLOSSARY-MAP.md` / ADRs itself |
| **RV** reads vocabulary | Reads `GLOSSARY.md` (or the "domain glossary") to name things |
| **RA** reads ADRs | Reads/respects ADRs, or flags conflicts with them |
| **D** delegates to domain-modeling | Calls the `domain-modeling` skill (and so writes the model indirectly) |
| **G** delegates to grilling | Calls the `grilling` skill |
| **C** configures | Writes the consumer rules / layout (`docs/agents/domain.md`) |
| **I** incidental | Mentions the terms without depending on the files |

## Summary

| Skill | Classes | Skills invoked by name |
|---|---|---|
| domain-modeling | W, RV, RA | none |
| grill-with-docs | D, G | grilling, domain-modeling |
| improve-codebase-architecture | RV, RA, D, G (W inline) | codebase-design, grilling, domain-modeling |
| triage | RV, RA, D, G (W inline) | grilling, domain-modeling; `/setup-matt-pocock-skills` |
| wayfinder | D, G | grilling, domain-modeling, research, prototype; `/setup-matt-pocock-skills` |
| setup-matt-pocock-skills | C (+ defines RV/RA rules) | refers to `/domain-modeling`, `/grill-with-docs`, `/improve-codebase-architecture`, `/triage`, `/wayfinder` |
| diagnosing-bugs | RV, RA | none |
| tdd | RV, RA | codebase-design |
| to-spec | RV, RA | `/setup-matt-pocock-skills` |
| to-tickets | RV, RA | `/setup-matt-pocock-skills` |
| pr | RV | none |
| wait-what | RV (incl. GLOSSARY-MAP) | none |
| codebase-design | RV (DESIGN-IT-TWICE only) | none |
| ask-matt | I (router; describes the flow) | names nearly every skill |
| grill-me | G | grilling |
| loop-me | G | `/grilling` |
| handoff, claude-handoff | I (reference ADRs, don't read them) | none |
| teach | I (own, separate `GLOSSARY.md` for a teaching workspace) | none |
| prototype | I ("domain language" in UI labels) | none |
| code-review | I ("domain concept" smell) | `/setup-matt-pocock-skills` |
| writing-fragments, writing-shape | I ("grilling session" as a style, no skill call) | none |
| setup-ts-deep-modules | I ("vocabulary" = codebase-design's) | codebase-design |
| grilling | none (pure interview primitive) | none |

No dependency at all: chief-of-staff, git-guardrails-claude-code, implement (calls tdd, code-review), implement-spec (calls tdd, code-review; `/setup-matt-pocock-skills`), migrate-to-shoehorn, research, retro (calls writing-for-agents), scaffold-exercises, setup-pre-commit, to-questionnaire, wizard, writing-beats, writing-for-agents. `implement` and `implement-spec` reach RV/RA only **transitively** through `tdd`.

## Per-skill detail

### domain-modeling (W, RV, RA): the owner of the model

| Passage | Class |
|---|---|
| "Actively build and sharpen the project's domain model as you design. This is the *active* discipline: challenging terms, inventing edge-case scenarios, and writing the glossary and decisions down the moment they crystallise. (Merely *reading* `GLOSSARY.md` for vocabulary is not this skill: that's a one-line habit any skill can do. This skill is for when you're changing the model, not just consuming it.)" (`SKILL.md:8`) | W; defines the read/write split |
| "If a `GLOSSARY-MAP.md` exists at the root, the repo has multiple contexts." (`SKILL.md:24`) | RV (layout) |
| "Create files lazily: only when you have something to write. If no `GLOSSARY.md` exists, create one when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed." (`SKILL.md:40`) | W |
| "When the user uses a term that conflicts with the existing language in `GLOSSARY.md`, call it out immediately." (`SKILL.md:46`) | RV |
| "When a term is resolved, update `GLOSSARY.md` right there. … Use the format in GLOSSARY-FORMAT.md." (`SKILL.md:62`) | W |
| "`GLOSSARY.md` should be totally devoid of implementation details." (`SKILL.md:64`) | W (content rule) |
| "Only offer to create an ADR when all three are true … Use the format in ADR-FORMAT.md." (`SKILL.md:68-74`) | W (ADR) |
| "ADRs live in `docs/adr/` and use sequential numbering" (`ADR-FORMAT.md:3`); "Scan `docs/adr/` for the highest existing number" (`ADR-FORMAT.md:27`) | W, RA |
| "If `GLOSSARY-MAP.md` exists, read it to find contexts … If neither exists, create a root `GLOSSARY.md` lazily" (`GLOSSARY-FORMAT.md:56-58`) | W, RV |

Invokes: none.

### grill-with-docs (D, G)

| Passage | Class |
|---|---|
| description: "A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go." (`SKILL.md:3`) | D (writes via domain-modeling) |
| "Call the Skill tool twice, for \"grilling\" and \"domain-modeling\"." (`SKILL.md:7`) | D, G |

Invokes: grilling, domain-modeling. The whole skill is this one line: it is the composition of the two.

### improve-codebase-architecture (RV, RA, D, G)

| Passage | Class |
|---|---|
| "This command is _informed_ by the project's domain model …" (`SKILL.md:11`) | RV |
| "The domain language in `GLOSSARY.md` gives names to good seams; ADRs in `docs/adr/` record decisions this command should not re-litigate." (`SKILL.md:14`) | RV, RA |
| "Read the project's domain glossary (`GLOSSARY.md`) and any ADRs in the area you're touching first." (`SKILL.md:25`) | RV, RA |
| "**Use GLOSSARY.md vocabulary for the domain, and the `/codebase-design` vocabulary for the architecture.**" (`SKILL.md:54`) | RV |
| "**ADR conflicts**: if a candidate contradicts an existing ADR, only surface it when the friction is real enough …" (`SKILL.md:56`) | RA |
| "call the Skill tool with \"grilling\" to walk the decision tree" (`SKILL.md:64`) | G |
| "call the Skill tool with \"domain-modeling\" to keep the domain model current as you go" (`SKILL.md:66`) | D |
| "Add the term to `GLOSSARY.md`. Create the file lazily …" / "Update `GLOSSARY.md` right there." / "Offer an ADR …" (`SKILL.md:68-70`) | W (inline, under domain-modeling) |
| "ADR callout (if applicable)" (`HTML-REPORT.md:53`) | RA (report format) |

Note: "glossary" in `HTML-REPORT.md:42,121,123` means the **codebase-design** glossary, not `GLOSSARY.md` (I).

Invokes: codebase-design, grilling, domain-modeling.

### triage (RV, RA, D, G)

| Passage | Class |
|---|---|
| "Explore the codebase using the project's domain glossary, respecting ADRs in the area. … search for an existing implementation of the requested behavior by domain concept" (`SKILL.md:70`) | RV, RA |
| "call the Skill tool twice, for \"grilling\" and \"domain-modeling\", and grill it into shape … sharpening domain terms and updating `GLOSSARY.md`/ADRs inline as decisions land." (`SKILL.md:76`) | D, G, W |

Invokes: grilling, domain-modeling; tells user to run `/setup-matt-pocock-skills`.

### wayfinder (D, G)

| Passage | Class |
|---|---|
| "**Grilling** (HITL): Conversation. The default case. Always call the Skill tool twice, for \"grilling\" and \"domain-modeling\"." (`SKILL.md:79`) | D, G |
| "**Name the destination.** Call the Skill tool twice, for \"grilling\" and \"domain-modeling\" …" (`SKILL.md:111`) | D, G |
| "If in doubt, call the Skill tool twice, for \"grilling\" and \"domain-modeling\"." (`SKILL.md:124`) | D, G |
| `wayfinder:grilling` label (`SKILL.md:65`) | I (label name) |

Invokes: grilling, domain-modeling, research, prototype; `/setup-matt-pocock-skills`. Does not read GLOSSARY/ADRs directly.

### setup-matt-pocock-skills (C)

| Passage | Class |
|---|---|
| "**Domain docs**: where `GLOSSARY.md` and ADRs live, and the consumer rules for reading them" (`SKILL.md:13`) | C |
| Explores "`GLOSSARY.md` and `GLOSSARY-MAP.md` at the repo root" / "`docs/adr/` and any `src/*/docs/adr/` directories" (`SKILL.md:25-26`) | C (detects layout) |
| "Default to **single-context** (one `GLOSSARY.md` + `docs/adr/` at the repo root)… Offer **multi-context** (a root `GLOSSARY-MAP.md` …)" (`SKILL.md:59-61`) | C |
| Writes "`docs/agents/domain.md`" and an AGENTS.md section pointing at it (`SKILL.md:68,99`) | C |
| `domain.md` (template copied into `docs/agents/domain.md`): "Before exploring, read these: `GLOSSARY.md` … `GLOSSARY-MAP.md` … `docs/adr/`" (`domain.md:5-9`) | defines RV, RA |
| "If any of these files don't exist, **proceed silently**. … The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily" (`domain.md:11`) | defines W ownership |
| "## Use the glossary's vocabulary … use the term as defined in `GLOSSARY.md`. Don't drift to synonyms … note it for `/domain-modeling`." (`domain.md:41-45`) | defines RV |
| "## Flag ADR conflicts … _Contradicts ADR-0007 …_" (`domain.md:47-51`) | defines RA |

Invokes: none directly; names `/domain-modeling`, `/grill-with-docs`, `/improve-codebase-architecture` in `domain.md`, `/triage` and `/wayfinder` in issue-tracker templates.

### diagnosing-bugs (RV, RA)

"When exploring the codebase, read `GLOSSARY.md` (if it exists) to get a clear mental model of the relevant modules, and check ADRs in the area you're touching." (`SKILL.md:10`). Invokes: none.

### tdd (RV, RA)

"When exploring the codebase, read `GLOSSARY.md` (if it exists) so test names and interface vocabulary match the project's domain language, and respect ADRs in the area you're touching." (`SKILL.md:10`). Invokes: codebase-design (`SKILL.md:26`).

### to-spec (RV, RA)

"Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching." (`SKILL.md:13`). Invokes: `/setup-matt-pocock-skills` (fallback).

### to-tickets (RV, RA)

"Ticket titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching." (`SKILL.md:21`). Invokes: `/setup-matt-pocock-skills` (fallback).

### pr (RV)

"Use the user's domain language from `GLOSSARY.md`." (`SKILL.md:37`). Invokes: none.

### wait-what (RV)

"use the ubiquitous language from `GLOSSARY.md` (follow `GLOSSARY-MAP.md` to the right one if the repo has more than one)." (`SKILL.md:7`). Invokes: none. Only consumer besides domain-modeling/setup that names `GLOSSARY-MAP.md`.

### codebase-design (RV, in one supporting file)

"Include both SKILL.md vocabulary and GLOSSARY.md vocabulary in the brief so each sub-agent names things consistently with the architecture language and the project's domain language." (`DESIGN-IT-TWICE.md:30`). Its own `## Glossary` (`SKILL.md:10`) is the architecture vocabulary (I). Invokes: none.

### ask-matt (I: router/documentation)

Describes, does not depend: "`/grill-with-docs` … it's stateful, retaining what it learns in `GLOSSARY.md` and ADRs" (`SKILL.md:19`); "`/domain-modeling`: sharpen the project's *domain* language … record a hard-to-reverse decision as an ADR. It's the active discipline `/grill-with-docs` drives to keep `GLOSSARY.md` a clean glossary." (`SKILL.md:66`); "`/grill-me` … builds no `GLOSSARY.md`" (`SKILL.md:85`); "`/triage`, `/wayfinder` and `/improve-codebase-architecture` all run [grilling] internally" (`SKILL.md:86`); "`/wait-what` … using the `GLOSSARY.md` vocabulary" (`SKILL.md:91`). Names nearly every skill. Its prose must be rewritten in a fork but it has no runtime dependency.

### grill-me (G), loop-me (G)

grill-me: "Call the Skill tool with \"grilling\"." (`SKILL.md:7`). loop-me: "Run a stateful `/grilling` session whose only output is **workflow** specs." (`SKILL.md:8`); its `## Vocabulary` (`SKILL.md:16`) is its own workflow vocabulary (I). Neither touches GLOSSARY/ADRs.

### Incidental only

| Skill | Passage | Why incidental |
|---|---|---|
| handoff | "Do not duplicate content already captured in other artifacts (specs, plans, ADRs, …). Reference them by path or URL instead." (`SKILL.md:12`) | Points at ADRs, never reads them |
| claude-handoff | same sentence (`SKILL.md:14`) | same |
| teach | "`GLOSSARY.md` is the canonical language for this teaching workspace." (`GLOSSARY-FORMAT.md:3`); learning records are "the teaching equivalent of ADRs" (`LEARNING-RECORD-FORMAT.md:5`) | Its own `GLOSSARY.md` in a teaching workspace: a name collision, not the project domain model. A fork must keep it separate. |
| prototype | "Every label is in **domain language**, not code" (`LOGIC.md:39`) | General style, no file |
| code-review | "Primitive Obsession: a primitive or string standing in for a domain concept" (`SKILL.md:49`) | Code smell, no file |
| writing-fragments, writing-shape | "Run a grilling session …" (`writing-fragments/SKILL.md:9`), "a grilling session inverted" (`writing-shape/SKILL.md:43`) | Style, no Skill call |
| setup-ts-deep-modules | "For the vocabulary … call the Skill tool with \"codebase-design\"" (`SKILL.md:11`) | Architecture vocabulary only |

## Observations for the fork decision

1. **One writer.** Only `domain-modeling` writes `GLOSSARY.md`/ADRs. Every other write path (grill-with-docs, improve-codebase-architecture, triage, wayfinder) goes through it with a "call the Skill tool … domain-modeling" line. Replacing that one skill (plus the call-site wording) moves all writes to the ESDM model.
2. **Readers hard-code the file name.** diagnosing-bugs, tdd, pr, wait-what, improve-codebase-architecture, codebase-design (DESIGN-IT-TWICE) name `GLOSSARY.md` literally. to-spec, to-tickets, triage say "the project's domain glossary" without a path: these are easier to re-point.
3. **`docs/agents/domain.md` is written, never read by name.** Only setup-matt-pocock-skills mentions it. Consumers find it through the AGENTS.md "Domain docs" pointer. That file and its template (`setup-matt-pocock-skills/domain.md`) are the single place the consumer rules live, so forking it changes reader behavior wherever a skill relies on AGENTS.md rather than a hard-coded path.
4. **`GLOSSARY-MAP.md`** appears only in domain-modeling, setup-matt-pocock-skills, and wait-what.
5. **ADR readers** (RA): domain-modeling, improve-codebase-architecture, triage, diagnosing-bugs, tdd, to-spec, to-tickets, plus the rules in `domain.md`. If ESDM keeps decisions elsewhere, these lines need the same treatment.
6. **grilling itself is model-agnostic.** It has no domain-file references, so it can stay as-is; the model coupling sits in the "grilling + domain-modeling" pairing used by grill-with-docs, triage, wayfinder.
7. **Transitive readers:** implement and implement-spec reach RV/RA only via tdd.

# ESDM extension documents: format, placement, linking, linting, CLI

Research for issue #3. Question: for the Domain Storytelling and Given-When-Then extensions, what are the file formats, where do the documents live relative to core model files, how do they reference core elements, what do their linter rules enforce, and does the CLI render, glossary or document them?

Sources: `thenativeweb/esdm` at commit `947c4d1` (2026-10-05). `documentation/` in that repo is the source of https://www.esdm.io (`documentation/mkdocs.yml`: `site_url: https://www.esdm.io/`); I spot-checked the live pages against it and they match. Paths below are relative to the repo root. URLs are given where a docs page exists.

## TL;DR

- **Format:** same as core. YAML, `.esdm.yaml` suffix, `---` between documents in one file, and the same top-level shape (`apiVersion`, `kind`, `name`, `description`, `metadata`). Only the `apiVersion` differs: `schema.esdm.io/domain-storytelling/v1` (kind `domain-story`) or `schema.esdm.io/given-when-then/v1` (kind `feature`; `scenario` is nested inside it, not a document of its own).
- **Placement:** anywhere under the model root. The loader collects every `*.esdm.yaml` recursively and dispatches on `apiVersion`, so the directory doesn't matter. The docs only suggest a convention: stories in a sibling directory next to the Bounded Contexts they came from, Features next to the consistency unit they describe.
- **Linking:** both point at core elements through a `scope` block, by kebab-case name.
  - A Domain Story has `scope.domain` and nothing else. Its Actors and Work Objects are free-text names, not links to core Actors.
  - A Feature has a `scope` tied to exactly one consistency unit (Aggregate, DCB, Process Manager or Read Model). Its Scenarios name core Commands, Events, Queries, Timers, Actors and Invariants, and the linter checks all of those names.
- **Linting:** the Domain Storytelling rules (`story-*`) only check that a story is consistent in itself. The Given-When-Then rules (`gwt/*`) check Features against the core model, including invariant coverage.
- **CLI:** `esdm view` and `esdm documentation` include both kinds. Stories appear under their Domain and Features under their consistency unit. `esdm glossary` includes neither, because it only reads the ubiquitous language on Bounded Contexts.

## 1. File format

| | Domain Storytelling | Given-When-Then |
|---|---|---|
| `apiVersion` | `schema.esdm.io/domain-storytelling/v1` | `schema.esdm.io/given-when-then/v1` |
| Kinds | `domain-story` (top-level) | `feature` (top-level); `scenario` is nested in `feature.scenarios[]` |
| Schema file | `schema/domain-storytelling/v1.yaml` | `schema/given-when-then/v1.yaml` |
| Required top-level fields | `apiVersion, kind, name, scope, sentences` (`v1.yaml:266`) | `apiVersion, kind, name, scope, scenarios` (`v1.yaml:514`) |
| Suffix and separator | `.esdm.yaml`, `---` | `.esdm.yaml`, `---` |

What the docs say (https://www.esdm.io/extensions/overview/):
- Each document validates against exactly one schema. Extensions never add kinds to the core, and core documents never validate against an extension schema.
- Extensions are built into the binary. Users can't write their own.
- Each extension is versioned separately from the core.
- The schema URLs are identifiers only. They can't be fetched yet.

`esdm add-schema` / `update-schema` write the core schema and both extension schemas into `schemas/` so editors can use them (`cmd/esdm/commands/addschema/documentation.go`).

### Domain Story anatomy
Source: https://www.esdm.io/extensions/domain-storytelling/reference/domain-story/

- `scope: { domain }` is the only scope. A story isn't tied to a Bounded Context, because a narrative often crosses contexts.
- Three optional classifiers:
  - `pointInTime`: `as-is` or `to-be`
  - `granularity`: `coarse-grained` or `fine-grained`
  - `domainPurity`: `pure` or `digitalized`

  The linter ignores them.
- `groups[]` is optional. Each group has `name`, plus optional `description` and `annotation`.
- `actors[]` is optional. It's only needed when an Actor carries an `annotation` or `groups`; edges can name an Actor inline without declaring it.
- `sentences[]` is required. Each Sentence has:
  - `sequenceNumber`: an integer of 1 or more. Two Sentences with the same number happen in parallel.
  - `edges[]` (required): each edge is `from`/`to` plus optional `label` (the activity), `annotation` and `groups`. A node reference is either `{ actor: <name> }` or `{ workObject: <name> }`.
  - `workObjects[]` (optional): declared per Sentence. The same name in another Sentence is a new instance.
- The singular `annotation` is text shown in the diagram. `metadata.annotations` is for tooling and provenance.

### Feature / Scenario anatomy
Sources: https://www.esdm.io/extensions/given-when-then/reference/feature/ and `.../scenario/`

`scope` is a `oneOf` over four variants. Which unit field is present decides the variant:

| Variant | Scope fields |
|---|---|
| Aggregate | `domain`, `boundedContext`, `aggregate` |
| DCB | `domain`, `boundedContext`, `dynamicConsistencyBoundary` |
| Process Manager | `domain`, `processManager` (Process Managers belong to a domain, so there's no Bounded Context) |
| Read Model | `domain`, `boundedContext`, `readModel` |

Each Scenario has `name`, optional `description`, and `given`, `when`, `then`:

- **Aggregate:**
  - `given`: Events by bare name, each with `{event, data}`.
  - `when`: `{command, data, actor?}`.
  - `then`: either `events[]` (an empty list means the Command is idempotent) or `rejection: { invariant }`.
- **DCB:**
  - `given`: Events with full references (`boundedContext`, `event`, `data`, and `aggregate` when the Event belongs to one).
  - `when` and `then`: same as Aggregate.
- **Process Manager:**
  - `given`: Events with full references.
  - `when`: an Aggregate-owned Event, a free-standing Event, or `{timer}`.
  - `then`: any of `emits`, `setTimers`, `cancelTimers`, `state`, `ended`.
- **Read Model:**
  - `given`: Events with full references.
  - `when`: `{query, parameters}`.
  - `then`: `result` (free-form) or `readModel`.

## 2. Where the documents live

- Discovery doesn't depend on location. `loader` walks the model directory recursively and collects every file ending in `.esdm.yaml` (`loader/documentation.go`, `loader/walk.go:15`). `resolver/resolve.go` then dispatches each document by `apiVersion` into `m.Extensions.DomainStorytelling.Stories` or `m.Extensions.GivenWhenThen.Features`, so extension kinds have their own namespace and can't collide with core kinds (`model/model.go`).
- The docs suggest a layout but don't enforce one:
  - Stories: "typically keeps stories in a sibling directory next to the Bounded Contexts they originated in, but the schema imposes no specific layout" (https://www.esdm.io/extensions/domain-storytelling/reference/overview/).
  - Features: "typically live next to the consistency unit they describe rather than in a separate `tests/` directory" (https://www.esdm.io/extensions/given-when-then/reference/overview/). The introduction says Scenarios live "in the same `.esdm.yaml` files" as the model.
- Model keys:
  - A story's key is `domain/name` (`resolver/resolve.go`, `compositeKey`).
  - A Feature's key is `domain/boundedContext/unit/name` (`model/keys.go`, `FeatureKey`). Two Features can share a name if they're about different units.

## 3. How they reference core elements

**Domain Storytelling: loosely.**
- Only `scope.domain` points at the core model. The resolver checks it like any other scope (`resolver/references.go`: `checkScopes(m, m.Extensions.DomainStorytelling.Stories)`), so an unknown domain gives an unresolved-reference diagnostic.
- Actor and Work Object names are local to the story. Nothing connects them to core `actor` documents or to ubiquitous-language terms.
- The docs describe the direction as one-way: a story "precedes and informs the core ESDM model – Aggregates, Events, and Commands are typically derived from stories later. Stories themselves do not depend on the core: a Domain Story document validates in isolation against this extension's schema" (https://www.esdm.io/extensions/domain-storytelling/introduction/). In practice that means the schema check is isolated, but the domain scope is still resolved.

**Given-When-Then: tightly.**
- `scope` points at one core consistency unit.
- Scenario names resolve through that scope:
  - Event names in `given` and `then.events`: bare names inside the Feature's scope for Aggregates, full references for the other variants.
  - `when.command`, `when.query`, `when.timer` and `when.actor`.
  - `then.rejection.invariant`, which names an invariant declared on the unit.
- The invariant link is the key design idea. "An invariant defines the rule … A Scenario verifies that rule by example" (https://www.esdm.io/extensions/given-when-then/introduction/).

## 4. Linter rules

Both sets run as part of every `esdm lint`, and only fire when the model contains documents of that kind. Rule texts: `documentation/snippets/reference/linter-rules/{domain-storytelling,given-when-then}.md`, generated by `refgen` from `rules/*.go`.

**Domain Storytelling** (https://www.esdm.io/extensions/domain-storytelling/reference/linter-rules/). These only check the story against itself.

| Rule | Severity | Enforces |
|---|---|---|
| `esdm/structure/story-duplicate-actor-name` | error | Each Actor name appears once in `actors` |
| `esdm/structure/story-duplicate-group-name` | error | Each Group name appears once |
| `esdm/structure/story-duplicate-work-object-in-sentence` | error | Each Work Object name appears once per Sentence |
| `esdm/structure/story-unknown-group-membership` | error | Every `groups` membership names a declared Group |
| `esdm/structure/story-sentence-without-edges` | warning | Every Sentence has at least one edge |
| `esdm/structure/story-without-sentences` | warning | Every story has at least one Sentence |
| `esdm/modeling/story-orphan-actor` | warning | Every declared Actor is used by at least one edge |
| `esdm/modeling/story-orphan-work-object` | warning | Every declared Work Object is used by an edge in its Sentence |
| `esdm/modeling/story-orphan-group` | warning | Every Group has at least one member |

**Given-When-Then** (https://www.esdm.io/extensions/given-when-then/reference/linter-rules/). These are all in the `gwt` category and check Features against the core model.

| Rule | Severity | Enforces |
|---|---|---|
| `feature-references-unknown-{aggregate,dynamic-consistency-boundary,process-manager,read-model}` | error | The Feature's scope names a unit that exists |
| `feature-without-scenarios` | warning | The Feature has at least one Scenario |
| `scenario-references-unknown-{command,event,query,timer,actor}` | error | Every name a Scenario uses exists where the scope says it should |
| `scenario-rejection-references-unknown-invariant` | error | `then.rejection.invariant` names an invariant on the unit |
| `scenario-actor-not-permitted` | error | `when.actor` is listed in the Command's `actors` |
| `scenario-when-mismatched-feature-scope` / `scenario-then-mismatched-feature-scope` | warning | `when` and `then` have the shape the Feature's variant expects |
| `scenario-without-when` / `scenario-without-then` | warning | Each Scenario has a `when` and a `then` |
| `uncovered-invariant` | warning | If an Aggregate or DCB has a Feature, every one of its named invariants is exercised by at least one Scenario. Units without a Feature are exempt. |

## 5. CLI support

| Command | Domain Story | Feature |
|---|---|---|
| `esdm lint` | Yes: schema plus `story-*` rules plus the domain scope check | Yes: schema plus `gwt/*` rules |
| `esdm view` | Yes. A node under its **Domain** (`tree/builder.go:92`), tagged with pointInTime, granularity and domainPurity and showing the Sentence count. `--with-details` adds the description only. Sentences and edges aren't drawn. | Yes. A node under its **consistency unit**: Aggregate, DCB, Read Model or Process Manager (`tree/builder.go:287,349,454,631`). Shows the Scenario count. `--with-details` adds the description and Scenario names, but not the given/when/then content. |
| `esdm documentation` (docgen) | Yes. One Markdown page per story, built from the same tree with details on (`docgen/build.go:38`, labels "Domain Story/Stories") | Yes. One page per Feature, labelled "Feature/Features" (`docgen/labels.go`) |
| `esdm glossary` | **No.** It only reads `ubiquitousLanguage` on Bounded Contexts (`cmd/esdm/commands/glossary/documentation.go`) | **No** |
| `esdm add-schema` / `update-schema` | Writes the extension schema to `schemas/` | Same |

No command renders a Domain Story as a diagram, and none exports Scenarios as test fixtures. The docs only say Scenarios "double as … input for tests".

## Implications for esdm-skills (map #1)

These are my inferences, not claims from the sources.

- A skill that writes Domain Stories can work before the core model exists, needing only a valid domain. Its Actor and Work Object vocabulary isn't checked against the ubiquitous language, so if the skill wants story and model terms to stay aligned, it has to do that check itself.
- A skill that writes Features is tightly bound to the core model. It can rely on `esdm lint` to catch dangling references and uncovered invariants, which makes Given-When-Then a natural output format for TDD- or spec-style skills.
- The glossary doesn't include either extension, so `esdm glossary` alone won't show terms that come from stories.

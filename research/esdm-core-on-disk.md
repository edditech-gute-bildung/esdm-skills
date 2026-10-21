# How an ESDM core model lives on disk

Research for issue #2. Researched 2026-10-21 against ESDM **0.15.0** (latest release tag `v0.15.0`) and `thenativeweb/esdm` at commit `947c4d1` (2026-10-05). The esdm.io site is built from `documentation/docs/` in that repo, so docs pages and repo paths below are the same primary source.

Source shorthand:

- **[schema]** `schema/core/v1.yaml` – https://github.com/thenativeweb/esdm/blob/947c4d1/schema/core/v1.yaml
- **[cli]** https://www.esdm.io/reference/cli/ (`documentation/docs/reference/cli.md`)
- **[core-ref]** https://www.esdm.io/reference/core-schema/ (`documentation/docs/reference/core-schema/overview.md`)
- **[refnot]** https://www.esdm.io/reference/reference-notation/
- **[rules]** https://www.esdm.io/reference/linter-rules/ (`documentation/docs/reference/linter-rules.md` + `documentation/snippets/reference/linter-rules/core.md`)
- **[gs-*]** https://www.esdm.io/getting-started/... (`documentation/docs/getting-started/*.md`)
- **[loader]** `loader/walk.go`, **[pipeline]** `runner/pipeline.go`
- **[example]** `documentation/guides/your-first-model/model/*.esdm.yaml`

## TL;DR for later decisions

1. A model is a set of **YAML documents in files ending `.esdm.yaml`**, anywhere under a directory; `esdm lint -d <dir>` walks it recursively. One document per element, `---` allowed for several per file. Element identity is logical (`kind` + `name` + `scope`), never the file path. [core-ref, loader]
2. Every document: `apiVersion: schema.esdm.io/core/v1`, `kind`, `name` (kebab-case `^[a-z][a-z0-9-]*$`), optional `description`, optional `metadata.{labels,annotations}`. **Unknown keys are errors** (`unevaluatedProperties: false`). [schema]
3. **Definitions live only in `bounded-context.ubiquitousLanguage[]`** (`term`, `definition`, optional `avoid[]`, `translations[]`), with `language` (BCP 47) required once that block exists. `esdm glossary` reads exactly that block and nothing else – not `description`, not element names. This is the GLOSSARY.md replacement. [schema, gs-glossary]
4. Recommended layout (not linted): one top-level directory per Bounded Context, grouped inside by consistency unit; cross-BC kinds (policy, process-manager, event-handler, context-mapping) in a sibling `integration/` dir; external systems in one `external-systems.esdm.yaml`. `schemas/` (from `esdm add-schema`) sits at the project root. [schema `x-esdm-project-layout`]
5. External references use `esdm:<kind>=<name>/...` URIs following containment (e.g. `esdm:domain=library/bounded-context=catalog/aggregate=book/event=registered`). [refnot]
6. CLI is a single unsigned Go binary downloaded per OS/arch from `https://esdm.s3.fr-par.scw.cloud/<version>/esdm-<os>-<arch>`; no package manager, no self-update; pin by URL/version. [gs-install]
7. `esdm lint` is silent and exits 0 on a clean model; errors fail, warnings fail only with `--warnings-as-errors`. Rules are not configurable. `--format json` for machines. [cli, rules]

## 1. File format and directory layout

- **Suffix and separator.** Documents are stored as `*.esdm.yaml`; one file may hold several documents separated by `---`. Exposed mechanically as `x-esdm-file-suffix: ".esdm.yaml"` and `x-esdm-document-separator: "---"`. [schema lines 40–45, 66–67; core-ref "File Convention"]
- **Discovery.** `loader.Walk` collects every file under the directory whose name ends in `.esdm.yaml`, recursively, sorted lexicographically. It **skips nothing** – no hidden-directory, `node_modules`, or `.gitignore` handling – and returns `ErrNoFiles` if none are found. [loader/walk.go]
  - Consequence for us: running `esdm lint` from a repo root that contains copies of the model (e.g. `.claude/worktrees/*`) would load duplicates and throw `esdm/structure/duplicate-name`. Point `-d` at the model directory.
- **File placement is meaningless to the model.** "ESDM lets you split a model across as many `.esdm.yaml` files as you like, merge several into one, and move elements between them, all without changing the model itself." [refnot "Why Not Just Point at a File"]
- **Recommended layout** (`x-esdm-project-layout.document-organization`, "not enforced by the linter"): [schema lines 68–108]
  - `primary-axis: bounded-context` – every BC has its own top-level directory. Grouping by kind (`commands/`, `events/`) is explicitly discouraged.
  - `cross-context-bucket: integration` – policies, process-managers, event-handlers and context-mappings live in a sibling `integration/` directory.
  - Inside a BC, group by consistency unit (aggregate / DCB); granularity (one file per unit, split by kind, or a directory per unit) is up to the modeler.
  - External systems: typically one `external-systems.esdm.yaml` at the domain root.
  - Getting-started guides use a flat one-artifact-per-file layout for a single BC. [gs-first-model]
- **Schemas directory.** `esdm add-schema` writes the embedded schemas to `schemas/<name>/<version>.yaml` (`schemas/core/v1.yaml`, `schemas/given-when-then/v1.yaml`, `schemas/domain-storytelling/v1.yaml`); model files live alongside. Docs say commit it. [cli add-schema; gs-editor; schema `schemas-directory`, `schema-path-template`]
- **Editor modeline** (optional): `# yaml-language-server: $schema=./schemas/core/v1.yaml` as the first line, path relative to the file; one per document in multi-doc files. [gs-editor]

Minimal example (from the official first-model guide): [example]

```yaml
apiVersion: schema.esdm.io/core/v1
kind: aggregate
name: book
scope:
  domain: library
  boundedContext: cataloging
identifiedBy:
  source: state
  field: isbn
state:
  type: object
  properties:
    title: { type: string }
    isbn: { type: string }
  required: [title, isbn]
```

## 2. Common shape and schema identity

- Required on every document: `apiVersion`, `kind`, `name`. Optional: `description` (free string), `metadata` with `labels` (string map, for selection) and `annotations` (string map, tooling hints such as `cloudevents.type`). `metadata` is "non-semantic; nothing in the rest of the schema reads them". [schema lines 426–478]
- `name` pattern `^[a-z][a-z0-9-]*$` (lowercase kebab-case). Property-name references (`field`, `at`) are any non-empty string. [schema `$defs.name`, `$defs.propertyName`]
- `apiVersion` is `$id` without `https://`: core is `schema.esdm.io/core/v1`; extensions are `schema.esdm.io/given-when-then/v1` and `schema.esdm.io/domain-storytelling/v1`. Validation dispatches on `apiVersion`; the core `kind` enum is closed. [schema header; extension schemas]
- `x-esdm-schema-revision: "1.0.0"` (SemVer) moves with non-breaking schema edits while `$id` stays stable. The `schema.esdm.io` URL is currently an identifier, not fetchable. [schema line 64; core-ref "Schema Identity"]
- Prose fields (`rule`, `criteria`, `condition`) carry behavior that does not fit a grammar – invariants, constraints, projection rules, side effects. [schema top-level `description`]
- Most arrays use natural keys (`name`, `term`, reference triple); uniqueness within arrays and cross-field references are "modeling rules the schema does not enforce" – some are enforced by linter rules (section 7). [schema top-level `description`]

## 3. Schema per kind

`R` = required, `o` = optional. "Bare" = a plain name resolved within the document's own scope. All fields are under the document root next to the common fields. [schema `allOf` branches, lines 480–1889]

### Scope shapes

| Shape | Fields | Used by |
|---|---|---|
| none | – | domain, context-mapping |
| `scopeDomain` | `domain` | subdomain, bounded-context, event-handler, policy, process-manager, external-system |
| `scopeBoundedContext` | `domain`, `boundedContext` | aggregate, dynamic-consistency-boundary, read-model, query, entity, value-object, domain-service, actor; event (free-standing variant) |
| `scopeAggregate` | `domain`, `boundedContext`, `aggregate` | command, event (aggregate-owned) |
| `scopeDynamicConsistencyBoundary` | `domain`, `boundedContext`, `dynamicConsistencyBoundary` | command (DCB-bound) |

Domain membership is assembled entirely from children's `scope` fields; there are no child lists on parents. [schema lines 486–493; core-ref "Scope"]

### Reference shapes used inside documents

- **eventReference**: `{boundedContext, aggregate, event}` (aggregate-owned) or `{boundedContext, event}` (free-standing). Used by `handles`, `startsWhen`, `reactions[].when`, `projections`, `consults`. No `domain` – the consumer's scope fixes it.
- **commandReference**: `{boundedContext, aggregate, command}` or `{boundedContext, dynamicConsistencyBoundary, command}`. Used by `policy.emits`, `reactions[].emits`.
- **Bare names**: `command.publishes`, `command.actors`, `query.readModel`, `query.actors`, `subdomain.boundedContexts`, `actor.backedBy`, `sideEffects[].externalSystem`.
- **mappingEndpoint**: `scopeBoundedContext` or `{domain, externalSystem}`.
[schema `$defs` lines 237–424]

### Kinds

| Kind | Scope | Required fields | Optional fields |
|---|---|---|---|
| **domain** | – | (common only) | – |
| **subdomain** | domain | `scope`, `type` (`core`\|`supporting`\|`generic`), `boundedContexts[]` (bare, ≥1) | – |
| **bounded-context** | domain | `scope` | `language` (BCP 47; R if `ubiquitousLanguage` present), `ubiquitousLanguage[]` (≥1): `{term R, definition R, avoid[] {term R, reason o}, translations[] {language R, term R, definition R, avoid[]}}` |
| **aggregate** | BC | `scope`, `identifiedBy` (`{source: state, field}` \| `{source: static, value}` \| `{source: generated, generator}`), `state` (JSON Schema object) | `invariants[]` (namedRule `{name, rule}`) |
| **dynamic-consistency-boundary** | BC | `scope`, `identifiedBy[]` (≥1; each `{name, source: command-payload, field}` \| `{name, source: static, value}` \| `{name, source: generated, generator}`), `consults[]` (≥1; eventReference + `criteria`) | `invariants[]` |
| **command** | aggregate or DCB | `scope`, `data` (JSON Schema; `{}` for none), `publishes[]` (bare event names, ≥1) | `actors[]` (bare, ≥1), `constraints[]` (namedRule) |
| **event** | aggregate or BC (free-standing) | `scope`, `data` (JSON Schema) | – (versioning = new event name) |
| **event-handler** | domain | `scope`, `deliveryGuarantee` (`at-least-once`\|`at-most-once`), `handles[]` (eventReference), `sideEffects[]` (`{type: external-call, externalSystem, rule}` \| `{type: other, rule}`); `idempotency` R if at-least-once | `constraints[]` |
| **policy** | domain | `scope`, `deliveryGuarantee`, `handles[]`, `emits[]` (commandReference); `idempotency` R if at-least-once | `constraints[]` |
| **process-manager** | domain | `scope`, `deliveryGuarantee`, `correlatedBy` (`{source: event-field, field}`), `state`, `startsWhen[]` (eventReference), `endsWhen[]` (`{name, condition}`), `reactions[]` (`{when: eventReference \| {timer}, rule, emits[]?, setTimers[]?, cancelTimers[]?}`); `idempotency` R if at-least-once | `invariants[]`, `constraints[]`, `timers[]` (`{name, description?, after: {value, unit}}` or `{name, at: <state field>}`) |
| **read-model** | BC | `scope`, `projections[]` (eventReference + `rule`), `schema` (shape of the whole materialized view) | `paradigm` (tabular, document, graph, stream, key-value, search-index, time-series, column, vector) |
| **query** | BC | `scope`, `readModel` (bare), `result` (JSON Schema) | `paradigm`, `parameters` (object), `actors[]`, `constraints[]` |
| **entity** | BC | `scope`, `schema`, `identifiedBy` (`{source: schema, field}` \| `{source: static, value}`) | `invariants[]` |
| **value-object** | BC | `scope`, `schema` | `invariants[]` |
| **domain-service** | BC | `scope`, `functions[]` (≥1; `{name R, arguments R, returns R, description o, rules[] o}`) | – |
| **actor** | BC | `scope`, `type` (`human`\|`system`) | `responsibilities[]` (strings), `backedBy[]` (bare external-system names; forbidden on `human`) |
| **external-system** | domain | `scope`, `direction` (`inbound`\|`outbound`\|`bidirectional`) | `category` (free string), `capabilities[]` (strings) |
| **context-mapping** | – | `type` + role endpoints: `customer-supplier` (`customer`, `supplier`), `conformist` (`conformist`, `upstream`), `anti-corruption-layer` (`downstream`, `upstream`), `open-host-service` (`host`, `consumer`), `published-language` (`publisher`, `consumer`); symmetric `shared-kernel` / `partnership` / `separate-ways` use `participants` (exactly 2 BCs) | asymmetric types: `terms[]` pairing the two sides' canonical terms, e.g. `{customer: Customer, supplier: Account}` |

`idempotency` = `{owner: self|downstream|infrastructure|none|not-required, strategy?}`. [schema lines 356–391]

Not in the core: `feature` (given-when-then) and `domain-story` (domain-storytelling) are extension kinds with their own `apiVersion`. [schema header; refnot]

## 4. Where definitions and descriptions live

- **Term definitions**: only in `bounded-context.ubiquitousLanguage`. One canonical term per language, no aliases; rejected synonyms go in `avoid` with optional `reason`; other languages go in `translations`. [schema lines 566–628; concepts/bounded-context.md "The Ubiquitous Language"]
- **`esdm glossary` reads exactly that block and nothing else**; "it does not invent definitions from artifact names". Bounded Contexts without the block contribute nothing; a model with none prints only `# Glossary`, exit 0. [gs-glossary "What the Glossary Reads"; cli]
- **Element prose**: the optional top-level `description` on any document. It appears in `esdm documentation` pages, not in the glossary. [cli documentation; gs-documentation "Reading a Page"]
- **Cross-context term equivalence**: `context-mapping.terms` on asymmetric mappings; values must be canonical terms of each endpoint's ubiquitous language (resolver-checked; BC endpoints only). [schema lines 673–699]
- Other prose: `actor.responsibilities`, `external-system.capabilities`, `timers[].description`, `functions[].description`, and the `rule`/`criteria`/`condition` fields.

## 5. Reference notation

- Form: `esdm:<kind>=<name>/<kind>=<name>/...`, walking containment from the Domain inward; `kind` is the `kind` value, `name` is used verbatim. Scheme is `esdm:` (a name, not a location – no `//`). [refnot]
- Placement: Domain → `esdm:domain=X`; domain-scoped kinds (subdomain, bounded-context, policy, event-handler, process-manager, external-system) → `esdm:domain=X/<kind>=Y`; BC-scoped kinds (aggregate, DCB, free-standing event, read-model, query, entity, value-object, domain-service, actor) → `.../bounded-context=B/<kind>=Y`; commands and aggregate-owned events → `.../aggregate=A/command=C` or `.../dynamic-consistency-boundary=D/command=C`; context-mapping → `esdm:context-mapping=Z` (no domain). [refnot "What You Can Point At"]
- A reference is "that document head, serialized": derive it from `scope` + `kind` + `name` without any lookup. [refnot]
- References stop at elements – not into schema fields, invariants, or individual ubiquitous-language terms. So a glossary *term* has no `esdm:` reference; its Bounded Context does. [refnot]
- Stable across file moves, not across renames (a rename is a refactoring that must update references, including those in specs and tickets). [refnot "References and Renames"]
- `esdm documentation` maps a reference to a page path by replacing `=` with `_`: containers become `.../README.md`, leaves `.../<kind>_<name>.md`. [refnot; cli]

## 6. CLI: install, versioning, commands

**Install.** Pre-built binaries only (macOS/Linux/Windows × arm64/amd64), from `https://esdm.s3.fr-par.scw.cloud/<version>/esdm-<os>-<arch>[.exe]`, with SHA256s on the install page. Rename to `esdm`, `chmod a+x`, on macOS `xattr -d com.apple.quarantine esdm`. Binaries are **unsigned**. Docs put the binary "in your project" and call it as `./esdm`. CI example: `curl -sSL -o esdm https://esdm.s3.fr-par.scw.cloud/0.15.0/esdm-linux-amd64`. Building from source: `make build`. [gs-install; gs-lint "Linting in CI"; README]

**Versioning.** `esdm version` prints a SemVer and the git commit. No self-updater; on interactive runs it checks `https://www.esdm.io/version.json` once a day and prints a hint (suppressed when not a TTY, when `CI` is set, or with `ESDM_DISABLE_UPDATE_CHECK=true`). Upgrading = downloading a new binary. Pre-1.0 (current 0.15.0). The schema itself is versioned separately via `x-esdm-schema-revision`. [cli version; gs-updating]

**Commands** (six plus `--help`): [cli]

| Command | Produces |
|---|---|
| `esdm lint [-d dir] [--format human\|json] [--color auto\|always\|never] [--warnings-as-errors]` | Nothing on success (exit 0). Otherwise findings: severity, rule ID `esdm/<category>/<name>`, `file:line:col`, message, `see <docs URL>`. JSON: array of objects with the same fields plus `documentationUrl`. Non-zero exit iff any error (or any warning with `--warnings-as-errors`). |
| `esdm view [path] [-d dir] [--with-details] [--color]` | Terminal tree `domain → bounded-context → aggregate/DCB/read-model/query → command/event`, with counts and `→`/`←` relations; `path` is `domain/bc/unit` by name. `--with-details` adds identifiedBy, payload fields, projection rules, etc. |
| `esdm glossary [path] [-d dir] [--language <bcp47>]` | Markdown on stdout: `# Glossary`, `## <bc>` per BC (sorted), `### <term>` per term (sorted), definition, `_Avoid the term "X"._ reason`. With `--language`, renders translations, marking gaps `_No translation into de._`. `path` is `domain` or `domain/bc`. Intended use: `esdm glossary > glossary.md`. |
| `esdm documentation [path] -o <dir> [-d dir] [--force]` | Directory of Markdown pages, one per element, named `kind_name` per reference segment; root `README.md` lists Domains and Context Mappings. Each page: name, kind + `esdm:` reference, stats, description, details, linked children/relations; BC pages include the ubiquitous language with translations. Refuses a non-empty output dir without `--force` (which wipes it). Lint findings do not block. |
| `esdm add-schema` | Writes `schemas/` in the CWD; refuses if it exists. |
| `esdm update-schema` | Refreshes `schemas/` when the binary's schema revision is newer; refuses downgrades. |
| `esdm version` | Version + commit. |

`view`, `glossary` and `documentation` require only that the model **resolves**; lint warnings/errors from rules do not block them. [cli]

## 7. Linter rules an agent must respect when writing files

Lint runs in two stages: parse + schema-validate + resolve, then (only if that stage has no errors) the rule catalog. No rule can be disabled or re-severitied; there is no project config file. [rules; repo `.claude/rules/esdm.md` "Architectural Negatives"]

**Pipeline errors (block everything):** [rules "Pipeline Diagnostics"]

- `structure/yaml-syntax-error`, `structure/unknown-api-version`
- `structure/missing-required-field`, `structure/unknown-field` (typos and misplaced fields are errors), `structure/type-mismatch`, `structure/constraint-violation` (enum values, kebab-case names, `minItems`, forbidden combos)
- `structure/duplicate-name` – same kind + same name in the same scope
- `structure/unresolved-reference` – every scope segment, bare name and reference triple must point at a declared element
- `system/schemas-directory-drift` – if `schemas/` exists in the lint directory and differs from the binary's embedded schemas, lint stops before reading models. Fix with `esdm update-schema` (or upgrade the binary). [runner/pipeline.go]

**Rule errors:** [rules core]

- `structure/ambiguous-name` – within a BC, aggregates, DCBs, entities, value-objects and domain-services share **one namespace**. Other kinds may reuse a name (aggregate `order` + read-model `order` is fine).
- `structure/aggregate-identified-by-field`, `entity-identified-by-field`, `dynamic-consistency-boundary-identified-by-field`, `process-manager-correlated-by-field`, `process-manager-timer-at-field` – the named `field`/`at` must exist in the referenced schema (`state`, `schema`, command `data`, event payloads, PM `state`).
- `structure/duplicate-translation-language` – one translation per language per term.
- `structure/translation-into-own-language` – no translation into the BC's own `language`.

**Warnings that matter for a clean model** (all 39 modeling rules are warnings; full list on [rules]). The ones agents most often hit:

- `event-name-with-aggregate-prefix` – name events `acquired`, not `book-acquired`, on aggregate `book`. Same convention for commands in examples (`acquire`).
- `event-without-consumer`, `event-without-publisher`, `read-model-without-query`, `orphan-actor`, `orphan-external-system`, `orphan-context-mapping` – every element must be wired into something.
- `cross-bounded-context-reference-without-mapping` – any consumer touching two BCs needs a context-mapping between each pair.
- `bounded-context-without-content` – a BC needs at least one aggregate, DCB or read-model.
- `domain-without-bounded-context`, `subdomain-without-bounded-context`, `aggregate-without-commands`/`-events`.
- `consumer-at-least-once-without-idempotency`, `human-actor-with-backed-by` (also schema-enforced).

The docs recommend `--warnings-as-errors` in CI. [gs-lint]

## Open points / not verified

- Behavior of `esdm lint` on zero `.esdm.yaml` files: `loader.Walk` returns `ErrNoFiles` and `Run` documents an error return for an empty directory; the exact CLI message/exit code was not run.
- No CLI was executed; all behavior above is from docs and source at the stated commit.
- The extension kinds (`feature`, `domain-story`) and their rules were not researched beyond their existence.

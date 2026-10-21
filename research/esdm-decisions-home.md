# Does ESDM have a home for decisions and rationale?

Research for [#5](https://github.com/edditech-gute-bildung/esdm-skills/issues/5) (map: [#1](https://github.com/edditech-gute-bildung/esdm-skills/issues/1)).

Sources: `thenativeweb/esdm` at commit [`947c4d1`](https://github.com/thenativeweb/esdm/tree/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f) (2026-10-05). The `documentation/` tree in that repo is the source of https://www.esdm.io (`site_url` in `documentation/mkdocs.yml`). I spot-checked the live site against it and they match. Links below are permalinks to that commit. `S` = `schema/core/v1.yaml`.

## Answer

**The assumption holds. ADRs stay in `docs/adr/`.** No ESDM kind, core or extension, records design decisions, alternatives or trade-offs. ESDM can't be given one either, because users can't add extensions. What ESDM does have is a few free-form slots on every document, and an ADR can be cross-referenced from them. The best fit is `metadata.annotations`.

## Findings

### 1. The core has no decision kind

The core `kind` enum is closed and has 18 values: domain, subdomain, bounded-context, context-mapping, aggregate, dynamic-consistency-boundary, command, event, event-handler, policy, process-manager, read-model, query, entity, value-object, domain-service, actor and external-system. None of them is a decision, ADR, rationale or trade-off record. ([S L430-449](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/schema/core/v1.yaml#L430-L449))

Every document must match its schema exactly: `unevaluatedProperties: false` rejects unknown top-level keys. That means you can't add a `decisions:` field. ([S L477-478](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/schema/core/v1.yaml#L477-L478); [core-schema overview, "Common Fields"](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/documentation/docs/reference/core-schema/overview.md))

The only fields that look like rationale are about other things:

- **Business rules**, such as `invariants`, `constraints`, `rules`, `endsWhen` and `criteria`. These hold prose that the implementation has to enforce, not reasons for a design choice. ([S L159-188](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/schema/core/v1.yaml#L159-L188))
- **Rejected terms.** `ubiquitousLanguage[].avoid[]` has `{term, reason?}`. It records vocabulary that was considered and rejected, which makes it a terminology decision log. It does not cover architecture. ([S L138-157](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/schema/core/v1.yaml#L138-L157), [S L566-621](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/schema/core/v1.yaml#L566-L621))

### 2. The extensions have no decision kind, and users can't add one

ESDM ships exactly two extensions. Domain Storytelling covers discovery stories, and Given-When-Then covers behavioural scenarios. Neither records decisions. The docs say: "They are not user-extensible: writing a new extension requires changes to the binary itself." ([extensions/overview.md](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/documentation/docs/extensions/overview.md))

The schema header does mention third-party extensions with their own authority, such as `acme.corp/esdm/my-ext/v1`. ([S L29-31](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/schema/core/v1.yaml#L29-L31)) The linter doesn't support them, though. It validates only against the schemas built into the binary, and it reports any other `apiVersion` as an error: `unknown apiVersion "…"; expected one of: …`. ([parser/parse.go L68-73, L95-115](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/parser/parse.go#L68-L115)) A home-made "decision" extension would therefore fail `esdm lint`.

The docs never mention ADRs or architecture decisions. A grep of `documentation/docs` and `schema/` for `ADR`, `decision record` and `architecture decision` finds nothing.

### 3. Free-form slots where a model element can point to an ADR

Every core and extension document has these common fields:

| Field | Shape | Read by tooling? | Fit for an ADR link |
|---|---|---|---|
| `description` | string, free prose | Yes. `esdm docgen` renders it ([render.go L71-73](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/cmd/esdm/commands/docgen/render.go#L71-L73)) and `esdm view` shows it | Readable: a prose sentence such as "See ADR-0003" shows up in generated docs |
| `metadata.annotations` | `map<string,string>`, "free-form key/value data for tooling, integration, and provenance" | No. "Non-semantic attachments; nothing in the rest of the schema reads them. A deliberate escape hatch" | Best structured fit, e.g. `annotations: { adr: docs/adr/0003-….md }` |
| `metadata.labels` | `map<string,string>`, tag-like identifiers for selection | No | Not suitable. Labels are meant for grouping, not for links |

Sources: [S L451-476](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/schema/core/v1.yaml#L451-L476). The extensions use the same `metadata` shape: [given-when-then L448-462](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/schema/given-when-then/v1.yaml#L448-L462) and [domain-storytelling L118-132](https://github.com/thenativeweb/esdm/blob/947c4d13437b6dc8ce1f638b0b34e8a11cfff92f/schema/domain-storytelling/v1.yaml#L118-L132).

Two limits to keep in mind:

- Nested entries such as Scenarios, ubiquitous-language terms and invariants have no `metadata` of their own. Only top-level documents do. If an ADR concerns one invariant, the link has to go on the enclosing document.
- ESDM doesn't check annotation values, so a broken ADR path would go unnoticed. Our skills would have to check these links themselves if we want that.

YAML `#` comments are also allowed in `*.esdm.yaml` files, but no tool reads them.

## Implications for the fork

- Keep ADRs in `docs/adr/`. ESDM has nothing to replace them, and it can't be extended to add something.
- Choose one convention for linking from a model document to an ADR. The recommendation is a `metadata.annotations` key such as `adr` (comma-separated if there are several), and optionally a mention in `description` so the link also appears in generated docs.
- Terminology decisions belong in `ubiquitousLanguage[].avoid[].reason`, not in an ADR. This is the one decision-like field ESDM has, and the GLOSSARY-replacement work should use it.

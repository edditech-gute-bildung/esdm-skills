# What does ESDM already ship for AI agents?

Research for [#4](https://github.com/edditech-gute-bildung/esdm-skills/issues/4), part of the map [#1](https://github.com/edditech-gute-bildung/esdm-skills/issues/1).

Sources: the ESDM repository [thenativeweb/esdm](https://github.com/thenativeweb/esdm) at commit `947c4d1` (2026-10-05), latest release **v0.15.0** (2026-09-17), and the docs site [esdm.io](https://www.esdm.io), which is built from `documentation/docs/` in that repository. Paths below are relative to that repository.

## Short answer

ESDM ships **no agent skills, no MCP server, no ESDM-specific language server, and no agent rules file for end users**. What it ships for agents is:

1. **One tool-agnostic starter prompt** (role, "read the schemas", interview one question at a time, lint loop).
2. **Self-describing schemas** materialized into the project by `esdm add-schema`, carrying vocabulary, file conventions and a machine-readable project layout explicitly aimed at "AI tooling such as Claude Code".
3. **A CLI that is agent-friendly by construction**: `lint --format json` with rule IDs and documentation URLs, exit codes that mean "model correct or not", and Markdown output from `glossary` and `documentation`.
4. **Editor support via the generic YAML language server** (modeline convention only).

Everything above the "draft a model, then lint" loop – how a modeling session runs, when to edit the model, how other workflows consume it – is unoccupied. That is the space the fork fills.

## What exists, in detail

### "Your First Model with AI" – the starter prompt

`documentation/docs/getting-started/your-first-model-with-ai.md` ([live](https://www.esdm.io/getting-started/your-first-model-with-ai/)):

- Workflow: `esdm add-schema` → open any coding agent in the directory (names Claude Code, Codex, GitHub Copilot) → paste starter prompt → `esdm lint` → paste findings back to the agent → `esdm view` to inspect.
- Rationale stated by the docs: the schemas "carry the vocabulary, the file conventions, and a project-layout description the agent should follow. Pointing the agent at those files is enough; you don't have to teach it ESDM in the prompt." And: "`esdm lint` then closes the loop."
- The starter prompt has four parts the docs name explicitly: **role** (DDD + Event Sourcing expert), **schema instruction** (read the schemas before writing anything), **interview style** ("Ask one question at a time and phrase the questions in the vocabulary from the schemas"), **lint loop** (after writing, ask the user to run `esdm lint`).
- It is deliberately tool-agnostic and depends on no agent-specific feature.
- Scope: a first, small, greenfield model (one Domain, one Bounded Context, one Aggregate …). It does not cover evolving an existing model, multi-context work, or the extensions.

### Schemas as the agent's reference

`schema/core/v1.yaml` (plus `schema/domain-storytelling/v1.yaml`, `schema/given-when-then/v1.yaml`):

- Header comments document the extension model, file suffix, multi-document files, and the project layout. The layout is exposed "mechanically so generators (including AI tooling such as Claude Code) materialize the expected layout without guessing".
- Machine-readable fields: `x-esdm-schema-revision`, `x-esdm-file-suffix` (`.esdm.yaml`), `x-esdm-document-separator` (`---`), `x-esdm-project-layout`.
- `x-esdm-project-layout.document-organization`: primary axis **bounded-context** (one top-level directory per BC); cross-BC artifacts (policies, process managers, event handlers, context mappings) in a sibling **`integration/`** directory; within a BC, group by consistency unit; external systems in one `external-systems.esdm.yaml` at the domain root. "Tools that materialize ESDM models default to this layout"; not enforced by the linter.
- The long `description` strings and per-definition comments act as the ESDM vocabulary an agent reads.

`esdm add-schema` writes them to `schemas/<name>/v1.yaml` and refuses if `schemas/` exists; `esdm update-schema` refreshes and rejects downgrades (`documentation/docs/reference/cli.md`).

### CLI surface usable by agents

From `documentation/docs/reference/cli.md` ([live](https://www.esdm.io/reference/cli/)): six subcommands.

| Command | Agent relevance |
| --- | --- |
| `esdm lint [-d dir] [--format human\|json] [--warnings-as-errors]` | JSON array of findings with `ruleId` (`esdm/<category>/<name>`) and `documentationUrl`; exit code non-zero iff an error finding (or any warning with `--warnings-as-errors`). The verification step for every model edit. |
| `esdm glossary [domain[/bc]] [--language tag]` | Markdown glossary from `ubiquitousLanguage` blocks, with *Avoid* notes for discouraged terms; path scoping per Domain / Bounded Context. Direct replacement for a hand-written `GLOSSARY.md`. |
| `esdm view [path] [--with-details]` | Hierarchical tree of the model; path scoping down to a consistency unit. Cheap way for an agent to orient in a model. |
| `esdm documentation --output dir [path] [--force]` | One Markdown page per element, with relationships written out as links. Useful as a readable context dump. |
| `esdm add-schema` / `update-schema` | Setup and upgrade of the local schemas. |
| `esdm version` | SemVer + commit; usable for a version check in a setup skill. |

Further agent-relevant facts:

- The once-a-day update check stays quiet in non-interactive runs and when `CI` is set (`documentation/docs/getting-started/updating-esdm.md`), so agent tool calls get clean output.
- **Reference notation** (`documentation/docs/reference/reference-notation.md`): `esdm:<kind>=<name>/…` URIs for pointing at model elements from *outside* the model – explicitly meant for specs, tickets and architecture notes. This is the existing mechanism for ADRs, specs and tickets to cite model elements.
- Deliberate product negatives (`.claude/rules/esdm.md`): no project-level config file, no rule toggling or severity overrides. Skills must not assume or invent such configuration.

### Editor / LSP support

`documentation/docs/getting-started/editor-support.md`: no ESDM language server. Support is the **generic YAML language server** fed by a per-document modeline `# yaml-language-server: $schema=./schemas/core/v1.yaml` (path relative to the file). Editor-specific setup is declared out of scope.

### Ecosystem, Recipes, Modeling Guides

- **Ecosystem** (`documentation/docs/ecosystem.md`): one entry, the **ESDM Visualizer** by Impierce (Apache-2.0, Docker, reads core + both extensions, verified with 0.15.0). A human-facing board, not an agent tool.
- **Recipes** (`documentation/docs/recipes/overview.md`): empty; "added over time".
- **Modeling Guides** (`documentation/docs/modeling-guides/overview.md`): "The first Modeling Guide is in preparation." (`documentation/guides/your-first-model/` holds a lint-gated example domain.)

### What does not exist

- No MCP server, agent skills, or agent plugin in `thenativeweb/esdm` or elsewhere in the `thenativeweb` org (`gh repo list thenativeweb`; `gh search repos esdm`).
- The repository's own `CLAUDE.md` and `.claude/rules/*.md` are **contributor rules for developing the ESDM CLI**, not guidance for modeling with ESDM.

## Reuse vs. build for the fork

**Reuse / defer to (do not duplicate):**

- **The schemas as the vocabulary source.** Skills point the agent at `schemas/` instead of restating ESDM concepts. Teaching ESDM inside skill text would drift from the schema revision.
- **`x-esdm-project-layout`** for where `domain-modeling` writes files (BC directories, `integration/`, `external-systems.esdm.yaml`). Read it from the schema, don't hard-code a competing layout.
- **`esdm lint --format json`** as the verification step after every model write; link findings via `documentationUrl` instead of explaining rules.
- **`esdm glossary`** for the generated glossary (already settled in #1); `esdm view` / `esdm documentation` for orienting consumer skills in the model.
- **Reference notation** for citing model elements from ADRs, specs and tickets (relevant to the "ADR ↔ ESDM interplay" open item in #1).
- **`esdm add-schema` / `update-schema` / `version`** as the backbone of the ESDM setup skill; the modeline convention for files the skill creates.
- **The starter prompt's four moves** (role, read schemas, interview one question at a time in schema vocabulary, lint loop). They line up with `grilling` + `domain-modeling`, so the forked `domain-modeling` can adopt them and link the page rather than reinvent them.

**Build (nothing upstream covers it):**

- An **ongoing** modeling workflow: editing an existing model inline during a session, not only drafting a first model from scratch.
- Rules for **when to change the model vs. write an ADR**.
- How skills **locate the relevant Bounded Context** in a multi-context model (layout + `esdm view` path scoping are the raw material).
- Use of the **Domain Storytelling** and **Given-When-Then** extensions in agent workflows (discovery, and the bridge to `tdd`); ESDM's AI guide doesn't touch them.
- The **ESDM setup skill** (`docs/agents/domain.md` shape, binary presence/version check, `add-schema`, model scaffolding).
- How downstream skills (`to-spec`, `to-tickets`, `triage`, `tdd`, …) **read** the model.

**Don't build:** an MCP server or LSP – the CLI's JSON lint output, Markdown generators and the YAML LSP already cover the need, and the CLI is what ESDM maintains. Watch the empty Recipes and Modeling Guides chapters: once they land, link them from the skills instead of writing parallel guidance.

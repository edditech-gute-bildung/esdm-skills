---
name: to-spec
description: "Turn the current conversation into a spec and publish it to the project issue tracker: no interview, just synthesis of what you've already discussed."
disable-model-invocation: true
---

This skill takes the current conversation context and codebase understanding and produces a spec. Do NOT interview the user; just synthesize what you already know.

The issue tracker and triage label vocabulary should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching.

2. Sketch out the seams at which you're going to test the feature. Existing seams should be preferred to new ones. Use the highest seam possible. If new seams are needed, propose them at the highest point you can. The fewer seams across the codebase, the better - the ideal number is one.

For a unit that has a Given-When-Then Feature, the Feature's scope is the seam. `esdm` (the command named in `docs/agents/domain.md`) lists each unit's Features and their Scenarios: `esdm view -d <model dir> --with-details`. The scope names the unit, and its variant fixes where the tests sit: command handling for an Aggregate or DCB, the reaction for a Process Manager, projecting the Events and then the Query for a Read Model. These seams are already agreed in the model. The paragraph above holds for units without a Feature, and only their seams need the check below.

Check with the user that these seams match their expectations.

3. Write the spec using the template below, then publish it to the project issue tracker. Apply the `ready-for-agent` triage label - no need for additional triage.

<spec-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts, not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)
- The Features and Scenarios the work must satisfy, as its acceptance criteria. Cite each Scenario by the Feature's `esdm:` reference, then its name after `scenario=` (references stop at the Feature), the way `tdd` comments its tests.

The model holds each Scenario's `given`, `when`, `then` and `data`; the reference points there, so never copy them into the spec. If the work needs behaviour no Scenario covers, name the missing Scenario as a gap for `/domain-modeling` to write.

<citation-example>
- `esdm:domain=library/bounded-context=lending/aggregate=copy/feature=borrowing-a-copy scenario=returned-copy-becomes-borrowable-again`
</citation-example>

## Out of Scope

A description of the things that are out of scope for this spec.

## Further Notes

Any further notes about the feature.

</spec-template>

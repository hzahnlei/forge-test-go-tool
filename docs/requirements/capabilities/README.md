# Capabilities

One _Capability Specification_ per capability, named `CAP-NNN_name.md` and numbered in the order
the capabilities are written. The name matches `CAP-[0-9]{3,4}_[a-zA-Z0-9._-]+\.md`: ASCII
letters, digits, and dots, `_` in place of a space, and `-` inside a compound word such as
`check-in`. It describes the current target state of its capability, not a change:
if a later capability contradicts an earlier one, correct the earlier specification.

This file is written by `repo update`; keep notes in another file.

## Workflow

1. Write the specification from the template below, with or without an assistant.
2. Review it and set its status to `Accepted`.
3. Derive Gherkin scenarios from the acceptance criteria, changes to interface descriptions, new
   glossary terms, and an ADR only for a decision that reaches beyond the capability and is hard
   to reverse. The scenarios of `CAP-NNN_name.md` go into
   `docs/verification/acceptance/CAP-NNN_name.feature`.
4. Implement test-first. `make test`, `make bdd-test`, and `make lint` verify the result.

## Template

Every section is present, in this order; a section without content says `None.`

```markdown
# CAP-NNN: Name

**Status**: Draft

## Context

Why the capability exists; builds on the mission statement.

## References

Interfaces and documents the capability relies on.

## Details

Content that fits the capability better than prose, e.g. tables that relate input to output.

## Functional Requirements

1. Numbered.

## Non-Functional Requirements

1. Numbered, each measurable.

## Technical Requirements

1. Numbered; constraints on the solution space, e.g. target hardware or interrupt context.

## Error Handling

1. Numbered.

## Out of Scope

- What the capability deliberately does not do.

## Acceptance Criteria

1. Numbered; with test vectors where values matter; each verified automatically unless it
   refers to a manual test.

## Decisions

1. **The decision.** Its reason.
   Consequence: what follows from it.
```

## Guidance

- Status is `Draft` or `Accepted`.
- Phrase a negative acceptance criterion by the capability's own output ("no _Motor Status_"),
  not by everything ("no CAN message"); otherwise a later capability refutes it.
- An acceptance criterion that no automated test can check refers to the manual test that
  verifies it.
- Refer to an earlier capability instead of repeating it ("as for CAP-003").
- Links point to earlier capabilities only.
- Design documents that serve several capabilities live in `docs/design/`; link them under
  References.

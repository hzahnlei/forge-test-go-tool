# Architecture Decision Records

An ADR records a decision that reaches beyond a single capability and is hard to reverse. A
decision that concerns one capability belongs in that _Capability Specification_'s Decisions
section instead.

Name each ADR `ADR-NNN_short_title.md`, numbered in order, with four digits from ADR-1000 on.
The title uses ASCII letters, digits, and dots, `_` in place of a space, and `-` inside a compound
word such as `check-in`. An ADR is frozen once a release tag contains it; a later decision
supersedes it with a new ADR instead of changing it.

This file is written by `repo update`; keep notes in another file.

## Template

```markdown
# ADR-NNN: Title

**Status**: Proposed | Accepted | Superseded by ADR-NNN
**Date**: YYYY-MM-DD

## Context

The forces at play and the requirement that makes a decision necessary.

## Decision

The decision, in one or two sentences.

## Alternatives

Each considered alternative with the reason it was not chosen.

## Consequences

What becomes easier and what becomes harder.
```

---
description: Break a product or technical request into dependency-ordered task cards. No implementation.
argument-hint: "[requirement, doc paths, extra constraints]"
---

Use the `architect` agent to turn `$ARGUMENTS` into task cards. Do not write application code.

This command is a convenience, not the only way to make cards — any card that follows the "Task lifecycle" section of `CLAUDE.md` can be executed.

## Input

Read `$ARGUMENTS`, `CLAUDE.md`, and the code the request touches. Do not invent requirements that can't be traced to the request or the code; write open product decisions down explicitly.

## Rules

1. Follow the frontmatter and body rules in `CLAUDE.md` → "Task lifecycle".
2. Before writing, list `docs/tasks/` and `docs/tasks/done/` and make sure each new slug is unique and clearly describes the work.
3. One card = one reviewable change. Order contract-first: API table in `CLAUDE.md` → backend → `OrderApiClient`/models → repository/state → UI → docs.
4. Mark `securityReview: required` when the card hits any trigger in `CLAUDE.md` → "Safety policy". Don't mark plain UI, copy, formatting, or behaviour-preserving refactors.
5. Every card names its tests and, for each acceptance criterion, how it's verified: a `make` gate, independent review, or owner acceptance in the real environment (browser/proxy/phone).

## Output

Write `docs/tasks/<slug>.md` files. Report the paths, the dependency order, open decisions, and which card to run first. Stop before implementation and wait for the owner's review.

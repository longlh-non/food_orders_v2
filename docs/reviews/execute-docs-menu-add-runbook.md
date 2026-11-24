---
task: docs-menu-add-runbook
status: passed
p0: 0
p1: 0
---

# Review: docs-menu-add-runbook

Change: `docs/runbook-local.md` only. New section "3a. Add a menu item from the restaurant app", plus one-line pointers in section 3 and section 4. `CLAUDE.md` untouched. No code changed.

## Gates

| Command | Exit | Note |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make check` | 2 | stops at `make analyze`: 30 `deprecated_member_use` infos, the known baseline (no code changed since the last card, same 30) |

Docs-only, so test and backend gates were not re-run (no code changed since the previous run that exited 0).

## Findings (code-reviewer)

- P0: 0. P1: 0.
- P2 (fixed): a wrong password (401) reopens the staff login box, not the form. Section 3a now says so.

Reviewer checked button names, field labels, quoted Vietnamese strings, limits (100/500/0-1,000,000/300), error mapping, id rule, picture steps, no password written, and CLAUDE.md untouched: all match the shipped code.

## Unverified

- That the steps work end to end in a real browser against the real backend (owner acceptance). Stated in the runbook.

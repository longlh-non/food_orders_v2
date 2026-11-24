---
task: backend-menu-staff-add-endpoint
status: passed
p0: 0
p1: 0
---

# Review: backend-menu-staff-add-endpoint

Owner approved, for this task, editing `CLAUDE.md` only to remove the five "not live until `backend-menu-staff-add-endpoint` lands" markers (done: `grep backend-menu-staff-add-endpoint CLAUDE.md` now finds nothing; the `# Engineering contract` half is byte-identical to HEAD, checked by the orchestrator).

## Gates

| Command | Exit | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make backend-analyze` | 0 | |
| `make backend-test` | 0 | 719 tests; re-run after the P2 edits below |
| `make test` | 0 | |
| `make analyze` / `make check` | 2 | 28 baseline `deprecated_member_use` infos, no new finding; `make check` stops at analyze |

## Findings (code-reviewer): P0 0, P1 0, P2 4

Implementation matches the `CLAUDE.md` `POST /menu` row on every point checked (check order, field rules, UTF-16 counting, price rules, slug and duplicate folding, `BEGIN IMMEDIATE` handling, 201 + `no-store`, fixed texts).

- Fixed: `menu_api.dart` class doc said "the one write"; now names both staff writes.
- Fixed: two legacy tests in `backend/test/menu_api_test.dart` claimed POST /menu is "not served" but passed vacuously; POST removed from both lists (`menu_add_test.dart` covers it).
- Deferred test gaps (follow-up): the "no free id" 409 path after 1000 attempts (unreachable behind the 300 cap); a forced mid-transaction exception to prove rollback; DEL/C1/tab control-character cases; a duplicate-check case with a truly decomposed name (the slug test named "decomposed" may use a precomposed literal).
- Noted, harmless: a name made only of combining marks folds to empty and clashes with another such name in one category.

## Security review: `docs/reviews/security-backend-menu-staff-add-endpoint.md`

## Unverified

Real `curl` through Caddy with real credentials, and the item appearing in the customer app (owner acceptance); contention with the `sqlite3` CLI writing at the same time (correct by reading, no test).

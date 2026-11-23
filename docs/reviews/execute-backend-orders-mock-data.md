---
task: backend-orders-mock-data
status: passed
p0: 0
p1: 0
---

# Review: backend-orders-mock-data

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make backend-analyze` | 0 | |
| `make backend-test` | 0 | 602 tests (17 new) |
| `make check` | 2 | stops at `analyze`: the 19 pre-existing `deprecated_member_use` infos (`material_ui` SDK issue), none in this card's files |

Real run (orchestrator, root-form command, temp db in scratchpad, never `backend/data/orders.db`):
`dart run backend/bin/seed_mock_orders.dart --db=<tmp> --month=2026-10 --yes` → exit 0, 321 orders inserted; the cleanup one-liner removed all 321 (0 left). The executor's own run gave the same result and confirmed that answering `no` exits 1 with nothing written.

## Changed paths

New: `backend/lib/mock_orders.dart`, `backend/lib/mock_orders_db.dart` (extra file beyond the card, so tests can reach the DB logic), `backend/bin/seed_mock_orders.dart`, `backend/test/mock_orders_test.dart`, `backend/test/seed_mock_orders_test.dart`. Edited: `docs/runbook-local.md` (new block in section 3).

## Findings (code-reviewer, round 1): P0 0, P1 0, P2 5

1. Acceptance row "run against temp file" not evidenced → resolved: real run recorded above.
2. Runbook root-form command unverified → resolved: it works from the project root (run above).
3. Runbook diff also contains section 7 "CI today" → not scope creep; it comes from the archived `ci-dependabot-and-triggers` card.
4. **Deferred P2:** generated item/topping ids are not length-checked against `maxIdLength` (a menu id over 64 chars would produce an order the real POST rejects). Menu ids are owner-controlled and short today.
5. **Deferred P2 nits:** meaningless `isNot(second.length + 100000)` assertion in `seed_mock_orders_test.dart`; the confirmation prompt doesn't say `--clean` also deletes existing `mock-` rows; `exit()` inside `try` skips `finally` (harmless at process exit).

## Unverified

The owner running it against the real `backend/data/orders.db` and viewing the result in Excel or the restaurant app.

## Verdict

**Passed**, P0: 0, P1: 0.

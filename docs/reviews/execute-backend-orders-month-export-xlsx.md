---
task: backend-orders-month-export-xlsx
status: passed
p0: 0
p1: 0
---

# Review: backend-orders-month-export-xlsx

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make backend-analyze` | 0 | |
| `make backend-test` | 0 | 635 tests (33 new in `orders_export_api_test.dart`) |
| `make check` | 2 | stops at `analyze`: the 19 pre-existing `deprecated_member_use` infos (`material_ui` SDK issue), none in this card's files; format-check and boundaries before it passed |

## Changed paths

`CLAUDE.md` (only the `GET /orders/export` row and "Exporting a month", edit approved by the owner for this task), `backend/lib/orders_api.dart`, `backend/test/orders_export_api_test.dart`.

## Findings (code-reviewer, round 1): P0 0, P1 0, P2 6 — all deferred

Deviation judged acceptable: any `format` query key returns 400 even without `report` (card's own test list requires `format=xlsx` → 400).

Deferred follow-ups (P2):
1. CLAUDE.md row/bullet should state explicitly that any `format` key is 400, also in the "no `report` means CSV" sentence.
2. `orders_api.dart` ~218-222: stale comment ("file holds customer names", old check order).
3. `orders_api.dart` ~284-292: comment that the per-order `deliveredOrders([order], month)` call exists to attribute errors to an id.
4. Report builders run outside a `try`; optionally catch `Error` and return `_exportFailed` (also noted by the security review).
5. Summary test doesn't prove preparing/cancelled/other-month orders are excluded (only detail has that test).
6. CSV byte-identical test compares two handlers on the same DB instead of pinned golden bytes.

Security review: `docs/reviews/security-backend-orders-month-export-xlsx.md` — passed, P0 0, P1 0.

## Unverified (owner acceptance)

Opening both files in Excel and comparing with the owner's samples; `curl` against the real backend with real settings; no-store/file name through Caddy/nginx.

## Verdict

**Passed**, P0: 0, P1: 0.

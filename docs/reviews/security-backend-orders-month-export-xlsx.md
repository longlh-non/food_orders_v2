---
task: backend-orders-month-export-xlsx
status: passed
p0: 0
p1: 0
---

# Security review: backend-orders-month-export-xlsx

## Scope

`GET /orders/export?month=YYYY-MM[&report=summary|detail]` in `backend/lib/orders_api.dart`, the CLAUDE.md API row, and `backend/test/orders_export_api_test.dart`. Read-only review (no commands run by the reviewer).

## Findings: P0 0, P1 0, P2 0

Checked and clean:
- Staff gate is the first statement, before query parsing, settings check, DB read and file-name construction; 401/403/429 tests send bad `month`/`report` and assert the same status and an empty body.
- `month` regex-validated; `report` must be exactly one value `summary` or `detail`; empty, repeated, mixed case, `format=` and malformed `%` escapes are 400 with fixed bodies that never echo input.
- `Content-Disposition` file name = fixed ASCII prefix + validated month: no header/path injection.
- Reports carry no customer names or order ids (`ReportOrder` holds day, description, total, method only).
- Formula injection: descriptions are written as shared-string text cells; only SUM formulas built from computed row numbers; covered by test with `=1+1` and `=cmd|...`.
- Malformed stored order → fixed 500, only the JSON-quoted id logged.
- `Cache-Control: no-store`; nosniff from the existing middleware.
- Read-only: one bound SELECT; test asserts row count and `user_version` unchanged.
- DoS: bounded by the 10,000-order cap, one month, and the gate's lock-out.
- No new dependency, CORS and proxy untouched.

## Notes (not findings)

- The summary/detail builders are not wrapped in a catch; a hand-edited DB row with a non-finite number would reach shelf's default 500 handler (stack trace logged server-side, nothing to the client). Only reachable by editing the database directly. Optional follow-up: catch `Error` around the build and call `_exportFailed`.
- The route is synchronous; a 10,000-order build briefly blocks the event loop. Staff-only, acceptable.

## Unverified (owner acceptance)

`no-store` and file name through Caddy/nginx; Excel opening both files without a repair prompt.

## Verdict

**Passed**, P0: 0, P1: 0.

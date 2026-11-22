---
task: backend-orders-month-export-endpoint
status: passed
p0: 0
p1: 0
---

# Review: backend-orders-month-export-endpoint

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-backend-orders-month-export-endpoint.md`.

## Candidate

- **`backend/lib/orders_api.dart`:** `OrdersApi(db, {maxStoredOrders, StaffGate? staffGate})`; with no gate the export answers 403. New `GET /orders/export?month=YYYY-MM`:
  1. the staff gate;
  2. the month (`isValidMonth`; a broken query escape gives 400);
  3. a read-only bound query for the month (`substr(placed_at, 1, 8) = 'YYYY-MM-'`);
  4. `ordersInMonth` → `exportRows` → `csvBytes` (part 1).
  - A 200 carries `text/csv; charset=utf-8`, an attachment named `orders-YYYY-MM.csv` (built only from the validated month) and `no-store`.
  - A malformed stored order gives a fixed 500; only its id goes to stderr, JSON-quoted.
- **`backend/bin/server.dart`:** passes the server's staff gate (the same instance as `MenuApi`).
- **`backend/test/orders_export_api_test.dart` (new):** 21 tests.
- **`CLAUDE.md` (owner-approved):**
  - the API row;
  - "### Exporting a month": curl, the columns, Excel (`sep=;`, BOM, leading `'`), old USD orders, "the file holds customer names", and "the staff token doesn't make customer data private";
  - two "Known limitations" lines (device-clock month; open `/api/orders`);
  - the Staff token intro.

Owner decisions: EXP1 pick the month, EXP2 CSV now, EXP3 HTTP behind the staff token, EXP4 text month from `placedAt`, EXP5 the format from part 1. `CLAUDE.md` edits approved (2026-11-19). EXP5b (delete old USD test orders) is still the owner's to do.

## Round 1: passed. P0 0, P1 0, P2 3

- **P2-1:** two comments were left in the wrong place by the insertion ("Newest first…" above the export route; the `_orderFromRow` doc above `_exportFailed`). **Fixed.**
- **P2-2:** the logged order id is client-supplied and could carry newlines or control characters. **Fixed:** it's JSON-quoted (shared with the security review).
- **P2-3 (tests):**
  - The SSE route isn't exercised in the new file; it's still covered by `test/orders_api_test.dart`.
  - The 400 cases' "no customer name" check proves little, but the `content-disposition == null` check is the real assertion.
  - Nothing shows a malformed order in another month is ignored (correct by construction). Deferred, optional.

Confirmed:
- **Goals:** 1–3, and the order of checks (tested: the token is checked before the month).
- **No route shadowing:** `/orders/<id>` is PATCH only.
- **The SQL prefilter** equals `startsWith('YYYY-MM-')`.
- **The per-order export loop** gives the same output as one call.
- **`CLAUDE.md`** matches the code (statuses, headers, file name, the column list vs `exportHeader`).
- **No new dependency.**

## Re-review 1 (security reviewer, on the fix batch): passed. P0 0, P1 0

## Deferred follow-ups

1. **Huge months:** the whole month is built in memory synchronously. A deliberately huge month (only a token holder can ask) could pause the backend. Stream the rows, or cap the export.
2. **Log escaping:** `jsonEncode` doesn't escape DEL or C1 control characters. Optionally strip `[\x00-\x1f\x7f-\x9f]` and cap at 64 characters. Negligible: it needs a hand-corrupted row.
3. **One more test:** a malformed order in another month doesn't affect this month's export.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make backend-analyze` (round 1 and after fixes) | 0 |
| `make backend-test` (327 tests; round 1 and after fixes) | 0 |
| `make format-check` (round 1 and after fixes) | 0 |
| `make boundaries` (round 1 and after fixes) | 0 |
| `git diff --stat backend/pubspec.yaml` (empty) | 0 |
| `make check` (final candidate; 303 app + 327 backend tests) | 0 |

## Unverified (owner acceptance)

With the backend restarted with `STAFF_TOKEN`:
- `curl -H "X-Staff-Token: $STAFF_TOKEN" -o test.csv "http://customer.local/api/orders/export?month=2026-11"` downloads the month;
- without the header, 401;
- the file opens in Excel (Vietnamese settings) with columns split, diacritics intact and prices summing;
- Caddy doesn't log the `X-Staff-Token` header.

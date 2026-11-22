---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: [backend-orders-month-export-format, backend-staff-token-gate]
securityReview: required
---

# Monthly orders export, part 2: `GET /orders/export?month=YYYY-MM` behind the staff token

Replaces the local-command card `backend-orders-month-export-cli` (removed 2026-11-12), because the owner chose an HTTP endpoint. Its security notes are carried over below.

## Owner decisions (2026-11-12)

- **EXP3 = (b):** HTTP endpoint behind the staff token (`backend-staff-token-gate`), so staff can press a button in the restaurant app (`restaurant-orders-month-export-button`).
- **EXP1 = pick the month:** on demand, staff choose the month. No scheduler.
- **EXP2 = CSV now.** `.xlsx` is a separate later card (`backend-orders-month-export-xlsx`).
- **EXP4 = as recommended:** an order belongs to the month in its `placedAt` text, read as shop-local time (Asia/Ho_Chi_Minh), compared as text and never converted. Known limit: `placedAt` comes from the customer's device clock, so a phone with a wrong date puts its order in the wrong month. A server-side timestamp is a separate future contract change.
- **EXP5 (columns/format): the owner will send the format later.** This card ships the format already built in part 1 (`exportHeader` in `backend/lib/orders_export.dart`). When the owner's format arrives, a new card changes part 1; this endpoint does not need to change.
- **EXP5b (old USD test orders): still open.** Recommended: the owner deletes them with `sqlite3` after a dated backup before the first real export. The endpoint never changes or hides data.

## THE critical issue: this file holds every customer's name and order history

Anyone who gets the CSV gets all customer names for that month. So: the route is staff-only and fails closed, the response is never cached, and nothing about the content is logged.

## Sources

`backend/lib/orders_export.dart` (part 1: `isValidMonth`, `ordersInMonth`, `exportRows`, `csvBytes`), `backend/lib/staff_token.dart` (from the gate card), `backend/lib/orders_api.dart` (routes, `_orderFromRow`, SQLite reads), `CLAUDE.md` -> "Backend" (table, Storage, Known limitations).

## Goal

1. **Contract first (invariant 3).** `CLAUDE.md` -> "Backend" table (owner approval needed for this edit, per task): add `GET /orders/export?month=YYYY-MM`, header `X-Staff-Token`. Responses:
   - 200 `text/csv; charset=utf-8`, `Content-Disposition: attachment; filename="orders-YYYY-MM.csv"`, `Cache-Control: no-store`, body = part 1's `csvBytes(exportRows(ordersInMonth(all, month)))`. An empty month is a header-only file, still 200.
   - 400 missing or invalid `month` (checked with `isValidMonth` **before** anything else uses it); 401 missing/wrong token; 403 staff routes disabled.
   - 500 with a short fixed message when a stored order is malformed (e.g. a string price makes `exportRows` throw). Never skip it silently; log the **order id only** on the server.
   - Add an "Exporting a month" paragraph: what the button/URL does, how to open the file in Excel (double click, or Data -> From Text/CSV; the `sep=;` first line; the leading `'` on cells that started with `=`, `+`, `-`, `@`), that the file contains customer data and must not be committed or shared through unsafe channels. "Known limitations": month comes from the device-clock `placedAt`.
2. **Backend.** Route in `OrdersApi`, registered so `/orders/export` is never mistaken for an order id (there is no `GET /orders/<id>` today; keep it that way or order the routes so the fixed path wins). Order: token check, then month check, then read. Reads only (never writes, never migrates). The file name in `Content-Disposition` is built only from the validated month.
3. **No content in logs.** `logRequests` logs the URL (month only) and status; that is fine. Nothing logs customer names, the token, or the CSV.

## Non-goals

Restaurant UI (next card), `.xlsx`, scheduling or emailing, deleting or editing orders, a summary/totals response, changing the CSV format, time-zone conversion.

## Tests written with the change

In `backend/test/orders_api_test.dart` or a new `backend/test/orders_export_api_test.dart` (in-memory database, token passed by constructor):
- valid token + month with orders in three months -> 200, only that month's lines, headers exact (`text/csv; charset=utf-8`, attachment file name, `no-store`), body starts with the BOM, Vietnamese names intact;
- empty month -> 200 header-only;
- `month` missing, `2026-13`, `2026-1`, `../x`, `2026-11/../../x`, a very long string -> 400, and the file name never contains anything but the validated month;
- no token -> 401; wrong token -> 401; gate disabled -> 403; in all three the body holds no customer data;
- a stored order with a string price -> 500 with the fixed message, no customer name in the body;
- the database is unchanged after an export (row count and `PRAGMA user_version`);
- a customer named `=cmd|' /C calc'!A0` comes back as `'=cmd...` (end-to-end check of part 1);
- `GET /orders`, `POST /orders`, `PATCH /orders/{id}` and the SSE route still behave as before.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour and status codes as listed | `make backend-test` (gate) |
| Backend clean | `make backend-analyze` (gate) |
| Staff-only, fails closed, month validated before use, no customer data or token in logs or errors, `no-store`, CORS not widened, no new dependency | `security-reviewer` (review; customer data + endpoint trigger) |
| `CLAUDE.md` table and paragraph match the code | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| With the real backend and token: `curl -H "X-Staff-Token: ..." "http://customer.local/api/orders/export?month=2026-11" -o test.csv` downloads the month; without the header -> 401; the file opens in Excel (Vietnamese settings) with columns split, diacritics intact, prices summing | owner acceptance - "unverified" until done |

## Carried over from the removed CLI card's reviews

- File and data safety: validate `month` before using it anywhere; the download name comes only from the validated month; never cache (`no-store`).
- Malformed old data (security P2-2): `exportRows` throws a `TypeError` on a malformed stored order. Catch it, log the order id, answer 500. Never skip silently.
- Non-whole prices (code P2-2): values like `9.5` (old USD test orders) are written with `.`, which Vietnamese Excel reads as text, so they will not sum. There is no terminal here to print a warning, so the "Exporting a month" paragraph in `CLAUDE.md` says so and points to EXP5b (delete the test orders first).

## Environment limits

Agents never call the endpoint against the owner's real database (it holds customer names) and cannot open Excel; the owner does both.

## Added by `backend-staff-token-gate` reviews (2026-11-12)

- **Read this first (security P2-1):** `GET /orders` and `GET /orders/stream` already give every customer name and order to anyone on the wifi, with no token. So gating the export adds **no real confidentiality** until those routes are gated too (that needs the apps to send a token, or real staff login). Neither this card nor `CLAUDE.md` may claim that the staff token protects customer data. Say it plainly in the "Exporting a month" paragraph and in "Known limitations".
- **Token only in the header:** never accept it in the query string, because `logRequests` logs URLs.
- **Gate first:** check the gate before any month parsing or database work. Cascade only falls through on 404/405, so a 401/403 from this route never reaches another API.
- **`Cache-Control: no-store`** on the 200 response (already in the Goal).
- **Owner check through Caddy:** `X-Staff-Token` reaches the backend and isn't written to Caddy's access log.
- **Header name (security re-review):** `shelf_cors_headers` 0.1.5 allows `authorization` cross-origin by default and reflects any `Origin`. So keep staff auth on `X-Staff-Token` only, never `Authorization: Bearer`, and never add `x-staff-token` to the CORS allow-list. Because the `Origin` is reflected, any web page the owner visits can also read the open `GET /orders`. That's the same pre-existing exposure as above.

## Owner approval and executor notes (2026-11-19)

- **Owner approval:** the owner approved the `CLAUDE.md` edits for this card.
- **Gate:** `OrdersApi(db, {maxStoredOrders, StaffGate? staffGate})`. Without a gate the export answers 403 (fail closed); `bin/server.dart` passes the server's gate.
- **Order of checks:** gate, then `month` (`isValidMonth`; a broken `%` escape in the query gives 400 too), then a read-only `SELECT … WHERE substr(placed_at, 1, 8) = ?` with the month bound. Then `ordersInMonth`, `exportRows` and `csvBytes` from part 1.
- **Malformed stored orders:** bad items JSON, or a field of the wrong type, makes the export stop with 500 "Export failed: a stored order is malformed". Only `month export: stored order <id> is malformed` goes to stderr.
- **No content in logs:** `logRequests` logs the URL (month only) and status. The token travels only in the header.
- **`GET /orders` vs the export:** `GET /orders` is limited to the newest 500; the export reads every order of the month straight from the table.
- **EXP5b** (delete old USD test orders) is still the owner's to do; `CLAUDE.md` says so.

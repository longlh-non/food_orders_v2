---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: [backend-report-summary-xlsx, backend-report-detail-xlsx]
securityReview: required
---

# Backend: `GET /orders/export?month=...&report=summary|detail` (the two Excel reports)

Created 2026-11-12 as "monthly export as a real .xlsx"; **rewritten 2026-11-19** to be the route card of the two-report plan (it keeps its slug so earlier references still work). What changed against the first version:
- The one-sheet "same rows as the CSV, `format=xlsx`" design is **dropped**. The owner wants two specific reports that look like his samples (`backend-report-summary-xlsx`, `backend-report-detail-xlsx`).
- The query parameter is `report`, not `format`.
- The "CSV / Excel choice in the dialog" part moved to `restaurant-export-report-choice`.
- The old decisions XLSX1 (how the file is built) and EXP5 (format) are replaced by RPT4 (in `backend-xlsx-writer`) and by the layouts; the owner's format has arrived.

**No open decisions block this card.** Changes the `CLAUDE.md` API table first (owner approval needed for this card).

## Decision

- **RPT5, decided (owner, 2026-11-19, "OK" to the recommendation):** **keep the CSV export, unchanged.** `GET /orders/export?month=YYYY-MM` with no `report` stays the CSV (one row per order line, all statuses, customer names) for filtering and pivot tables in Excel; the two reports are for the books.

## Sources

`backend/lib/orders_api.dart` (the export route and `_exportFailed`), `backend/lib/orders_export.dart` (CSV, unchanged), `backend/lib/orders_report.dart`, `backend/lib/report_summary.dart`, `backend/lib/report_detail.dart`, `backend/lib/shop_settings.dart`, `backend/lib/staff_gate.dart`, `backend/test/orders_export_api_test.dart`, `CLAUDE.md` -> "Backend" (export row, "Exporting a month").

## Goal

### Contract (table first)

`GET /orders/export?month=YYYY-MM[&report=summary|detail]`, staff only (`X-Staff-Id` + `X-Staff-Password`), as today for the CSV.

| `report` | Result |
|---|---|
| absent | the CSV, exactly as today (RPT5) |
| `summary` | 200 `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, `Content-Disposition: attachment; filename="bao-cao-tong-hop-YYYY-MM.xlsx"`, `Cache-Control: no-store`; the workbook with sheets `gộp` and `tách` |
| `detail` | the same headers with `filename="chi-tiet-YYYY-MM.xlsx"`; the one-sheet detailed workbook |
| anything else (also `format=xlsx`, `report=` empty, repeated `report`) | 400 |

- Extra status for `summary`: **503** with a fixed message when `ShopSettings.reportEnabled` is false (a report with blank shop details would be wrong; the CSV and `detail` don't need the settings).
- Both reports are built from the month's **`delivered`** orders only; the file contains no customer names or order ids.
- Order of checks: staff gate, then `month`, then `report`, then settings (summary only), then the read. File names come only from the validated month and a fixed prefix (ASCII, no accents, so every browser accepts them).
- A stored order that can't be read (bad JSON, a string price) -> the same 500 with the fixed message and only the order id logged, as the CSV does.
- The route reads only; nothing is written, migrated or cached.

## Non-goals

Changing the CSV, any new report, a month range, scheduling, emailing, the restaurant UI (`restaurant-export-report-choice`).

## Tests written with the change

In `backend/test/orders_export_api_test.dart` (in-memory database, injected staff gate and settings):
- `report=summary` and `report=detail` for a month with orders in other months and statuses: 200, headers exact, body is a valid zip whose sheets/cells match the delivered orders only (read with the test reader); the CSV default is **byte-identical** to before (golden bytes from the existing tests).
- gate: no headers 401, wrong 401, gate disabled 403, lock-out 429, for both reports; the checks run before the month and report checks; bodies hold no data.
- `month` missing / `2026-13` / `../x` -> 400; `report=other`, `report=`, `report=summary&report=detail`, `format=xlsx` -> 400.
- `summary` with settings disabled -> 503 fixed message; `detail` and the CSV still 200.
- a transfer order and a cash order on one day land in the right columns end to end; an order with no stored method counts as cash.
- a malformed stored order -> 500, fixed message, only its id in stderr.
- the database is unchanged by an export (row count, `user_version`).
- a customer named `=cmd|' /C calc'!A0` and an item named `=1+1` can't become a formula in either workbook.
- Existing orders, menu and staff tests still pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour and status codes as listed | `make backend-test` (gate) |
| Backend clean | `make backend-analyze` (gate) |
| Staff-only, fails closed, month and report validated before use, `no-store`, no customer data in either report, CORS not widened, no new dependency beyond the writer card's | `security-reviewer` (review; endpoint trigger) |
| `CLAUDE.md` table matches the code | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| With the real backend, real settings and a staff ID: `curl ... "http://customer.local/api/orders/export?month=2026-11&report=summary" -o a.xlsx` (and `detail`) download files that open in Excel and look like the samples | owner acceptance - "unverified" until done |

## Environment limits

Agents never call the endpoint against the owner's real database and can't open Excel; the owner does both.

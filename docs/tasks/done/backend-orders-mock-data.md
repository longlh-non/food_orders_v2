---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: []
---

# Backend: a dev tool that seeds realistic mock orders, for testing the two Excel reports

Planned 2026-11-22. Written because `backend-report-detail-xlsx` and `backend-report-summary-xlsx` (both done) and the still-open `backend-orders-month-export-xlsx` all end in the same "owner acceptance" row: *open the generated file in Excel next to `sample/...` and look at it* — which needs a real month of order data in the owner's **local** dev database (`backend/data/orders.db`), and today there isn't any realistic data to point either report builder at.

## Why this card isn't blocked by the export route

`buildSummaryReport`/`buildDetailReport` (done) take `List<DayTotals>` from `orders_report.dart`'s `dailyTotals`/`daysWithOrders` (also done) — plain data, no HTTP. This card only needs rows to exist in the `orders` table in the shape those functions already read; it does not need `GET /orders/export?report=...` to exist. `blockedBy: []`.

## Decision: write rows directly with SQLite, not by POSTing to a running backend

Weighed against driving `POST /orders` + the status/payment routes for every mock order:

- To reach `delivered` through the real API, a `bank_transfer` order must first be moved out of `awaiting_payment` by a **staff-only** route (`confirm-payment` or `staff-switch-to-cash`, both needing `X-Staff-Id`/`X-Staff-Password`), then PATCHed through to `delivered`. A `cash` order needs one PATCH. Multiplied over a realistic month's worth of orders, that's hundreds of sequential HTTP calls, a backend that must already be running, and staff credentials the script would have to be handed safely — a lot of moving parts for what is, in the end, just rows in a table.
- Writing rows straight into `backend/data/orders.db` is the same thing CLAUDE.md already documents and sanctions for day-to-day menu edits ("Editing the menu": direct `sqlite3` INSERT/UPDATE against this same file, with a dated backup first). Orders are a different table in the same file, same risk profile, same discipline.
- Reusing `openDatabase()` from `backend/lib/database.dart` (exactly what `bin/server.dart` calls) means the script never duplicates schema/migration logic and is safe to point at a brand-new file or an already-migrated one.
- Trade-off accepted: inserted rows bypass `_orderProblem` (the POST validator in `orders_api.dart`), which is **private** to that file and can't be imported. The generator instead builds every row within the same **public** bound constants `orders_api.dart` already exports (`maxIdLength`, `maxNameLength`, `maxItemsPerOrder`, `maxQuantity`, `maxPrice`, `maxToppingsPerItem`, `orderStatuses`, `paymentMethods`), so it can't drift from the real limits even though it isn't calling the same function. If the owner later wants byte-for-byte identical validation, making `_orderProblem` public (a visibility-only change, no behaviour change) is a one-line follow-up — not done here, to avoid touching `orders_api.dart` for a dev tool's convenience.

## Decision: mock orders are created already in a terminal state

Real "last month" data, by the time anyone runs a report, is settled: every order is either `delivered` or `cancelled`. The generator **never** produces `awaiting_payment`, `preparing` or `ready` rows, and never simulates the payment countdown/expiry. Consequence: `paymentDueAt` is always `NULL` in every generated row — the only way a real order leaves `awaiting_payment` for a later status is through a payment route that already clears it, or a PATCH-cancel that also clears it, so a settled order with a non-null `paymentDueAt` is not a state the real backend would ever hand you (it only happens on live, not-yet-resolved transfer orders). This sidesteps simulating the payment state machine entirely while staying faithful to what the real backend produces.

## Security review

Not required. No HTTP/SSE route is added or changed, no new JSON is parsed from an untrusted source (the script only encodes data it generated itself, with `jsonEncode`, exactly as `orders_api.dart` already does), no CORS/network/proxy/mDNS/dev-infra file is touched, and no new dependency is added.

## Sources

`backend/lib/database.dart` (`openDatabase`, reused as-is), `backend/lib/orders_api.dart` (the public constants listed above, and the `INSERT INTO orders (...)` shape at `orders_api.dart:304-314` to match column-for-column), `backend/lib/orders_report.dart` (`deliveredOrders`, `dailyTotals`, `daysWithOrders`, `orderTotal`), `backend/lib/report_summary.dart`, `backend/lib/report_detail.dart`, `backend/lib/shop_settings.dart`, `backend/bin/server.dart` (the `ORDERS_DB` env convention), `docs/tasks/done/backend-report-detail-xlsx.md`, `docs/tasks/done/backend-report-summary-xlsx.md`, `docs/tasks/backend-orders-month-export-xlsx.md`, CLAUDE.md -> "Storage", "Editing the menu".

## Goal

### 1. `backend/lib/mock_orders.dart` — pure generator, no database, no files

```dart
List<Map<String, dynamic>> buildMockOrders({
  required String month,          // 'YYYY-MM'
  required List<Map<String, dynamic>> menuItems,  // GET /menu shape, available ones only
  required List<Map<String, dynamic>> toppings,   // GET /toppings shape
  required int seed,
  required int runTimestampMs,    // wall-clock at the moment of the real run
})
```

Returns rows ready for the `INSERT` below (`id, customerName, status, placedAt, items, paymentMethod, paymentDueAt`). Requirements:

- **Menu-driven, not hand-written item names.** Lines are built by picking from the `menuItems`/`toppings` passed in (the caller reads them from the **same target database**'s `menu_items`/`toppings` tables), so order descriptions are the owner's real current Vietnamese menu text, never a separate hard-coded list. Toppings are only attached to items whose `allowToppings` is true, and only from the given `toppings` list — same rule the real menu enforces.
- **Every calendar day of `month` is covered**, but at least one specific day (deterministic, not probabilistic — e.g. always the 1st, or picked from `seed`) gets **zero** orders, to exercise RPT1 (summary: shown as 0) and RPT2 (detail: day skipped).
- **A realistic spread per day**: a random (seed-controlled) count of orders per day, varying item lines per order (1-4), quantities (mostly 1-2, occasionally more), some lines with toppings and some without, a mix of `cash` and `bank_transfer` among `delivered` orders, and a minority (recommended 10-20%) of rows left `cancelled` so a delivered-only report can be visibly checked against the fuller order list.
- **`paymentDueAt` is always `null`** (see decision above).
- **Field bounds**: every generated value stays within the public constants imported from `orders_api.dart` (`maxIdLength`, `maxNameLength`, `maxItemsPerOrder`, `maxQuantity`, `maxPrice`, `maxToppingsPerItem`); `status` is always `orderStatuses`-valid (`delivered` or `cancelled` only, per the decision above); `paymentMethod` is always `paymentMethods`-valid.
- **Ids**: `mock-<runTimestampMs>-<index>` — unique within a run and across runs without `--clean`, since `runTimestampMs` is wall-clock, not the deterministic `seed`. `seed` controls everything else (which days/items/toppings/method/customer name are picked), so two calls with the same `seed`, `month`, `menuItems` and `toppings` produce identical output except for the id's timestamp component.
- **Customer names**: a small fixed list of plausible Vietnamese names with diacritics, defined in this file (see open decision 3).
- **`placedAt`**: an ISO-8601 string (`YYYY-MM-DDTHH:MM:SS...`) with a plausible time of day for a food shop (recommended 07:00-21:00), on the right calendar day.
- A handful of rows (recommended 2-3) are placed just outside `month` (last day of the previous month, first day of the next), still respecting the same field rules, so the owner can see the month filter actually excludes them when a report is run.

### 2. `backend/bin/seed_mock_orders.dart` — thin CLI wrapper

1. Flags (hand-rolled parsing, no new dependency — the project doesn't carry `package:args`): `--month=YYYY-MM` (default: the previous full calendar month), `--db=PATH` (default: `ORDERS_DB` env var if set, else the same relative default `bin/server.dart` uses), `--seed=N` (default: a fixed constant, so a bare run is reproducible), `--clean` (delete existing `id LIKE 'mock-%'` rows before inserting), `--yes` (skip the interactive confirmation).
2. Resolve the absolute db path and print it, plus the dated-backup command from CLAUDE.md's "Storage" section (`cp <path> "<path>.$(date +%F-%H%M).bak"`), then require typed `yes` on stdin (or `--yes`) before writing anything.
3. `openDatabase(path)` (creates/migrates exactly like the real server).
4. Read `menu_items` (`available = 1`) and `toppings` from that same database.
5. Refuse (print and exit non-zero) if the current row count in `orders` plus the rows about to be inserted would reach or exceed `defaultMaxStoredOrders` (10,000) — the same cap the backend itself enforces.
6. Call `buildMockOrders`, then run the same `INSERT INTO orders (id, customer_name, status, placed_at, items_json, payment_method, payment_due_at) VALUES (?, ?, ?, ?, ?, ?, ?)` shape `orders_api.dart` uses for a real POST (`items_json` = `jsonEncode(items)`), always with `?` placeholders.
7. Print a summary (how many rows, date range, counts by status/method) and the exact cleanup one-liner: `DELETE FROM orders WHERE id LIKE 'mock-%'`.

### 3. `docs/runbook-local.md`

Add a short subsection under "3. Database" (not a new numbered section): how to run the script (with and without `--month`/`--clean`), the backup reminder, and the cleanup one-liner. Plain copy-paste commands, matching the file's existing style (no new top-level section, no restructuring).

## Non-goals

Any change under `lib/` (the Flutter apps), any change to `backend/lib/orders_api.dart`'s behaviour (only its already-public constants are imported, read-only), the HTTP export route, a report-preview CLI that writes an actual `.xlsx` from the mocked data (useful, but a separate concern from generating the data itself — raised as a suggestion below, not built here), simulating `awaiting_payment`/payment expiry/renewal, any UI, any new dependency, `dev/**` or `tool/**`.

## Decisions (owner), with recommendations

1. **How much data, which month(s).** Recommended: `--month` defaults to the previous full calendar month, one month per run; re-run with a different `--month` for more. If the owner wants several consecutive months seeded by default (e.g. to also sanity-check a report run spanning a month boundary beyond the few stray adjacent-month rows already planned), say so and the default becomes a loop over N months.
2. **Re-run behaviour: append or replace.** Recommended default: **append** (never deletes without being asked — `--clean` is opt-in). Running the script twice for the same month without `--clean` doubles that month's mock data, which is harmless (ids never collide) but does change report totals between runs. If the owner would rather re-running the same `--month` silently replace the previous mock rows for that month, say so.
3. **Customer names: hand-picked list or generated.** Recommended: a short hand-picked list (10-20 common Vietnamese given/family name combinations with diacritics) written straight into `mock_orders.dart`. Simpler, no new dependency, good enough for a visual spot-check. A combinatorial generator (first name x last name parts) would give more variety but isn't needed for what this data is for.
4. **Confirmation gate strictness.** Recommended: the printed warning + typed-`yes`/`--yes` gate described above (section 2, bin script). An alternative is no gate at all, matching the low-ceremony `sqlite3` one-liners CLAUDE.md already documents for menu edits (which have no confirmation step). Recommended staying slightly more careful here only because this can insert hundreds of rows in one call versus a single `UPDATE`; say if the owner finds the gate annoying and prefers it removed.

## Suggestion (not built, needs a separate decision if wanted)

A tiny companion CLI that reads **any** orders.db (mock or real), computes `dailyTotals`/`daysWithOrders` for a given month, and writes `buildSummaryReport`/`buildDetailReport`'s bytes straight to a `.xlsx` file on disk — letting the owner see an actual report file today, without waiting on the blocked `backend-orders-month-export-xlsx` route. This reuses only already-done, already-reviewed pure functions and touches no HTTP surface, so it would be low-risk, but it's a distinct deliverable (consumes data; this card produces it) and wasn't asked for. If wanted, it should be its own small task card.

## Tests written with the change

`backend/test/mock_orders_test.dart` (pure function, no I/O):
- same `seed`, `month`, `menuItems`, `toppings` -> identical output except the id's timestamp component (determinism).
- every row: `id` starts with `mock-`, non-empty, `<= maxIdLength`; `customerName <= maxNameLength`; `items` non-empty, `<= maxItemsPerOrder`; each item `name <= maxNameLength`, `quantity` a whole number in `1..maxQuantity`, `price` a whole number in `0..maxPrice`; each item's `toppings.length <= maxToppingsPerItem` and only present when the source menu item's `allowToppings` was true; `status` is `delivered` or `cancelled` only, both in `orderStatuses`; `paymentMethod` in `paymentMethods`; `paymentDueAt` is always `null`; `placedAt` matches `^\d{4}-\d{2}-\d{2}T` and parses.
- at least one calendar day in the requested month has zero rows, guaranteed every call (not just most calls).
- a few rows fall just outside the month (previous/next), and are themselves still field-valid.
- toppings only ever come from the given `toppings` list and only attach to items whose source menu row allows them; an empty `menuItems` or `toppings` list still returns a valid (smaller) result, not a crash.

`backend/test/seed_mock_orders_test.dart` (integration, in-memory database, no stdin/CLI parsing involved — exercise the testable pieces directly):
- `openDatabase(':memory:')` + the generator's rows inserted with the exact column list above are read back by `_db.select('SELECT * FROM orders')`-equivalent and, after being reshaped the way `orders_api.dart`'s `_orderFromRow` does, round-trip correctly through `deliveredOrders`, `dailyTotals` and `daysWithOrders` from `orders_report.dart` (right counts, right day buckets, cash vs transfer split matches what was generated).
- those `DayTotals` are then fed into both `buildSummaryReport` and `buildDetailReport` (with a throwaway `ShopSettings`) and produce non-empty, valid zip bytes without throwing — proving the whole chain (mock data -> report bytes) actually works end to end, entirely inside `make backend-test`.
- the cap check: given a database already holding `defaultMaxStoredOrders` rows, the insert step is refused (whatever function/flag implements it) rather than silently exceeding the cap.
- `--clean`'s deletion only ever removes rows whose id matches `mock-%`, never anything else, verified against a database seeded with one real-looking (non-`mock-`) row first.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Generator determinism, field bounds, guaranteed empty day, menu-driven lines, terminal-state-only, `paymentDueAt` always null | `make backend-test` (gate) |
| Round-trip through `orders_report.dart` and both report builders produces valid, non-empty `.xlsx` bytes from generated data alone | `make backend-test` (gate) |
| 10,000-order cap respected; `--clean` only touches `mock-*` rows | `make backend-test` (gate) |
| Backend clean; no new dependency | `make backend-analyze` (gate) |
| A real run against a disposable temp-file database (never `backend/data/orders.db`) prints the summary, inserts the expected row count, and the printed cleanup one-liner removes exactly those rows | executor runs `dart run backend/bin/seed_mock_orders.dart --db=<temp path> --yes` during execution and records the output (gate-equivalent, not owner acceptance, since no real data is touched) |
| `docs/runbook-local.md` subsection matches the script's actual flags and defaults | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| Owner runs it for real: backs up `backend/data/orders.db` first (section 3 of the runbook), runs the script against it, and the resulting data looks plausible when browsed with `sqlite3`/the restaurant app | owner acceptance - "unverified" until done |

## Environment limits

Agents never point this script at `backend/data/orders.db` (the owner's real local database, which holds real customer names); every automated and executor-run check above uses `:memory:` or a disposable temp file. Running it against the real file, after the owner's own dated backup, and judging whether the resulting mock data "looks right" day-to-day, is the owner's step. Agents also still can't open Excel — this card only produces rows in the database, not a report file (see "Suggestion" above for that gap).

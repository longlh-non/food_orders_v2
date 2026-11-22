---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: []
securityReview: required
---

# Monthly orders export, part 1: build the CSV text (pure code, no file, no endpoint)

## Why

The owner wants the orders of one month in a spreadsheet. This card builds only the logic that turns a list of orders into the text of a CSV file that Excel opens correctly. It reads no database, writes no file, adds no route and no package. That keeps it small and fully testable with `dart test`. Part 2 (`backend-orders-month-export-cli`) wires it to the database.

Security review is required even though nothing is exposed here: the text includes customer-typed names, and a name like `=HYPERLINK(...)` can run as a formula when the file is opened in Excel (CSV/formula injection). This card is where that is prevented.

## Sources

`backend/lib/orders_api.dart` (the order JSON shape and `_orderFromRow`; do not import its private helpers, make small public ones if needed), `lib/shared/money.dart` (only to know prices are whole VND; do not format prices in the file), `CLAUDE.md` -> "Backend" (Prices, Order rules).

## Open decisions (owner), recommendation each

- EXP2 delimiter: Excel with a Vietnamese Windows setting uses `;` between columns (because `,` is the decimal mark), so a comma-separated file opens as one long column there. Recommended: write `;` as the delimiter AND a first line `sep=;`, which tells Excel what to use on any regional setting. Plain trade-off: Google Sheets and LibreOffice may show the `sep=;` line as a data row. The writer takes the delimiter and the `sep=` line as parameters so one constant switches them. Whether Excel honours `sep=;` together with the UTF-8 BOM is **unverified** until the owner opens a sample file (see acceptance).
- EXP5 rows: one row per order **line** (an order with 3 lines gives 3 rows, the order id and customer repeated). Recommended because Excel filtering and pivot tables work on it directly. Toppings go in one text column (`Thêm chả; Thêm thịt`), not extra rows.
- EXP5 statuses: include all, with a status column, so the owner filters in Excel. No total row inside the file (a total row breaks sorting and pivots); totals are printed by the CLI in part 2.
- EXP5 header language: recommended Vietnamese (the file is for the shop, not app UI): `Ngày, Giờ, Mã đơn, Khách, Món, Số lượng, Đơn giá, Topping, Thành tiền, Trạng thái`. If the owner prefers English, change the constant. Status values stay the backend names (`delivered` ...), not translated, so the file stays filterable and matches the database.

## Goal

New file `backend/lib/orders_export.dart` with public, pure functions (no `dart:io`, no database):

1. `bool isValidMonth(String s)`: exactly `YYYY-MM`, month 01-12.
2. `List<Map<String, dynamic>> ordersInMonth(List<Map<String, dynamic>> orders, String month)`: keeps orders whose `placedAt` starts with `month + '-'`, sorted by `placedAt` ascending, ties kept in input order. The time is treated as the shop's local time (Asia/Ho_Chi_Minh): `placedAt` has no time zone and is compared as text, never converted. A value ending in `Z` or with an offset is still compared by its text prefix (noted in the doc comment as a known limit).
3. `List<List<Object>> exportRows(List<Map<String, dynamic>> orders)`: one row per item line, columns in this order: date (`YYYY-MM-DD`), time (`HH:MM`, empty if `placedAt` has no time part), order id, customer, item name, quantity (int), unit price = base price + sum of topping prices (number), toppings text (names joined by `; `), line total = unit price x quantity (number), status. Old orders without `id` or `toppings` work.
4. `String neutralise(String cell)`: if the text starts with `=`, `+`, `-`, `@`, tab or carriage return (also after leading spaces), prefix `'`. Applied to every **text** cell (customer, item name, topping names, order id); never to numbers.
5. `List<int> csvBytes(List<List<Object>> rows, {String delimiter = ';', bool sepLine = true})`: UTF-8 bytes starting with the BOM `EF BB BF`, then (if `sepLine`) `sep=;`, then the header row, then data rows. Line ending CRLF. A text cell is wrapped in `"` when it contains the delimiter, `"`, CR or LF, with `"` doubled. Numbers are written bare with no thousands separator and no currency text (whole VND as `25000`, so Excel can SUM).
6. `ExportSummary summarise(...)`: counts of orders and lines, VND total per status, grand total excluding `cancelled`, and how many lines have a non-whole price or quantity (old USD test data such as `9.5`). Used by part 2 for the terminal printout.

Prices that are not whole numbers are written as-is with `.` (not rounded) and counted in the summary so the owner is warned; the exporter never rewrites money.

## Non-goals

`.xlsx` (see "Format alternative"), reading the database, writing files, HTTP endpoint, UI, scheduling, server-side timestamps, time-zone conversion.

## Format alternative (not planned, for the owner's information)

Real `.xlsx` needs a Dart package (e.g. `excel`) in `backend/pubspec.yaml`: a new dependency, so it needs the owner's approval and a supply-chain look first (CLAUDE.md invariant 5). Gains: column widths, bold header, real numbers/dates, no separator or BOM problems. Costs: a dependency that pulls in other packages, and more code to review. Dart's standard library cannot make zip files, so there is no dependency-free way to build `.xlsx`. If the CSV turns out annoying in practice, a separate card `backend-orders-month-export-xlsx` swaps only `csvBytes` for an xlsx writer behind the same rows; part 1's row logic is reused unchanged.

## Tests written with the change

`backend/test/orders_export_test.dart`:
- `isValidMonth`: accepts `2026-11`, rejects `2026-13`, `2026-00`, `2026-1`, `202611`, `2026-11-01`, empty, `2026-11 ` and `2026-11%`.
- `ordersInMonth`: only that month; boundary values `2026-10-31T23:59:59.999` out, `2026-11-01T00:00:00.000` in, `2026-11-30T23:59:59.999` in, `2026-12-01T00:00:00.000` out; sorted ascending; empty list when none.
- `exportRows`: line with toppings (`price 25000 + 5000 + 10000`, quantity 2 gives unit 40000, total 80000); line without `toppings`/`id`; two-line order gives two rows; same topping twice counted twice; time empty when absent.
- `neutralise`: `=1+1`, `+84`, `-5`, `@SUM(A1)`, tab-prefixed, `  =x` get `'`; `Nguyễn Văn A`, `Bánh mì`, `a=b` unchanged; applied to customer, item and topping text in rows; numbers untouched.
- `csvBytes`: starts with bytes `EF BB BF`; contains `sep=;` line only when asked; CRLF; a name with `;`, with `"`, and with a newline is quoted and doubled correctly; round trip: decode the bytes as UTF-8, parse with a small test-local reader, and get the same Vietnamese strings back (`Xôi ruốc`, `Thêm chả`, `Trứng ngải cứu`, combining and precomposed forms are not altered); numbers have no separators.
- `summarise`: per-status totals, cancelled excluded from the grand total, non-whole price counted (`9.5`).
- Empty month gives the header only (BOM, sep line, header), no crash.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Month filter, rows, totals, quoting, BOM, Vietnamese round trip as listed | `make backend-test` (gate) |
| Formula-trigger text cells are neutralised, numbers are not | `make backend-test` (gate) and `security-reviewer` (review) |
| No new dependency, no `dart:io`, no Flutter or `lib/` import | `make backend-analyze` (gate) and `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| A sample file built from the function opens correctly in Excel (Windows and Mac, Vietnamese regional settings): columns split, diacritics intact, numbers sum, no stray `sep=` row | owner acceptance in the real environment - "unverified" until done. The executor writes a sample into the scratchpad or prints the bytes' text for the owner to save; agents cannot run Excel. |

## Environment limits

Agents cannot open Excel. Excel's handling of `sep=` plus BOM and of the visible `'` prefix (in CSV it is shown as a literal apostrophe, unlike typing it in a cell) is unverified until the owner tries it.

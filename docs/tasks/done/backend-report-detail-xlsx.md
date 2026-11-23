---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: [backend-xlsx-writer, backend-report-data]
---

# Backend: the monthly detailed report workbook ("chi tiết tháng": every order, day by day)

Planned 2026-11-19, updated the same day. **No open decisions block this card.** Pure code, like the summary card; the route is `backend-orders-month-export-xlsx`.

## Owner request (verbatim)

"... 2. monthly detailed with every orders in each day, I'll show you the format and I want exactly the same". Reference: `sample/Chi tiet 1 thang.xlsx` (layout extracted by the planner; the sample's rows 1-120 shown, the rest repeats the same pattern to row 895). **Reference only**: never read it at runtime or in tests, never commit it (it is git-ignored), never copy its content into code, tests or docs.

## Typo fixes (owner decision 2)

`Chi tiết` (sample: tiêt), `Tiền mặt` (sample: măt). **Every date is `DD/MM/YYYY`** with zero padding, also in `Cộng ngày` (the sample mixes `01/6/2026`, `1/6/2026`, `3/6`). Otherwise the same.

## Decided (owner, 2026-11-19, "OK")

- **RPT2:** days with no delivered order are **skipped** (no header, no `Cộng ngày` row).
- **RPT7:** long descriptions **wrap** in column B (Excel makes the row taller by itself). This is the one deliberate difference from the sample.
- **RPT8, as the working spec:** thin borders on all four edges of every table cell, rows 2 to the last row, columns A-D. The owner compares the borders against his sample in acceptance and reports differences. The executor may open `sample/` **read-only to check border edges only**, copying no values.
- **RPT3:** an order's day is its `placedAt` date as written (see `backend-report-data`).
- Empty money cells show 0: the `Cộng ngày` cells show `0` when a column has nothing. (The cash and transfer cells of an order row that belongs to the other method stay empty, as in the sample.)
- The sample has **no month total row** at the end; none is added.
- **PAY6, decided:** an order with no payment method counts as cash (column C).

## Sources

`backend/lib/xlsx_writer.dart`, `backend/test/xlsx_test_reader.dart`, `backend/lib/orders_report.dart` (`deliveredOrders`, `describeOrder`, `dailyTotals`, `daysWithOrders`).

## Goal

`backend/lib/report_detail.dart`: `List<int> buildDetailReport({required String month, required List<DayTotals> days})`, where `days` is what `daysWithOrders` returns (the function draws every day in the list it is given).

One sheet, named `Sheet1`. All text Calibri 18; amounts `#,##0`; column default styles Calibri 18 (C and D with the amount format). Columns: A width 26.109375, B 39.77734375, C 31.5546875, D 28.6640625; from E onward 8.88671875.

- Row 1 (height 24): A1 = `Chi tiết tháng M/YYYY` (M without a leading zero, e.g. `Chi tiết tháng 6/2026`), bold. (No shop information in this report.)
- Header, rows 2 and 3: A2 = `Ngày tháng năm` bold, centred horizontally and vertically, wrap text; merged `A2:A3`. B2 = `Giao dịch`, same style; merged `B2:B3`. C2 = `Số tiền`, bold, centred; merged `C2:D2`. Row 3: C3 = `Tiền mặt`, D3 = `Chuyển khoản`, bold, centred (**cash first here**, the reverse of the summary's `tách` sheet).
- Row 4: empty, with the table's borders in A:D (the sample has this empty row between the header and the first day).
- Then, for each day in date order, with `s` = the first row of the block:
  1. Row `s`: A = `Ngày DD/MM/YYYY`, bold; B, C, D empty with the table style.
  2. Rows `s+1` to `e`: one per order of that day, oldest first: B = the order's description (`describeOrder`), **wrapped**; the amount (the order's total) in **C if cash**, in **D if bank transfer**, the other cell empty with the table style; A empty with the table style.
  3. Row `e+1`: B = `Cộng ngày DD/MM/YYYY`, bold; C = formula `SUM(C{s+1}:C{e})` and D = formula `SUM(D{s+1}:D{e})`, each with its cached value, bold, `#,##0` (`0` when a column has nothing); A empty with the table style.
  - The next day's header row follows **immediately** (no blank row). No total after the last day.
- Example: first day header at row 5; with 35 orders on it, orders in rows 6-40, `Cộng ngày` in row 41 with `SUM(C6:C40)` and `SUM(D6:D40)`, next day header in row 42.
- A month with no delivered orders gives the header rows (1-4) only.
- A long order list stays valid up to the sheet limit; an order total that isn't a whole number is written as it is.
- Rows are not given custom heights (so Excel can grow a wrapped row); row 1 has height 24.

## Non-goals

The route and permissions, the summary report, customer names (not in this report), month totals, per-item rows, a template file, reading the sample.

## Tests written with the change

`backend/test/report_detail_test.dart`, synthetic orders, read back with the writer card's test reader:
- sheet name, column widths, row 1 height, the three header merges, header texts and styles exactly as above; month title `Chi tiết tháng 11/2026` (no zero) and `Chi tiết tháng 6/2026`.
- two days, 3 and 2 orders (cash, transfer, one with toppings and quantity 2): rows, day headers `Ngày 01/06/2026`, descriptions (`2 Xôi thịt (Thêm chả), Trà đá`), amounts in C for cash and D for transfer, `Cộng ngày 01/06/2026` formulas covering exactly the rows between its header and itself, cached values right, the next header right after the sum row.
- a day with orders only on 1 June and 3 June has **no block for 2 June**.
- a day whose only orders are cash has `0` in D's sum; the sum rows are bold with the number format.
- borders (thin, all edges on the table cells) and fonts (Calibri 18, bold on day header and sum row); wrap on column B description cells.
- an empty month gives rows 1-4 only; no sample typo (`tiêt`, `măt`) appears; a description with `=1+1` is a string cell; `&`, `<` and Vietnamese letters intact; an order with no stored method lands in C.
- no file access in the module.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Layout, formulas, merges, widths, styles, typo fixes as listed | `make backend-test` (gate) |
| Backend clean; no new dependency beyond the writer card's | `make backend-analyze` (gate) |
| No sample data in code or tests | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| Open a real month's file next to `sample/Chi tiet 1 thang.xlsx` in Excel: it looks the same (widths, merges, bold rows, thousands separators), long descriptions wrap, each day's `Cộng ngày` matches the orders, no repair prompt; the owner reports any border difference | owner acceptance - "unverified" until done |

## Environment limits

Agents can't open Excel to compare looks.

## Note from `docs/reviews/security-backend-xlsx-writer.md` (P2)

Every `XlsxCell.formula` string must be built only from cell references (e.g. `SUM(C9:C39)`), never from order text. The reviewers of this card check it.

## Note from `docs/reviews/execute-backend-xlsx-writer.md` (P2)

Rows that only exist for spacing (e.g. row 4) get an empty Calibri 18 cell in column A, so they keep the sample height (the writer does not write rows with no cells).

## Carried in from `docs/reviews/execute-backend-report-data.md`

Same note as `backend-report-summary-xlsx`: wrap calls into `orders_report.dart` in the same malformed-row handling the CSV export route uses (`backend/lib/orders_api.dart:246-258`).

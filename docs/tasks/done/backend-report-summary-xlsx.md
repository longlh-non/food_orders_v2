---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: [backend-xlsx-writer, backend-report-data, backend-shop-settings]
---

# Backend: the monthly summary report workbook ("báo cáo tổng hợp": sheets `gộp` and `tách`)

Planned 2026-11-19, updated the same day. **No open decisions block this card.** Pure code: builds the workbook bytes from synthetic or real data; the route is `backend-orders-month-export-xlsx`.

## Owner request (verbatim)

"update 2 format for export: 1. whole month with everyday income shows on each line with the sum of all orders on that day ... I'll show you the format and I want exactly the same". Reference: `sample/bao cao TONG HOP T3-2026.xlsx` (read by the planner; the layout below was extracted from it). The sample is **reference only**: never read it at runtime or in tests, never commit it (it is git-ignored), never copy its figures, tax code, address or name into code, tests or docs.

## Typo fixes (owner decision 2)

`HỘ KINH DOANH` (sample: KIMH), `SỔ CHI TIẾT DOANH THU BÁN HÀNG HÓA, DỊCH VỤ` (sample: SỎ CHI TIÊT), `Tiền mặt`, `Tổng cộng`. **Every date is `DD/MM/YYYY`** with zero padding (`Ngày 08/03/2026`; the sample has `08/3/2026` in places). Everything else as the sample.

## Decided (owner, 2026-11-19)

- **RPT6, decided:** "Use "Tổng " + "The month in Vietnamese" for this". The month-total label on sheet `tách` is `Tổng tháng M`, with M written without a leading zero, the same way as `Kỳ báo cáo: Tháng 3 năm 2026` (e.g. `Tổng tháng 3`, `Tổng tháng 11`). Sheet `gộp` keeps `Tổng cộng`, because the owner only asked to change the `tách` label; **review note for the owner:** if he meant both sheets, say so and the `gộp` label becomes `Tổng tháng M` as well (one constant).
- **RPT1, decided ("OK"):** every calendar day is listed; a day with no delivered order shows 0 and the standard description.
- **Empty money cells show 0 ("OK"):** a day with no sales has `0` in `C` and `D` of `tách` (the sample leaves them empty; the sums are the same).
- **`C9` centred ("OK"):** the "Chuyển khoản" heading is centred like `D9` and `E9` (the sample leaves it unaligned).
- **RPT8, decided as the working spec ("OK"):** thin borders on all four edges of every table cell (header rows, one row per day, total row), none on the title block above and the signature block below, except the bottom edge under row 7's period line and the top edge of the footer date cell as the sample shows them. The owner compares the borders against his sample in acceptance and reports differences. The executor may open `sample/` **read-only to check border edges only**, copying no values.
- **RPT9, decided ("OK" to the recommendation):** `SHOP_NAME` holds the **whole first line** (e.g. `HỘ KINH DOANH <tên quán>`); the code adds **no prefix**. The typo fix lives in the owner's setting, not in the code.
- **RPT3, decided:** the day of an order is its `placedAt` date as written (see `backend-report-data`).
- **PAY6, decided:** an order with no payment method counts as cash.

## Sources

`backend/lib/xlsx_writer.dart` and `backend/test/xlsx_test_reader.dart` (writer card), `backend/lib/orders_report.dart` (`dailyTotals`, `daysInMonth`), `backend/lib/shop_settings.dart` (`SHOP_*`), this card's layout.

## Goal

`backend/lib/report_summary.dart`: `List<int> buildSummaryReport({required ShopSettings shop, required String month, required List<DayTotals> days})`. `D` below is the number of days in the month (28 to 31). All text is Calibri 18 unless said; numbers use the built-in format `#,##0` (id 3); every column's default style is Calibri 18; columns from the first unused one onward have width 8.88671875.

### Sheet 1, named `gộp` (every day: one amount = cash + transfer)

- Columns: A width 28.33203125, B 79.5546875, C 54.
- Row 1: A1 = `SHOP_NAME` exactly as set, bold. Row 2: A2 = `Mã số thuế: ` + `SHOP_TAX_CODE`. Row 3: A3 = `Địa chỉ: ` + `SHOP_ADDRESS`. Row 4 empty.
- Row 5: A5 = `SỔ CHI TIẾT DOANH THU BÁN HÀNG HÓA, DỊCH VỤ`, bold, centred; merged `A5:B5`.
- Row 6: A6 = `Địa điểm kinh doanh: ` + `SHOP_LOCATION` (one space after the colon), centred; merged `A6:B6`.
- Row 7 (height 24): A7 = `Kỳ báo cáo: Tháng M năm YYYY` (M without a leading zero), centred; merged `A7:B7`.
- Row 8 (header): A8 = `Ngày, tháng, năm` bold, wrap text; B8 = `Giao dịch` bold, centred; C8 = `Số tiền` bold, centred.
- Rows `9` to `8 + D`, one per calendar day, in date order: A = `Ngày DD/MM/YYYY`; B = `Bán hàng cho khách không biết tên, không lấy hóa đơn` (one constant); C = that day's total (cash + transfer), `#,##0`. A number, not text.
- Row `9 + D` (height 25.8): B = `Tổng cộng`, bold, **size 20**, centred; C = formula `SUM(C9:C{8+D})` with its cached value, bold, size 20, `#,##0`; A is empty with the table style.
- Row `10 + D`: C = `Ngày {D} tháng M năm YYYY` (the month's **last day**, not today), italic, centred; merged `C{10+D}:E{10+D}`.
- Row `11 + D` (height 25.8, custom height): C = `NGƯỜI ĐẠI DIỆN HỘ KINH DOANH`, centred; merged `C{11+D}:E{11+D}`.
- Rows `12 + D` to `15 + D`: empty (room to sign).
- Row `16 + D`: C = `SHOP_REPRESENTATIVE`, bold, **Times New Roman 16**, centred; merged `C{16+D}:E{16+D}`.
- Example for D = 31: header row 8, days rows 9-39, total row 40 `=SUM(C9:C39)`, date row 41, representative title row 42, name row 47.

### Sheet 2, named `tách` (cash and transfer apart)

- Columns: A 28.33203125, B 79.5546875, C, D and E each 21.88671875.
- Rows 1-7 exactly as in sheet 1, except the title merges are `A5:C5`, `A6:C6`, `A7:C7`.
- Row 8: A8 = `Ngày, tháng, năm` bold, wrap text; B8 = `Nội dung` bold, centred; C8 = `Số tiền` bold, centred; merged `C8:E8`.
- Row 9 (height 24): C9 = `Chuyển khoản`, D9 = `Tiền mặt`, E9 = `Cộng`, all bold, centred (`A9`, `B9` empty with the table style). **Transfer comes first here**, cash second.
- Rows `10` to `9 + D`: A = `Ngày DD/MM/YYYY`; B = the same constant description; C = that day's **transfer** total; D = that day's **cash** total (both `0` on an empty day); E = formula `D{r}+C{r}` with its cached value. C, D, E are `#,##0`.
- Row `10 + D` (height 25.8): **A = `Tổng tháng M`** (RPT6; M without a leading zero, e.g. `Tổng tháng 3`), bold, size 20; C = `SUM(C10:C{9+D})`, D = `SUM(D10:D{9+D})`, E = `SUM(E10:E{9+D})`, each with cached value, bold, size 20, `#,##0`.
- Row `11 + D`: C = `Ngày {D} tháng M năm YYYY`, italic, centred, merged `C:E`. Row `12 + D` (height 25.8, custom): `NGƯỜI ĐẠI DIỆN HỘ KINH DOANH`, centred, merged `C:E`. Rows `13 + D` to `16 + D` empty. Row `17 + D`: `SHOP_REPRESENTATIVE`, bold, Times New Roman 16, centred, merged `C:E`.
- Example for D = 31: header rows 8-9, days rows 10-40, total row 41, date row 42, title row 43, name row 48.

### Rules

- Which orders and which column: only what `dailyTotals` returns (delivered orders; `bank_transfer` in `Chuyển khoản`, `cash` and old orders without a method in `Tiền mặt`).
- The workbook contains no customer names, order ids or item names.
- Cached values of every formula equal what Excel computes.

## Non-goals

The route and permissions, the detailed report, other months' comparisons, charts, printing setup, a template file, reading the sample.

## Tests written with the change

`backend/test/report_summary_test.dart`, synthetic data and fake shop settings (obviously fake tax code, address, name), read back with the writer card's test reader:
- sheet names are exactly `gộp` and `tách`, in that order.
- for D = 28, 29, 30 and 31 (2027-02, 2028-02, 2026-04, 2026-03): every row, merge, column width, row height and formula from the layout lands where the formulas above say; the total formula ranges cover exactly the day rows; cached values equal the sums.
- header text: the fixed title, `Kỳ báo cáo: Tháng 3 năm 2026`, `Ngày 31 tháng 3 năm 2026`, `NGƯỜI ĐẠI DIỆN HỘ KINH DOANH`, `Ngày 08/03/2026` (zero-padded dates everywhere); A1 equals the configured shop name exactly (no prefix added); none of the sample's typos appear anywhere in the file.
- total labels: `gộp` has `Tổng cộng`; `tách` A-total is exactly `Tổng tháng 3` for March and `Tổng tháng 11` for November (no leading zero, no `Tổng cộng t3`).
- styles: Calibri 18 default; bold/italic/size 20/Times New Roman 16 on the listed cells; `#,##0` on amounts and totals; centred cells (including `C9`); wrap on A8; thin borders on the table cells per RPT8.
- amounts: three orders on one day (2 cash, 1 transfer) give the right C, D, E; an empty day shows `0` in C, D and E and the standard description; sheet `gộp` C equals `tách` E for every day; an order with no stored method is counted in cash.
- shop text with `&`, `<` and Vietnamese letters is escaped and intact.
- the workbook never reads `sample/` (no file access in the module).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Layout, formulas, merges, widths, heights, styles, labels, typo fixes as listed | `make backend-test` (gate) |
| Backend clean; no new dependency beyond the writer card's | `make backend-analyze` (gate) |
| No sample data or real shop data in code or tests; no customer data in the file | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| Open the generated file for a real month next to `sample/bao cao TONG HOP T3-2026.xlsx` in Excel: it looks the same (fonts, widths, merges, borders, numbers with thousands separators), the `tách` total reads `Tổng tháng 3`, sums are right, no repair prompt; the owner reports any border difference | owner acceptance - "unverified" until done |

## Environment limits

Agents can't open Excel to compare looks; border edges and row heights are the likeliest differences, so the owner's visual check matters.

## Note from `docs/reviews/security-backend-xlsx-writer.md` (P2)

Every `XlsxCell.formula` string must be built only from cell references (e.g. `SUM(C9:C39)`), never from order text. The reviewers of this card check it.

## Follow-ups carried in from `docs/reviews/execute-backend-xlsx-writer.md` (P2)

- Add one writer test that parses the raw parts and checks that:
  - the `count` attributes equal the number of children (fonts, fills, borders, cellXfs, sst `count`/`uniqueCount`);
  - `fills` has exactly 2 entries;
  - the worksheet children come in the order `sheetFormatPr, cols, sheetData, mergeCells`.
- In `xlsx_writer.dart`:
  - reject sheet names with XML-invalid characters;
  - escape a literal `_x` in text as `_x005F_x` (and decode it in the test reader);
  - write the U+FFFE test literal as `￾`.
- Rows that only exist for spacing (e.g. row 4 and the footer gap rows) get an empty Calibri 18 cell in column A, so they keep the sample's height.

## Carried in from `docs/reviews/execute-backend-report-data.md`

`orders_report.dart`'s functions (`deliveredOrders`, `orderTotal`, `describeOrder`, `dailyTotals`, `daysWithOrders`) can still throw `TypeError`/`FormatException` on a corrupted stored row. Wrap the calls the same way the CSV export route already handles a malformed row (`backend/lib/orders_api.dart:246-258`), so one bad row gives a fixed 500 instead of an uncaught exception.

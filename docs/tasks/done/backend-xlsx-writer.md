---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: []
securityReview: required
---

# Backend: a small `.xlsx` writer built fresh in code (no template file)

Planned 2026-11-19, updated the same day. **No open decisions block this card.** Security review because of the new dependencies and because it turns text that customers typed (item names) into file content.

## Why

The owner wants two Excel reports that look **exactly** like his samples (cells, merges, fonts, widths, number format). The file is generated fresh in code each time (owner decision 6: no template at runtime; `sample/` is reference only). This card builds only the generic writer; the two layouts are separate cards (`backend-report-summary-xlsx`, `backend-report-detail-xlsx`).

## Git and the samples (done by the owner)

`sample/*.xlsx` is now in `.gitignore` (owner, 2026-11-19), so the samples with real revenue figures, tax code, address and name can't be committed by accident. No action left. Tests and code still never read or copy anything from `sample/`.

## Decision

- **RPT4, decided (owner, 2026-11-19):** "approve both". Approved dependencies: **`archive`** (backend `dependencies`, writes the zip) and **`xml`** (backend `dev_dependencies`, tests only, never shipped). The sheet XML is written by hand. The executor picks and pins a current stable version of each, checks the licence and the transitive dependencies (listed in the executor notes), and the security review covers the supply chain. **Any other new package still needs the owner's approval first** (e.g. an Excel-writing package such as `excel` is not approved).

## Sources

`backend/pubspec.yaml`, `backend/lib/orders_export.dart` (the CSV writer this sits beside; it stays unchanged), `docs/tasks/backend-report-summary-xlsx.md` and `docs/tasks/backend-report-detail-xlsx.md` (what the writer must express: merges, per-column widths and default styles, row heights, Calibri 18, Times New Roman 16, bold / italic, number format `#,##0`, centred and wrapped text, thin borders, formulas).

## Goal

`backend/lib/xlsx_writer.dart`, pure (no `dart:io`, no database):

- Model: `XlsxWorkbook(sheets)`, `XlsxSheet(name, columns, rows, merges)`, a cell = text, number, formula with its **cached value**, or empty-but-styled, plus a `CellStyle` (font name and size, bold, italic, `#,##0` or general format, horizontal alignment, wrap, borders: each of the four edges none or thin). Column definitions: range, width, default style. Row heights (with a flag for "custom height"). Merged ranges. Keep it as small as the two layouts need; no extra features.
- `List<int> toBytes()`: a valid `.xlsx` with `[Content_Types].xml`, `_rels/.rels`, `xl/workbook.xml` (with `fullCalcOnLoad="1"` so Excel recalculates), `xl/_rels/workbook.xml.rels`, `xl/styles.xml` (styles de-duplicated), `xl/sharedStrings.xml`, one `xl/worksheets/sheetN.xml` per sheet.
- **Formulas are written as formulas** (`<f>`), each with its cached `<v>` value, so a viewer that doesn't recalculate (a phone preview) still shows numbers.
- **Text is always a string cell**, never a formula: text starting with `=`, `+`, `-` or `@` stays text with no leading `'` (a test proves it). XML-escape `& < > " '`; **remove characters XML can't hold** (control characters except tab, newline, carriage return; unpaired surrogates) and replace newlines inside a cell by a space unless the style wraps text, because a bad character makes Excel offer to "repair" the file. Vietnamese letters stay as they are (UTF-8).
- Sheet names: 1-31 characters, none of `: \ / ? * [ ]`, unique; otherwise `ArgumentError`. Vietnamese letters allowed (`gộp`, `tách`).
- Cell and merge references are checked (a merge can't overlap another; a row index over 1,048,576 is refused).
- Deterministic output: the same input gives the same bytes (fixed zip entry order and timestamps), so tests can compare.

Also add a **test helper** `backend/test/xlsx_test_reader.dart` used by this and the two layout cards: unzips the bytes (with `archive`) and parses the XML (with `xml`), and returns, per sheet, the cells (value or formula and cached value, style summary), merges, column widths, row heights and the sheet names. Layout tests assert on that, never on the real samples.

## Non-goals

The report layouts, the route, dates, charts, images, data validation, frozen panes, print setup, reading `.xlsx` in the app, any use of the files in `sample/`, any package beyond the two approved.

## Tests written with the change

`backend/test/xlsx_writer_test.dart`:
- the bytes are a zip containing exactly the listed parts; every XML part is well-formed (parsed by the test reader); the content types and relationships point at real parts.
- a text cell, a number cell, a formula with its cached value, an empty styled cell, a merged range, a column width and default style, a row height (custom and not) all come back through the reader as written.
- styles: Calibri 18, bold, italic, Times New Roman 16, `#,##0`, centred, wrapped, thin borders on chosen edges; identical styles share one entry.
- text safety: `=1+1`, `+84`, `-5`, `@SUM(A1)` and `=HYPERLINK("http://x")` are string cells, no `<f>`; `<`, `&`, `"` come back unchanged after XML escaping; a NUL or a lone surrogate is removed and the file is still well-formed; Vietnamese text round-trips (`Xôi ruốc`, `Thêm chả`, `Trứng ngải cứu`, decomposed and precomposed forms unchanged).
- bad sheet names (empty, 32 characters, `a/b`, duplicate) and overlapping merges throw.
- same input twice gives identical bytes.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make backend-test` (gate) |
| Backend clean | `make backend-analyze` (gate) |
| Only `archive` (dependency) and `xml` (dev dependency) added, versions pinned, licences and transitive packages checked; no formula injection; XML escaping | `security-reviewer`, `code-reviewer` (reviews) |
| `make check` green | `make check` exit 0 (gate) |
| A file built by the writer opens in Excel (Windows, Mac) and Google Sheets with **no repair prompt** | owner acceptance - "unverified" until done (the layout cards give the owner a real report to open) |

## Environment limits

Agents can't open Excel. Tests must never read `sample/`; they use synthetic data only. The first `dart pub get` needs network access.

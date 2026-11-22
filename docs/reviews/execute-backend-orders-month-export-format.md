---
task: backend-orders-month-export-format
status: passed
p0: 0
p1: 0
---

# Execute review — backend-orders-month-export-format

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-12. It ran in parallel with `security-reviewer`, and neither saw the other's conclusions. Security report: `docs/reviews/security-backend-orders-month-export-format.md`.

**Path note:** the owner ran `/execute-tasks docs/tasks/back-end-orders-month-export-format.md`, which doesn't exist (pre-check 1). The executor ran the single close match, which is the card recommended just before, and told the owner. The reviewer saw no problem with that.

**Defaults applied** (open decisions, using the card's recommendations; the owner can change any of them):
- EXP2: `;` as the delimiter, plus a `sep=;` line.
- EXP5:
  - one row per order line, with toppings in their own column;
  - all statuses included, with a status column, and no total row in the file;
  - headers in Vietnamese, status values untranslated.

## Implementation notes

New `backend/lib/orders_export.dart`: pure functions, importing only `dart:convert`.
- `isValidMonth`.
- `ordersInMonth`: matches on the text prefix of `placedAt`, sorted with ties kept in input order.
- `exportRows`: one row per line. The unit price is the base price plus toppings, the line total is unit price × quantity, and every text cell is neutralised.
- `neutralise`: prefixes `'` when the first character after leading spaces is `=`, `+`, `-`, `@`, TAB or CR.
- `csvBytes`: UTF-8 byte order mark, an optional `sep=` line, CRLF line endings, quoting with `""`, and bare numbers (whole values written without decimals).
- `ExportSummary` and `summarise`: totals per status, a grand total excluding cancelled orders, and a count of non-whole lines.

## Gates

| Command | Exit |
|---|---|
| `make backend-analyze` | 0 |
| `make backend-test` | **2** first: my test's CSV reader didn't drop the `sep=;` line, which splits into `['sep=', '']` (a test bug, fixed in the reader). |
| `make backend-test` (166) | 0 |
| `make format-check`, `make boundaries`, `make analyze`, `make test` (149) | 0, 0, 0, 0 |
| `make check` (final candidate, after the follow-ups) | **0** (149 app tests, 170 backend tests) |

**Hidden-character check:** a literal U+FEFF had slipped into the test file. The analyzer doesn't flag that one; an explicit grep caught it, and it was replaced with the `﻿` escape. Neither file now contains control or invisible characters (checked by grep after the fixes too).

**Sample for the owner:** `scratchpad/export/sample-orders-2026-11.csv` was built with these functions. Its bytes start with `ef bb bf`, then `sep=;`, with CRLF throughout. Numbers are bare (`43000`, `86000`), the quote-and-semicolon name is quoted correctly, and the `=HYPERLINK(...)` name is neutralised. Summary: grand total 119.000, excluding the cancelled order.

## Findings: P0 0 · P1 0 · P2 5

- **P2-1:** the toppings were neutralised twice: per name, then on the joined text. Harmless, but redundant. **Fixed:** now done once, on the joined text.
- **P2-2:** non-whole numbers such as `9.5` are written with `.`, which Vietnamese Excel reads as text, so they won't add up. Only old USD test data has them. **Carried** to `backend-orders-month-export-cli`: warn the owner when `nonWholeLines` > 0.
- **P2-3:** the doc comment pointed to `bin/export.dart`, which doesn't exist yet. **Fixed.**
- **P2-4:** a `…Z` or offset time shows UTC in the "Giờ" column. **Accepted** as a known limit; the doc comment says so.
- **P2-5:** some test cases were missing. **Fixed** with 4 new tests: the `,` delimiter, `9.5` and negative numbers written as they are, a neutralised status, and a short `placedAt`.

**Checked with no issues found:** every function matches its card item; there's no file, database, network or Flutter import; and the number formatting is right for the values JSON can produce.

The fixes were the ones suggested, small, with no further review round. The security fix (date and time cells neutralised) is in the security report.

## Unverified (owner acceptance)

Open the sample in Excel (Windows and Mac, Vietnamese regional settings) and check:
- the columns split correctly;
- the diacritics look right;
- the Thành tiền column adds up;
- there's no stray `sep=` row;
- how the `'` prefix shows on the neutralised cells.

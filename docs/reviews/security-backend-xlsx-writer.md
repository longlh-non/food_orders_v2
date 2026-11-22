---
task: backend-xlsx-writer
status: passed
p0: 0
p1: 0
---

# Security review: backend-xlsx-writer

Date: 2026-11-19. Reviewer: `security-reviewer` (independent, read-only, first pass). It did not see the code review.

## Scope

- `backend/pubspec.yaml` and `backend/pubspec.lock`: `archive ^4.7.1` (dependency) and `xml ^7.1.0` (dev dependency), both added with `dart pub add`. They bring in `posix` 6.5.4 and `petitparser` 7.1.0. All four are MIT and hosted on pub.dev, and each has a sha256 in the lockfile.
- `backend/lib/xlsx_writer.dart`, `backend/test/xlsx_test_reader.dart` and `backend/test/xlsx_writer_test.dart` (new).

**Threat model:** the reports will put text that customers typed (their names, item names) into an Excel file that staff open.

## Gates

Run by the executor in this session on the candidate as reviewed.

| Command | Exit code | Output tail |
|---|---|---|
| `make backend-analyze` | 0 | `No issues found!` |
| `make backend-test` | 0 | `+411: All tests passed!` |
| `make format-check` | 0 | `Formatted 65 files (0 changed)` |
| `make check` | 0 | all gates green (run by the orchestrator in this session with this candidate in the tree) |

## Findings

P0: none. P1: none.

**P2 (carried to the layout cards):** `XlsxCell.formula(String, num)` (`backend/lib/xlsx_writer.dart:146`, `:600-604`) accepts any string. The string is XML-escaped, so it can't break the file. But if a layout card ever built a formula from order data, that would be formula injection. **Follow-up:** reviewers of `backend-report-summary-xlsx` and `backend-report-detail-xlsx` check that every formula is built only from cell references (e.g. `SUM(C9:C39)`), never from order text. A note has been added to both cards.

## Checked and clean (summary)

- **Formulas, DDE and links:**
  - Customer text is always a shared-string cell. It never becomes `<f>`.
  - `=HYPERLINK(...)`, `@SUM`, `+84`, `-5` and `=1+1` stay text.
  - No hyperlink elements or relationships are ever written.
- **XML escaping:** applied everywhere text lands (shared strings, sheet names, font names, merge refs). Every other attribute is numeric or fixed.
- **Invalid characters:**
  - Control characters, U+FFFE, U+FFFF and lone surrogates are removed.
  - Cutting text at 32,767 never leaves half a surrogate pair.
- **Size limits:**
  - Per-cell text, row, column, width and height limits are enforced.
  - The total size is bounded by the caller (one month of at most 10,000 orders).
- **Zip:** entry names are fixed (no user text) and timestamps are fixed. It only writes, so extracting attacks don't apply.
- **Supply chain:**
  - `lib/archive.dart` never reaches `posix`. The only imports are `package:archive/archive.dart`, so the owner's condition holds.
  - `xml` and `petitparser` are dev only.
  - No git or path sources.
  - `posix` is still downloaded as part of the dependency tree but never runs.
- **Leaks:**
  - The writer does no I/O, logging or environment reads.
  - Its errors hold only developer-supplied values.
  - The future route must turn writer errors into a fixed 500 message.

## Unverified (owner acceptance)

- Excel (Windows, Mac) and Google Sheets open a generated file with no repair prompt.
- A cell containing `=HYPERLINK("http://x")` shows as plain text in real Excel.

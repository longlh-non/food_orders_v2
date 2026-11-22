---
task: backend-xlsx-writer
status: passed
p0: 0
p1: 0
---

# Execute review: backend-xlsx-writer

Date: 2026-11-19. Reviewer: `code-reviewer` (independent, read-only, first pass). The security review is in `docs/reviews/security-backend-xlsx-writer.md` (passed). Neither reviewer saw the other's conclusions.

## Candidate

- **`backend/pubspec.yaml`, `backend/pubspec.lock`:** add `archive ^4.7.1` and, for tests only, `xml ^7.1.0` (owner-approved; `posix` comes in transitively and was accepted by the owner).
- **`backend/lib/xlsx_writer.dart` (new):**
  - the workbook model, with text, number, formula-with-cached-value and empty styled cells;
  - `CellStyle`, columns, row heights and merges;
  - `toBytes()` with de-duplicated styles and shared strings;
  - text safety, sheet-name and merge checks, and deterministic output.
- **`backend/test/xlsx_test_reader.dart`, `backend/test/xlsx_writer_test.dart` (new):** 26 tests.

## Gates

| Command | Exit code | Output tail | Run by |
|---|---|---|---|
| `make backend-analyze` | 0 | `No issues found!` | executor, this session |
| `make backend-test` | 0 | `+411: All tests passed!` | executor, this session |
| `make format-check` | 0 | `Formatted 65 files (0 changed)` | executor, this session |
| `make check` | 0 | format `0 changed`, analyze clean, `boundaries: ok`, Flutter and backend tests all passed (backend +411) | orchestrator, this session, with this exact candidate in the tree (frozen, unchanged since) |

## Findings

P0: none. P1: none.

The reviewer found the OOXML sound when read against the format rules: parts, content types, relationships, element order in the worksheet and styles, mandatory fills, count attributes, and shared-string counts. The model can express everything both layout cards need.

P2, deferred:

1. **Byte-identical output.** The output is identical on one machine, not across time zones (a field archive writes for the zip timestamp). No test compares against stored bytes, and none should. The executor's wording is accurate; accepted as is.
2. **Sheet names.** They are not checked for XML-invalid characters (lone surrogates, U+FFFE/FFFF, DEL). This can't happen today, because the layouts use fixed names. **Follow-up:** reject such names, together with item 4.
3. **Literal `_xHHHH_` in text.** Excel decodes `_xHHHH_` in shared strings, so an item name typed as `_x0007_` wouldn't show as typed. This is cosmetic, not code execution. **Follow-up:** escape `_x` as `_x005F_x`, together with item 4.
4. **Tests only check that the XML parses.** They don't check count attributes, the 2 mandatory fills, or the worksheet element order, so a change that makes Excel show a "repair" prompt could pass. **Follow-up: added to `backend-report-summary-xlsx`, the first card that uses the writer**, together with items 2, 3 and 5.
5. **An invisible U+FFFE literal at `backend/test/xlsx_writer_test.dart:281`.** Write it as `￾`.
6. **No default row style, and `sheetFormatPr` is fixed at height 15.** Layout rows with no cells may look shorter than in the samples. **Follow-up:** the layout cards give such rows an empty Calibri 18 cell in column A. A note was added to both layout cards.
7. **Smaller items:**
   - a doc comment placed after the imports;
   - the `dart:` import order;
   - no range check on `fontSize`;
   - optionally, `quotePrefix="1"` on text cells starting with `= + - @`, so Excel keeps them as text even after a user edits the cell. This needs the owner's OK; it's not visible in the cell.

## Unverified (owner acceptance)

A generated file opens in Excel (Windows, Mac) and Google Sheets with no repair prompt.

## Final gate before archiving

`make check` exit 0 (see Gates). No fix round was needed. The card was moved to `docs/tasks/done/`.

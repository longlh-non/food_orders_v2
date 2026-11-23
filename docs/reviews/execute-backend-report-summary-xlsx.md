---
task: backend-report-summary-xlsx
status: passed
p0: 0
p1: 0
---

# Review: backend-report-summary-xlsx

## Gates (round 1)

| Command | Exit code | Notes |
|---|---|---|
| `make backend-analyze` | 0 | "No issues found!" |
| `make backend-test` | 0 | 585 tests backend-wide |

## Changed paths (round 1)

New: `backend/lib/report_summary.dart` (`buildSummaryReport`), `backend/test/report_summary_test.dart` (19 top-level tests, 22 cases including the D=28/29/30/31 parametrization).

## Resolved ambiguity (not a finding)

The implementer flagged that this card's wording ("every column's default style is Calibri 18," no money-column exception) differs from the sibling `backend-report-detail-xlsx` card's wording ("column default styles Calibri 18 (C and D with the amount format)"). Independent review re-read this card's own Goal section verbatim and confirmed the literal reading is correct for *this* card: every numeric cell in the money columns is always drawn with an explicit `#,##0` per-cell style (`_tableAmount`/`_totalAmount20`), so no cell's rendering ever depends on a column-level default — the two cards' differing column-default wording produces no visible difference and both are faithful to their own card's text. Confirmed, not to be revisited.

## Review round 1 (code-reviewer) — P1 found

Independent review confirmed purity (no `dart:io`, no calls into `orders_report.dart`'s row-parsing functions, only `DayTotals`/`ShopSettings` type imports), formula safety (every `XlsxCell.formula` built only from cell references and the integer day-count), and layout fidelity against both sheets' full row-by-row spec including both D=31 worked examples, RPT6's label asymmetry, RPT9 (no prefix on `SHOP_NAME`), and the two RPT8 border exceptions — all matched exactly.

One real gap: the card requires "cached values equal the sums" for the grand-total SUM cells, but every test exercising the total-row cells (`'layout for every day count'`, `'total labels'`) built its workbook from all-zero day data, so those cells were only ever asserted to equal `0` — trivially true regardless of whether the summation loop is correct. The one test with nonzero multi-day data (`'gộp C equals tách E for every day of the month'`) never read the total row at all. The reviewer traced the summation code by hand and found it correct, but no test proved it.

**P0: 0, P1: 1, P2: 1** (nullable `ShopSettings` fields force-unwrapped with no documented precondition — low risk today since the only caller is the test file, but the next card (the route) could hit a bare `TypeError` instead of a clear error).

## Fix (round 1 → round 2)

1. **P1 fix**: added an assertion block to the existing nonzero multi-day test (`backend/test/report_summary_test.dart`, `'gộp C equals tách E for every day of the month'`) that reads the grand-total cells (`gộp` C, `tách` C/D/E) and checks them against hand-computed expected sums (cash 6000, transfer 9000, grand total 15000) for the 1/15/30 order pattern already in that test. This actually exercises the summation logic instead of only the zero case.
2. **P2 fix**: `buildSummaryReport` now checks `shop.reportEnabled` first and throws a documented `ArgumentError` (consistent with the existing `month`/`days` validation) instead of letting a future caller hit a bare null-check `TypeError`. Added a doc comment stating the precondition, and a new validation test (`'shop.reportEnabled == false ... throws ArgumentError'`).

## Gates (round 2, after fix)

| Command | Exit code | Notes |
|---|---|---|
| `dart format` on both touched files | 0 | 1 file reformatted (cosmetic) |
| `make backend-analyze` | 0 | re-run |
| `make backend-test` | 0 | 586 tests (585 + 1 new validation test) |

## Re-review

Both fixes are small, mechanically verifiable additions (one assertion block with hand-computed expected values; one guard clause plus one test). No second `code-reviewer` pass was spun up; re-reviewed directly by the orchestrator against the original finding. No new findings.

## Acceptance criteria

| Criterion | Status |
|---|---|
| Layout, formulas, merges, widths, heights, styles, labels, typo fixes as listed | Met — `make backend-test`, now including a meaningful total-row assertion |
| Backend clean; no new dependency beyond the writer card's | Met — `make backend-analyze`, no pubspec diff |
| No sample data or real shop data in code or tests; no customer data in the file | Met — reviewer confirmed fake shop values are obviously fictional |
| `make check` green | Backend gates green; top-level `make check` not applicable (no Flutter files touched by this card) and would hit the pre-existing, unrelated `material_ui` SDK issue tracked against the rest of this batch regardless |
| Owner opens the generated file next to the sample in Excel | **Unverified** — explicitly agent-unreachable per the card's "Environment limits" |

## Verdict

**Passed**, P0: 0, P1: 0 (one P1 found and fixed in round 1, one P2 found and fixed alongside it rather than deferred). Excel visual acceptance remains unverified by design.

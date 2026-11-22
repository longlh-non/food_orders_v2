---
task: backend-report-data
status: passed
p0: 0
p1: 0
---

# Execute review: backend-report-data

Date: 2026-11-20. Reviewer: `code-reviewer` (independent, read-only, first pass). No security review: the card has no `securityReview` field and the diff is pure functions with no database, route, JSON parsing from a request, dependency or network exposure.

## Candidate

Two new files, no existing file changed:

- `backend/lib/orders_report.dart`: `deliveredOrders`, `orderTotal`, `describeOrder`, `daysInMonth`, `dailyTotals`, `daysWithOrders`, `nonWholeOrders`, the `ReportOrder` and `DayTotals` carriers. Reuses `isValidMonth` and `ordersInMonth` from `orders_export.dart` (imported, not copied); `orders_export.dart` itself is untouched.
- `backend/test/orders_report_test.dart` (28 tests, after the fix round below).

## Gates

| Command | Exit code | Output tail | Run by |
|---|---|---|---|
| `dart analyze --fatal-infos` (backend/) | 0 | `No issues found!` | orchestrator (first round) |
| `dart test test/orders_report_test.dart` (backend/) | 0 | 24 tests passed (first round); 28 after the fix round | orchestrator |
| `make check` | 0 | `0 changed`, `boundaries: ok`, analyze clean, Flutter `+537` (unchanged by this card), backend `+551` (was 523, +28) | orchestrator, this session, final candidate |

## Findings

P0: none. P1: none.

The reviewer confirmed:
- `deliveredOrders` filters to `status == 'delivered'` after `ordersInMonth`'s month filter and ordering (RPT3, no time-zone conversion), and `method` defaults to `'cash'` for anything other than exactly `'bank_transfer'` (PAY6, and matches `_orderFromRow`'s real output shape, which is always a non-null string).
- `orderTotal`/`describeOrder` match the card's rules exactly, including the duplicate-topping and no-`id`/`toppings` cases, and never round money.
- `daysInMonth`'s `DateTime(year, month+1, 0)` trick is correct, including December rolling into next year.
- `dailyTotals` shows every calendar day (RPT1); `daysWithOrders` drops only empty days, in date order (RPT2); day-grouping relies correctly on `deliveredOrders`' already-sorted output.
- `nonWholeOrders` counts correctly.
- Invariant 4 (no Flutter/`lib/` import, no `dart:io`) and invariant 6 (the two data classes are minimal, justified carriers) hold.

P2, all fixed before archiving:

1. `dailyTotals` recomputed `daysInMonth(month)` on every loop iteration. **Fixed:** hoisted to a local.
2. `deliveredOrders` substringed `placedAt` with no length guard, unlike `orders_export.dart`'s own defensive read of the same field; a hand-edited row shorter than 10 characters would throw `RangeError` instead of being handled like the export route's malformed-row path. **Fixed:** a `_day` helper keeps a short string whole instead of throwing. (The reviewer flagged this as a note for the future route cards too, since no route exists yet — carried forward below.)
3. No test exercised December (the one case needing the year-rollover in `daysInMonth`'s trick). **Fixed:** added.
4. "Missing" and "explicit null" payment method were never distinguished in tests. **Fixed:** added a case with the key literally present and `null`.
5. No test for a JSON `quantity` as a double (e.g. `2.0`). **Fixed:** added, confirming `orderTotal` stays whole and isn't spuriously flagged as non-whole.
6. The control-character regex covered C0 and DEL but not the Unicode C1 range (U+0080–U+009F), and `describeOrder` had no direct test for a duplicate topping in the *description* (only `orderTotal` had one). **Fixed:** the regex now also covers C1, with a test; and a duplicate-topping description test was added.

These are all small, test-covered tightenings with no behaviour change to any case the review found working; verified by the final `make check`. No P0 or P1 was open, so the reviewer was not run again.

**Carried forward (not this card's job — no route exists yet, an explicit non-goal):** when the route cards (`backend-report-summary-xlsx`, `backend-report-detail-xlsx`, `backend-orders-month-export-xlsx`) call into `orders_report.dart`, they should wrap the calls in the same kind of `try`/`catch` the CSV export route already uses for a malformed stored row (`orders_api.dart:246-258`), since a corrupted database row can still throw `TypeError`/`FormatException` from `orderTotal`/`describeOrder`.

## Unverified

None — this card has no owner-acceptance item (pure code, no UI, no route).

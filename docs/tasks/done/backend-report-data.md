---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: [backend-order-payment-method]
---

# Backend: the numbers behind the two reports (delivered orders, per day, cash vs transfer)

Planned 2026-11-19, updated the same day. **No open decisions block this card.** Pure code: no database, no file, no route, no spreadsheet. The layouts (next cards) only draw what this returns.

## Owner decisions (2026-11-19)

- **Income counts only `delivered` orders**, in both reports (decision 5).
- **Detailed report: one row per order.** The description is built from the order's lines (quantity, item name, toppings), e.g. `2 Xôi thịt (Thêm chả), Trà đá`. The amount is the order total (decision 3).
- Payment: `bank_transfer` goes in the "Chuyển khoản" column, `cash` in "Tiền mặt" (decision 1).
- **PAY6, decided:** an order with no payment method counts as cash.
- **PAY2, decided:** the status list is `awaiting_payment, preparing, ready, delivered, cancelled`, so "delivered only" excludes all the others; no `pending` or `accepted` exists any more (stored ones are migrated by `backend-order-payment-method`).
- **RPT1, decided ("OK"):** the summary lists **every calendar day** of the month; a day with no delivered order shows 0 and the same standard description.
- **RPT2, decided ("OK"):** the detailed report **skips** days with no delivered order (no header, no "Cộng ngày" row of zeros).
- Empty money cells show 0 (owner "OK"): in the summary a day with no sales has `0` in the transfer and cash cells.
- **RPT3, decided (owner, 2026-11-19, "OK"):** an order's day is the date in `placedAt` **as written** (the customer device's local date, taken as shop time, no conversion), the same rule the CSV export uses. Known limits, also kept in `CLAUDE.md` "Known limitations": a phone with a wrong clock files its order in the wrong day or month; an order placed at 23:58 and delivered after midnight counts on the day it was placed. A server-side timestamp would be a later contract change.

## Sources

`backend/lib/orders_export.dart` (`isValidMonth`, `ordersInMonth`, the unit-price rule `base + sum of toppings`), `backend/lib/orders_api.dart` (`_orderFromRow`), `CLAUDE.md` -> "Backend" (Order rules, prices are VND whole numbers).

## Goal

`backend/lib/orders_report.dart` (pure functions; reuse `ordersInMonth` and the month rule, don't copy them; do not change the CSV code):

1. `List<ReportOrder> deliveredOrders(List<Map<String, dynamic>> orders, String month)`: orders of the month (by RPT3) with status exactly `delivered`, oldest first, ties kept in input order. `ReportOrder`: `day` (`YYYY-MM-DD`), `description`, `total`, `method` (`cash` / `bank_transfer`; a missing value is `cash`).
2. `num orderTotal(Map order)`: sum over lines of `quantity x (price + sum of topping prices)`; works for old orders with no `id` or `toppings`.
3. `String describeOrder(Map order)`: lines in order, joined by `, `. A line is `name`, with the quantity first (`2 name`) **only when quantity is above 1**, and the toppings in brackets after it (`name (Thêm chả, Thêm thịt)`, the topping names as stored, a topping taken twice is written twice). Example: `2 Xôi thịt (Thêm chả), Trà đá`. Newlines and control characters in names become a single space; the text is not shortened.
4. `int daysInMonth(String month)` (leap years: 2028-02 has 29) and `List<DayTotals> dailyTotals(List<ReportOrder> orders, String month)`: one entry for **every** calendar day (the summary shows all of them; the detail layout skips the ones without orders), each with `cash`, `transfer` and `total`, and the day's orders. A helper `daysWithOrders(...)` returns only the days that have at least one order, for the detail report.
5. Money stays numbers, never rounded or formatted. Count `nonWholeOrders` (a total that isn't a whole number: old USD test orders such as `9.5`) so the endpoint card can warn the owner; the reports never rewrite money.

## Non-goals

Spreadsheet cells, styles, the route, customer names (the reports don't contain them), refunds, time-zone conversion.

## Tests written with the change

`backend/test/orders_report_test.dart` with synthetic orders:
- only `delivered`; `awaiting_payment`, `preparing`, `ready` and `cancelled` excluded; only the month's orders; month boundaries `2026-10-31T23:59:59.999` out, `2026-11-01T00:00:00.000` in, `2026-11-30T23:59:59.999` in, `2026-12-01T00:00:00.000` out.
- `orderTotal`: `2 x (25000 + 10000) + 4000`; no toppings; same topping twice counted twice; old order without `id`/`toppings`; a `9.5` price is counted as non-whole.
- `describeOrder`: the example above exactly; quantity 1 has no prefix; two toppings; a name with a newline; Vietnamese text unchanged.
- `dailyTotals`: 28, 29 (2028-02), 30 and 31 days; empty days present with 0; cash and transfer split; an order with no method counts as cash; several orders on one day sum correctly; order within a day is oldest first. `daysWithOrders` returns only non-empty days, in date order.
- Invalid month (`2026-13`) throws `ArgumentError` (callers validate first, this is a backstop).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make backend-test` (gate) |
| Backend clean; no new dependency; no `dart:io`; CSV code untouched | `make backend-analyze` (gate), `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |

---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: [qr-static-backend-schema-and-create, status-finished-backend]
securityReview: required
---

# Backend: confirm to `paid`, switch to cash, PATCH rules, no expiry and the reports for `bank_transfer_static`

Planned 2026-11-26, revised after the `status-finished-*` chain (staff-only PATCH, staff may set any status, cancelled is final, `finished` replaces `ready`/`delivered`, a cash order may go to `awaiting_payment`) and the staff-login plan. Decisions QS2, QS8, QS13 in `qr-static-api-contract`; SF6, SF13, SF16, SF17 in `status-finished-contract`. Security review is required (payment routes and PATCH rules). **Staff proof:** every staff route here already calls the one staff check; it accepts the password headers now and a staff session once `staff-login-backend` ships (that card runs after this chain's schema card and needs no edit here). Tests use the password headers; do not add session code.

## Sources

`backend/lib/orders_api.dart`: the guarded `UPDATE ... WHERE` helpers, `confirm-payment`, `staff-switch-to-cash`, `switch-to-cash`, `renew-payment`, `payment-qr`, the expiry sweep, the **staff-gated PATCH handler as `status-finished-backend` left it** and the placeholder refusal of `paid` that `qr-static-backend-schema-and-create` added; `backend/lib/orders_report.dart` (`method == 'bank_transfer'` mapping at line ~77); `report_summary.dart`, `report_detail.dart`; tests `orders_payment_*_test.dart`, `report_*_test.dart`.

## Goal

For an order whose method is `bank_transfer_static`:

- `confirm-payment` (staff): `awaiting_payment` -> **`paid`**, method stays, `paymentDueAt` stays null. No deadline check. Other states 409. (The old `bank_transfer` `confirm-payment` still sets `preparing`.)
- `staff-switch-to-cash` and the customer `switch-to-cash`: `awaiting_payment` -> cash `preparing`. From `paid` or any other state: 409.
- `renew-payment` and `GET /orders/{id}/payment-qr`: **409** (fixed message).
- **PATCH** (staff-gated; a cancelled order can't be changed, already done by the earlier card):
  - `paid` becomes a legal target for **both** transfer methods (`bank_transfer_static` and the old `bank_transfer`; owner confirmed), from any non-cancelled status; `cash` -> `paid` stays 409 "That status doesn't fit this payment method" (SF16 open item, recommended as written). Replace the placeholder refusal.
  - `awaiting_payment` becomes a legal target for `bank_transfer_static` as well (from any non-cancelled status; `paymentDueAt` stays null). `cash` -> `awaiting_payment` is already legal (owner, `status-finished-backend`) and the old `bank_transfer` keeps its 409 "Use the payment routes".
  - an `awaiting_payment` transfer order (either method) can go to `paid`, `preparing`, `finished`, `cancelled` (owner).
  - the method is never changed. Match the method explicitly (list the two transfer methods, not "anything not cash").
- Sweep and lazy check: never touch it (no `payment_due_at`); prove it with a test.
- Each transition route is still one `UPDATE ... WHERE` on the expected status **and method**, 409 when no row matched, and publishes the order on the stream.
- Reports: a **`finished`** static order counts as transfer ("Chuyển khoản") in both Excel reports (`orders_report.dart` maps the new method). Cash and legacy NULL = cash unchanged.

Do not weaken any `bank_transfer` rule beyond what is listed.

## Non-goals

Schema, `/payment-info`, Flutter code, the CSV, session code, the audit log (it hooks into these routes later, `order-status-audit-log`).

## Tests written with the change

- confirm: static awaiting -> 200 `paid`, method kept, `paymentDueAt` null; staff gate 401/403/429 first; cash order, already `paid`, `preparing`, cancelled -> 409; two racing confirms -> exactly one 200; old `bank_transfer` confirm still gives `preparing`.
- both switch-to-cash routes: from `awaiting_payment` 200 cash `preparing`, `paymentDueAt` null; second call 409; from `paid` 409.
- renew and `payment-qr` on a static order -> 409, body a fixed string.
- PATCH (with staff headers): static `awaiting_payment` -> `paid`, `preparing`, `finished`, `cancelled` all 200; `paid` -> `finished` 200; `finished` -> `awaiting_payment` 200 and deadline null; **cancelled static -> any other status 409 "Use the payment routes"**; old `bank_transfer` awaiting -> `paid` 200; cash -> `paid` 409; **cash -> `awaiting_payment` still 200 (unchanged)**; old `bank_transfer` -> `awaiting_payment` 409 "Use the payment routes"; PATCH without proof 401.
- an old static order left longer than 5 minutes (fake clock as the existing tests use) is still `awaiting_payment` after the sweep ran and after a payment-route call on another order.
- reports: a `finished` static order lands in the transfer column of the summary (`tách`) and the detail report; a `paid` one counts nowhere; totals add up; `bank_transfer` and cash cases unchanged.
- the stream carries the updated order for each route.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make backend-test` (gate) |
| Gates | `make backend-analyze`, `make format-check` exit 0 |
| No existing payment rule loosened beyond SF16 and the owner's answers | `code-reviewer`, `security-reviewer` (reviews) |
| Excel shows the static order under Chuyển khoản | owner acceptance in Excel, "unverified" until done |

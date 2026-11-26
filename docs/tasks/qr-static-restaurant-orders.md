---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [qr-static-shared-model-client, qr-static-backend-transitions, status-finished-restaurant]
---

# Restaurant: how staff see and confirm a QR-without-amount order

Planned 2026-11-26, revised after the `status-finished-*` chain and the staff-login plan. **This card adds no cancel button, no status picker, no check-payment dialog and no login or credential code**: `status-finished-restaurant` built the first three and `staff-login-restaurant` the staff-action helper (session header, 401 returns to the login screen); this card only feeds them the new method and `paid`. Decisions QS2, QS8, QS9, QS13 in `qr-static-api-contract`; SF5, SF14, SF16, SF18 in `status-finished-contract`.

## Sources

`lib/restaurant/pages/orders_page.dart` (card, payment buttons, the cancel button, the picker with `allowedTargets(order)` and the reusable check-payment dialog from the earlier card, the staff-action helper from `staff-login-restaurant`, the transfer content line from the local `transferReference`, the chime and snackbar logic, the badge, the expired logic), `lib/shared/localized_labels.dart`, `test/orders_page_test.dart`, `docs/tasks/done/restaurant-confirm-bank-transfer.md`.

## Goal

For a `bank_transfer_static` order:

- The card shows the method label ("Chuyển khoản"; it reads the same as an old `bank_transfer` order, which the card tells apart only by having no deadline and no `DH` line), the existing "Chưa thanh toán" chip while `awaiting_payment`, and the amount staff should look for in the bank app. No `DH...` line: the customer was told to type the order's items (QS3, QS11), which the card already lists.
- Fast-path choices for an `awaiting_payment` static order, in this order: **"Đã nhận chuyển khoản"** (`confirm-payment`, becomes `paid`; it first opens the existing check-payment dialog, "Vui lòng kiểm tra nếu đơn hàng đã được thanh toán", SF18, then sends through the existing staff-action helper), **"Chuyển sang tiền mặt"** (`staff-switch-to-cash`, same helper), then the existing cancel button. The dedicated "Đã giao" button is **gone** (QS2).
- A **`paid`** order shows a paid chip (`statusPaid`) and the normal main button: "Đánh dấu đã phục vụ" (with its check-payment dialog). The badge counts `awaiting_payment` + `preparing` + `paid`; the chime rule (once, on arrival) is unchanged and does not ring again on `paid`.
- **The picker** (`allowedTargets`) is widened (SF16): `paid` is offered for both transfer methods (`bank_transfer_static` and the old `bank_transfer`) and never for cash; `awaiting_payment` is offered for `bank_transfer_static` (from a non-cancelled status) in addition to `cash` (already offered by the earlier card), never for the old `bank_transfer`. An `awaiting_payment` static order can go to `paid`, `preparing`, `finished`, `cancelled`. A cancelled order has no picker. Confirmations stay as built: **only** `paid`, `finished`, `cancelled` ask; `preparing` and `awaiting_payment` picks send at once. One test per method keeps the list equal to the backend rule.
- It is **never** treated as expired: the "Hết hạn thanh toán" state and the expiry-based badge drop apply only when `paymentDueAt` is set. A static order with no deadline stays in the badge until staff act.
- Chime and snackbar: rings once on arrival as `awaiting_payment` (QS9), with the same " — chờ chuyển khoản" suffix; no second ring when paid. A null deadline counts as "still valid", not as an error.
- A cancelled static order shows plain "Đã hủy" with no buttons and no picker.

## Non-goals

A second cancel, picker, dialog or login path, the printable shop QR page, anything customer-side, the backend.

## Tests written with the change

- card for an awaiting static order: label, chip, amount, "Đã nhận chuyển khoản", "Chuyển sang tiền mặt", then the existing cancel button, no `DH` line, no expired state, no "Đã giao" button; the badge counts it.
- tapping "Đã nhận chuyển khoản" shows the check-payment sentence; No sends nothing; Yes calls `confirm-payment` with the session header and the card becomes `paid`; a 401 ends the session as for every staff action (no credential dialog); a `paid` card shows the paid chip and "Đánh dấu đã phục vụ", and counts in the badge.
- exactly one cancel button on a static card, and none on a cancelled one.
- picker: for static it includes `paid`, `preparing`, `finished`, `cancelled` while awaiting; for the old transfer `paid` too but not `awaiting_payment`; for cash `awaiting_payment` but not `paid`; a cancelled card has no picker; picking `preparing` sends with no dialog.
- tapping confirm / switch calls the right repository method (fake client) and the card moves on after the live update.
- chime fires once on arrival of a new static `awaiting_payment` order and not again when it becomes `paid`; orders already on screen at open don't ring.
- no crash with `paymentDueAt` null in the expiry code paths; the existing `bank_transfer` expired-card test still passes.
- no overflow at 360 px and text scale 2.0 on the card.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Gates, no import across apps | `make analyze`, `make format-check`, `make boundaries` (gates) |
| Existing transfer card behaviour unchanged; one cancel path, one picker, one dialog, one staff-action helper | existing tests green; `code-reviewer` (review) |
| Staff understand the card and the buttons in the real shop; the chime sounds | owner acceptance, "unverified" until done |

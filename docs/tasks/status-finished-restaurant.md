---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [status-finished-shared, status-finished-backend, staff-login-restaurant]
securityReview: required
---

# Restaurant: "Đã phục vụ" button, cancel on most orders, a "Đổi trạng thái" picker and the check-payment dialog

Planned 2026-11-26, revised for staff-set status, "cancelled is final", the owner's check-payment text, the three-target confirmation rule, cash `awaiting_payment`, and the **staff session** (no more per-action password prompts). Decisions SF2, SF5, SF6, SF12 to SF19 in `status-finished-contract`. **This card builds the one cancel button, the one picker and the one check-payment dialog**; `qr-static-restaurant-orders` adds none of them. Security review is required: every status tap sends the staff session.

## Sources

`lib/restaurant/pages/orders_page.dart` (`_OrderCard`, `_nextStatus` and `_actionLabel` lines ~460-472, the status-change helper `_changeStatus` around line 242, the payment-action helper as `staff-login-restaurant` left it, the badge, chime and snackbar rules, doc comments at 78-88 and 418-430), the session holder and helper from `staff-login-client` / `staff-login-restaurant` (`lib/restaurant/state/`), `lib/shared/api/order_repository.dart`, `test/orders_page_test.dart`, `test/order_calls_test.dart`, `test/restaurant_l10n_test.dart`, `docs/tasks/done/restaurant-orders-status-update-shows-failure.md`, `docs/tasks/done/restaurant-confirm-bank-transfer.md`.

## Goal

- **Authentication (owner: the session):** the main button, the cancel button and the picker send the PATCH through the **one staff-action helper that `staff-login-restaurant` built**: it adds the session header, and on 401 ends the session (the login screen appears). **This card adds no password prompt and no credential handling.** 403 and 429 show the existing texts. The tapped action is **not** replayed after a new login: staff tap again.
- Main button: `preparing` -> `finished`, "Đánh dấu đã phục vụ". No "ready" button. A `finished` card has no main button.
- **Check-payment dialog (SF18, owner's exact text `orderCheckPaidNote`):** every path that ends in `paid` or `finished` first shows **one** Yes / No dialog containing that sentence (plus, as a second draft line for `finished`, `orderChangeStatusFinishedNote`): the main button (**cash orders too**, owner: yes), the picker, and (when it ships) "Đã nhận chuyển khoản". Only Yes sends. Write it as one reusable function so `qr-static-restaurant-orders` only calls it.
- **Cancel button** (SF5) on every card whose status is not `cancelled` and not `finished`: `orderCancelConfirm`, plus `orderCancelPaidNote` for a transfer order past `awaiting_payment`, plus `orderCancelFinalNote`; only Yes sends `cancelled`. Last in the button row, below the payment buttons.
- **"Đổi trạng thái" picker** (SF14) on every card **except `cancelled`** (final): a dialog or menu listing every status except the current one that the backend accepts for this order (one pure function `allowedTargets(order)` next to the card, with a test; the backend stays the judge). For this card's scope: `awaiting_payment` is offered for **`cash`** (owner) and never for the old `bank_transfer`; an `awaiting_payment` order can go to `preparing`, `finished`, `cancelled`; any non-cancelled order can go to `cancelled`; `paid` is never offered for cash. `qr-static-restaurant-orders` adds `paid` and static's `awaiting_payment`. **Confirmation only for targets `paid`, `finished`, `cancelled`** (owner): `cancelled` -> the cancel dialog (same function as the cancel button), `paid`/`finished` -> the check-payment dialog; every other pick is sent at once with no dialog. A 409 shows `orderChangeStatusNotAllowed` (or the cancelled text).
- A **cash** order in `awaiting_payment` (owner decision A in SF16, if confirmed) shows the "Chưa thanh toán" chip for staff, **no** "Đã nhận chuyển khoản" / transfer-content line (it isn't a transfer), and the picker; it counts in the badge like any `awaiting_payment` order and never shows the expired state.
- Badge, chime, snackbar and expiry rules **unchanged** (badge = `awaiting_payment` + `preparing`; `paid` later). A cancelled card has no picker and no cancel button.
- Update the doc comments that say `ready` / `delivered` or "no cancel button".

## Non-goals

The login screen, session holder and logout (`staff-login-restaurant`), the `paid` chip and static-transfer buttons (qr-static), removing old enum values or keys (cleanup card), any customer file, any backend change, showing who changed a status (`order-status-audit-log` records it; no screen yet).

## Tests written with the change

- a `preparing` card shows "Đánh dấu đã phục vụ"; tapping it (cash too) opens the check-payment dialog with the exact `vi` sentence; No sends nothing; Yes sends `finished` with the session header at once (no credential prompt); a 401 ends the session (login screen) and sends nothing further.
- no card offers "Đánh dấu sẵn sàng".
- cancel: shown on `preparing`, on `awaiting_payment` (payment buttons keep their order) and **not** on `cancelled`, an expired card or a `finished` card; No sends nothing; Yes sends `cancelled` once; a double tap sends one request; a failure shows the existing failure text; the paid note appears for a `preparing` transfer order and not for cash; the "can't be changed back" line is always there.
- picker: `allowedTargets` for cash (offers `awaiting_payment`, `preparing`, `finished`, `cancelled`, never `paid`), old transfer (live `awaiting_payment`: `preparing`, `finished`, `cancelled`; `preparing`: `finished`, `cancelled`, never `awaiting_payment`), a cash `awaiting_payment` order, an expiry-cancelled order (empty: no picker) and a `finished` order; the dialog lists exactly those with localized labels; picking `preparing` or `awaiting_payment` sends **without any dialog**; picking `paid`/`finished` shows the check-payment sentence; picking `cancelled` shows the cancel question; No sends nothing; Yes sends the right status; a 409 shows the not-allowed text.
- the badge and chime tests pass unchanged; a stream update making an order `finished` removes it from the badge.
- no overflow at 360 px and text scale 2.0 with main, both payment buttons, the picker button and the cancel button on one card, and in each dialog.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Gates, no import across apps | `make analyze`, `make format-check`, `make boundaries` (gates) |
| One helper for all status sends; the session token is never shown, logged or put in an error | `code-reviewer`, `security-reviewer` (reviews) |
| Every path to `paid` or `finished` shows the owner's sentence once; no other picker move shows a dialog except `cancelled` | the tests above; `code-reviewer` (review) |
| Staff find the picker and the confirmations clear on the real tablet, and the extra dialog is not too slow in the kitchen | owner acceptance, "unverified" until done |

## Note from `status-finished-shared` (2026-11-28)

`OrdersPage._changeStatus` sends the remembered staff credentials, or an EMPTY header map when staff haven't typed any, because the backend does not check headers on `PATCH /orders/{id}` yet. When the staff check is enforced this call gets 401/403/429 and today the page shows one generic "update failed" snackbar and never prompts. Handling 401 (re-prompt or back to the login screen, and clear the stored credentials), 403 and 429 on the status-change path belongs to the restaurant card; do not deploy the backend check before it ships. A repeated tap after a 401 counts toward the 5-in-60-seconds lock, so the restaurant card must not let status buttons loop on a 401.

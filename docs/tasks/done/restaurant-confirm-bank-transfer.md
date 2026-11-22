---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [restaurant-orders-show-payment-method, backend-order-payment-transitions]
securityReview: required
---

# Restaurant: "Đã nhận chuyển khoản" and "Chuyển sang tiền mặt" buttons (staff)

Planned 2026-11-19, updated the same day with the owner's answers. **No open decisions block this card.** Security review because it sends the staff ID and password and moves money-related state. (This card holds both staff payment buttons; the slug is kept so references stay valid.)

## Owner decisions (verbatim)

> After finishing the order: if the user transferred { order_status = preparing; payment_type = bank_transfer }.

- **PAY1, decided (owner, 2026-11-19):** staff confirm "Đã nhận chuyển khoản" in the restaurant app after checking the bank app. No bank webhook.
- **PAY5, decided:** "Hide it, a late transfer has to be handled by hand manually; If so let the staff change the payment type to CASH by hand." Staff cannot confirm a cancelled order; they can change the payment type to cash.
- **PAY13, decided:** "also after it was cancelled". The staff cash switch works on an `awaiting_payment` order and on a transfer order cancelled by the 5-minute expiry, with **no time limit** for staff.
- **PAY15, decided:** the customer may also renew an expired order's QR within 15 minutes (it becomes `awaiting_payment` again). The buttons here **follow the order's current status**, so nothing special is needed beyond the rules below.

## Sources

`lib/restaurant/pages/orders_page.dart`, `lib/restaurant/pages/export_month_dialog.dart` (staff ID and password fields and error texts), `lib/restaurant/state/staff_credentials.dart` (`StaffCredentialsHolder`, `StaffCredentials.headers`, `isSendable`), `lib/shared/api/order_repository.dart` (`confirmPayment`, `staffSwitchToCash`), `lib/shared/models/order.dart` (`expiredUnpaid`), the backend card `backend-order-payment-transitions`.

## Design (plain words)

- The buttons depend only on the order's **current** status, so they change by themselves when the live update arrives:
  - `bank_transfer` and `awaiting_payment` (a new order, **or a renewed one**): two buttons, **"Đã nhận chuyển khoản"** (confirm; the order becomes `preparing`, still a transfer) and **"Chuyển sang tiền mặt"** (cash + `preparing`).
  - **Expired** (`order.expiredUnpaid`: `cancelled`, `bank_transfer`, `paymentDueAt` set; the previous card shows "Hết hạn thanh toán"): **only "Chuyển sang tiền mặt"**, with no time limit for staff. **No "Đã nhận chuyển khoản"**: a late bank transfer is checked and refunded by hand outside the app. Tapping it brings the order back as `Tiền mặt` + `preparing`.
  - Any other order (cash, `preparing`, `ready`, `delivered`, and `cancelled` without `paymentDueAt`, i.e. cancelled on purpose): no payment button.
  - When the customer renews an expired order the card goes back to the first case; when the customer or staff switch it to cash it shows no payment button.
- Either button needs the staff ID and password. If `StaffCredentialsHolder` already has them (typed earlier this visit, e.g. for the export), use them silently. Otherwise open a small dialog asking for both (same fields and rules as the export dialog: no autofill, obscured password, plain-characters check via `isSendable`). Kept only in memory, as today.
- It calls `OrderRepository.instance.confirmPayment(id, staffHeaders: ...)` or `staffSwitchToCash(id, staffHeaders: ...)`. On success the card updates (the repository merges, and the live stream also sends it); the customer's page updates through the stream.
- Errors, short fixed texts, the dialog or snackbar stays usable: wrong ID/password (401) clears the remembered ones and asks again; locked (429) a generic "thử lại sau" (the repository's exception carries only the status code; don't change shared code in this card); disabled (403) "Chức năng đang tắt trên máy chủ"; 409 "Đơn này đã được xử lý" (and the card refreshes, since the customer may have switched or renewed it, or staff did on another device); anything else "Không thể cập nhật. Thử lại."
- If the dialog code would be copied from the export dialog, extract the small shared piece **inside `lib/restaurant/`** (e.g. a `showStaffLoginDialog`) and leave the export dialog's behaviour unchanged; `restaurant-menu-editing-page` can reuse it later. Do not add it to `lib/shared/`.

## Goal

The buttons, the credentials prompt and the error handling as above. The card's other buttons and the new-order notification are unchanged (a revived or renewed order must not chime again; that is in the previous card).

## Non-goals

Backend changes, refunds, confirming a cancelled order, automatic confirmation from the bank (a webhook is a possible later follow-up only), changing the staff-credentials rules, per-person staff accounts.

## Tests written with the change

Widget tests with a fake repository client (`MockClient` via `setApiForTest`) and the in-memory holder:
- live transfer order (`awaiting_payment`): both buttons. Expired transfer order (`cancelled` with `paymentDueAt`): only "Chuyển sang tiền mặt" and the expiry text, **also when it expired days ago** (no staff limit). Never for cash, `preparing`, `ready`, `delivered`, or a `cancelled` order without `paymentDueAt`.
- **renewal:** an expired card whose order flips to `awaiting_payment` through the repository now shows both buttons; one that flips to `preparing` (cash) shows none.
- confirm with remembered credentials: one request with exactly the headers, no dialog; the card shows `preparing` and `Chuyển khoản`. Staff switch (also on the expired one): the card shows `preparing` and `Tiền mặt`.
- without credentials: the dialog opens; Cancel sends nothing; typing both and confirming sends once and remembers them.
- 401 clears the holder and asks again; 429, 403, 409 and a network error show their texts; the staff values never appear on screen or in an exception.
- a non-plain character (accent) in the ID is refused before sending.
- fits at 360 px and text scales 1.3 and 2.0.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Format, analysis, boundaries (no shared or customer import) | `make format-check`, `make analyze`, `make boundaries` (gates) |
| Credentials only in memory, only in headers, never shown or logged; no new dependency | `security-reviewer`, `code-reviewer` (reviews) |
| `make check` green | `make check` exit 0 (gate) |
| Live: place transfer orders from the customer app; confirm one, switch one to cash, let one expire and switch it to cash, let one expire and renew it from the customer phone; the customer page and this screen show each result | owner acceptance - "unverified" until done |

## Note from `docs/reviews/security-backend-payment-qr-endpoint.md` (P2)

The transfer content `DH` + the last 6 digits of the order id can repeat between orders. Ids are client-chosen and public, and timestamps repeat their last 6 digits about every 16 minutes. Before "Đã nhận chuyển khoản", staff should match the **amount and customer name** too, not only the reference. Show the full amount, the name and the reference on the card. Optional: a small warning when two waiting orders share a reference.

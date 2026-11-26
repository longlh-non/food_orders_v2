---
executor: task-executor
scopes: [docs]
workKinds: [documentation, planning]
blockedBy: [staff-login-contract]
securityReview: required
---

# QR without amount: write the API contract and the decision record (CLAUDE.md first)

Planned 2026-11-26, revised after the `status-finished-*` chain (statuses `finished` instead of `ready`/`delivered`, staff-only PATCH, staff may set any status, cancelled is final) and after the `staff-login-*` plan (staff proof is now a **session** or the password headers). **Editing `CLAUDE.md` needs the owner's explicit approval for this task** (Safety policy). Without that approval, stop and ask. Do not start another `qr-static-*` card before this one is accepted (invariant 3: table first, then backend, then client). It runs after `staff-login-contract` (and so after `status-finished-contract`) is accepted and **never at the same time** as another card that edits `CLAUDE.md`.

## Owner request (verbatim, 2026-11-26)

> add another bank transfer feature but this one will only show the QR code not include the payment amount, customers will add the amount themself, the message for them is "Vui lòng chuyển khoản [the order payment amount] vào tài khoản dưới đây (then let them download the QR code) hoặc quét mã được dán tại quán sau đó thông báo với chủ quán. Rất chân thành cảm ơn!"

## Goal

Change the "Backend" API table and the "Payment by bank transfer" / "Shop and bank settings" text in `CLAUDE.md` so every later card has one source. Text only; no code.

## Decisions to record (planner's recommended default for each; the owner confirms or corrects before the contract is written)

- **QS1, model:** a **new payment method** `bank_transfer_static` (not a flag on `bank_transfer`). The existing flow keeps its name and every rule. Reason: the two flows differ in everything that matters (no deadline, no QR route per order, no renew). Cost: schema **step 10** (see `qr-static-backend-schema-and-create`; step 9 belongs to `status-finished-backend`, SF4; step 11 to `staff-login-backend`; step 12 to `order-status-audit-log`).
- **QS2, status and expiry (owner decided 2026-11-26, revised after SF1-SF19):** the order starts `awaiting_payment` with `paymentDueAt: null` and **no expiry, no renew**. It stays so until staff check the bank app and choose the next status. Fast-path choices on the card, in this order: (1) **paid**, "Đã nhận chuyển khoản" (`confirm-payment` sets `paid`; it first shows the owner's check-payment sentence, SF18), (2) **switch to cash** (`staff-switch-to-cash`, `preparing`), (3) **cancel** (the global cancel button of `status-finished-restaurant`; this card adds none). Through the "Đổi trạng thái" picker staff may also move it to `preparing` or `finished` (owner, SF16). The customer can switch it to cash too. The earlier dedicated "Đã giao" button is **dropped** (owner confirmed); the owner's flow is `awaiting_payment -> paid -> finished` (SF2). A **cancelled** static order can never be moved back (owner, SF6). The two staff routes here use the staff check (session or password headers, `staff-login-contract`).
- **QS13, a new order status `paid` (owner decided 2026-11-26, revised):** `paid` means the money was received and the order is in the kitchen queue: it is shown like `preparing` with a paid chip and goes `paid -> finished` with the main button "Đánh dấu đã phục vụ". It is a **new `OrderStatus` value** in the backend list (`awaiting_payment, preparing, paid, finished, cancelled`), in `lib/shared/models/order.dart` (kept in sync by hand) and in the localized labels. **No schema change for it:** `orders.status` has no CHECK constraint (the executor confirms against `database.dart`). **Who may reach it:** `confirm-payment` for a static order, and a staff PATCH. **`paid` is a legal PATCH target for both transfer methods** (`bank_transfer_static` and the old `bank_transfer`; the owner confirmed `paid` for the old one); the old flow's own confirmation route still ends in `preparing`. For `cash`, `paid` is refused (409 "That status doesn't fit this payment method") — **still an open owner item** (SF16), recommended as written. Note the owner's later rule: a **cash** order **may** go to `awaiting_payment` (staff only; `status-finished-contract` SF16); the static rules below are unchanged by it. Effects: the restaurant badge and chime count it, the customer banner tracks it, the Excel reports count **`finished` only** (so `paid` income appears once finished). **Deploy order:** backend restarted before the apps are reloaded (SF9).
- **QS14, the old transfer is blocked in the backend (owner decided 2026-11-26):** `POST /orders` with `paymentMethod: bank_transfer` answers **503 "Bank transfer is suspended"** (fixed message) via one named constant; routes for orders that already exist (confirm, switch, renew, QR) keep working. Both the cart (QS12) and the backend block it; switching the old flow back on means flipping both constants.
- **QS3, where the QR comes from, and the reference (owner decided 2026-11-26):** the **backend builds the text** (the app only draws it) and it is added to **`GET /payment-info`** as `staticQrPayload` (additive field, only when transfer is enabled). No new route. It has **no tag 54 (amount) and point of initiation `11`** (static), and **no tag 62 (no `DH+6 digits` reference)**, so it is the same code as the one posted in the shop. Instead the **customer is told to type the items of their order as the transfer content** (QS11). Staff match a payment by those items, the amount and the time in their bank app.
- **QS4, download:** render the existing `qr_flutter` painter to PNG (`QrPainter.toImageData`, white background and quiet margin) and hand the bytes to the browser as a Blob download with `package:web` (already a dependency). **No new dependency.** Web-only code behind a conditional export in `lib/customer/`; on non-web the button is hidden. iOS Safari behaviour is owner acceptance.
- **QS5, cart and label (owner decided 2026-11-26):** the new choice is labelled just **"Chuyển khoản"**. While the old transfer is suspended (QS12) the cart offers **two** choices: cash and "Chuyển khoản". Disabled with the "not enabled" subtitle when `BANK_*` aren't set.
- **QS12, the old transfer is suspended, not removed (owner decided 2026-11-26):** the cart no longer offers the old `bank_transfer`. Nothing is deleted. Orders already stored as `bank_transfer` keep working. The backend creation block is QS14.
- **QS6, printable shop QR page:** **non-goal.**
- **QS7, message layout:** one translated sentence with `{amount}` filled by `formatVnd(order.total)`, then the QR, then a "Tải mã QR" button. Owner confirms.
- **QS8, reports:** a `bank_transfer_static` order counts under **Chuyển khoản** in both Excel reports once it is `finished`. The CSV has no payment column and is unchanged.
- **QS11, the transfer content is the order's items (owner request 2026-11-26):** built **in the app from `order.items`** (the repository's order, never the cart): `quantity name` per line, toppings after the name, joined by `, `, e.g. `2 Xôi thịt (Thêm chả), 1 Trà đá`. Sub-decisions: (a) **no accents** in the copied text, via a small pure function in `lib/customer/` with a test; (b) **length cap 50 characters** (owner confirmed), cut at a whole item, ending with `...`; (c) a **"Sao chép nội dung" copy button** with Flutter's `Clipboard` that copies **only the items text**, plus selectable text; (d) not in the QR, the backend doesn't know it; (e) a convenience, not proof.
- **QS9, chime and badge:** same as other transfer orders (rings on arrival as `awaiting_payment`; counted in the badge together with `preparing` and `paid`). An unpaid static order never counts as expired.
- **QS10, wording:** the Vietnamese sentence is the owner's verbatim text. The other 9 languages are machine drafts, "unverified" (LANG5).

## Contract changes to write (CLAUDE.md)

(The status list, the staff-only PATCH, "cancelled is final" and the `finished` rename are already in `CLAUDE.md` from `status-finished-contract`, and the staff session from `staff-login-contract`; build on them, don't repeat them.)

1. `POST /orders`: `paymentMethod` may be `bank_transfer_static`; it needs status `awaiting_payment`, a total above 0 (400) and the `BANK_*` settings (503 "Bank transfer is not set up"); the server sets `paymentDueAt: null`. Update the "method and status must match" bullet and the 400 list. Also write QS14.
2. `GET /payment-info`: when `transferEnabled`, also `staticQrPayload` (string, no amount).
3. `confirm-payment` (static: sets **`paid`**), `staff-switch-to-cash` and the customer `switch-to-cash`: also accept a `bank_transfer_static` order that is `awaiting_payment`. `renew-payment` and `GET /orders/{id}/payment-qr` answer **409** for it. (A **cash** order in `awaiting_payment`, from the status-finished rule, answers 409 on all of these routes.)
4. Status list becomes `awaiting_payment, preparing, paid, finished, cancelled`, with the "kept in sync by hand" sentence. `PATCH` (staff only): `paid` is a legal target for both transfer methods and refused for cash; `awaiting_payment` is a legal target for `cash` (staff only) and `bank_transfer_static`, **not** for the old `bank_transfer`; `paymentDueAt` stays null for static; a cancelled static order can't be PATCHed on (the general rule).
5. Payment expiry text: the sweep and the lazy check only touch orders **with** a `paymentDueAt`, so a static order never expires.
6. Storage: add "Step 10 rebuilds `orders` so `payment_method` may hold `bank_transfer_static`", with the backup advice (steps 9 and 10 run together on one start; steps 11 and 12 are added by their own cards).
7. "Payment by bank transfer": a short paragraph for the second option (what the customer sees, what staff do, no expiry). Accepted risk: the static QR proves nothing; staff check the bank app.
8. Excel reports: one sentence for QS8.

Do **not** yet edit the "Languages" wording status, `docs/runbook-local.md` or deploy docs: that is `qr-static-docs`.

## Non-goals

Any code. The printable shop QR page. Customer authentication.

## Tests

None (docs). Check every row you touched against the names in `backend/lib/orders_api.dart`.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Table and text match QS1-QS14 as the owner confirmed them | owner acceptance of the decisions; `code-reviewer` (review) checks the text agrees with itself |
| No `ready` or `delivered` appears in the new text | `grep` in the review |
| No other file changed | `git diff --stat` in the review |
| `make check` green | `make check` exit 0 (gate) |

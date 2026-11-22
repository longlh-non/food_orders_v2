---
executor: task-executor
scopes: [docs]
workKinds: [documentation]
blockedBy: [backend-order-payment-transitions, backend-payment-qr-endpoint, customer-payment-qr-page, restaurant-confirm-bank-transfer, backend-orders-month-export-xlsx, restaurant-export-report-choice]
---

# Docs: payment method, bank transfer, shop settings and the two reports

Planned 2026-11-19, updated the same day with the owner's answers. **No open decisions block this card.** Edits `CLAUDE.md` (owner approval needed for this card) and `docs/runbook-local.md`. The API **table rows** were already written by each backend card (contract first); this card does the prose and checks everything agrees.

## Goal

1. **Check the API table and Order rules against the code**: `paymentMethod` and `paymentDueAt` on orders; the status list `awaiting_payment, preparing, ready, delivered, cancelled` (**`pending` and `accepted` are gone**), including the "kept in sync by hand with `OrderStatus`" sentence and the PATCH rules (a staff cancel of an awaiting order clears `paymentDueAt`; PATCH can't move a cancelled transfer order); `POST /orders/{id}/switch-to-cash`, `POST /orders/{id}/renew-payment`, `POST /orders/{id}/staff-switch-to-cash`, `POST /orders/{id}/confirm-payment`, `GET /payment-info`, `GET /orders/{id}/payment-qr`, `GET /orders/export` with `report`. Fix any drift. Search the whole file for leftover `pending` / `accepted` / "Accept" (the Notifications section, the table, examples).
2. **"Layout"** in `CLAUDE.md`: the new files (`lib/customer/api/payment_client.dart`, `lib/customer/pages/payment_page.dart`, the backend files `shop_settings`, `vietqr`, `xlsx_writer`, `orders_report`, `report_summary`, `report_detail`).
3. **A "Payment by bank transfer" section** in "Backend", plain words:
   - the flow: the customer picks the method; cash is `preparing` at once; transfer shows a QR with the exact amount, the bank details as text, and a 5-minute countdown; staff tap "Đã nhận chuyển khoản" in the restaurant app (the order becomes `preparing`, still a transfer); the server cancels an unconfirmed order at 5 minutes by its own clock (PAY1, PAY3, PAY7, PAY8: transfer content `DH` + last 6 digits of the order id);
   - **after the 5 minutes (PAY15, PAY14, PAY16):** the customer page asks whether to switch to cash. Yes = switch to cash (`preparing`); no = generate another QR (`renew-payment`: same order and amount, a fresh 5-minute deadline). Both work **only within 15 minutes after the expiry** (server clock; no count limit; each renewal restarts the window from its own new expiry); after that the server answers 409 and the customer must order again or tell the shop. Only orders cancelled by expiry are offered this; an order staff cancelled on purpose is not. The customer routes have no login, so anyone on the wifi who knows an order id can use them (the accepted risk);
   - **staff switch to cash (PAY13):** staff can switch an `awaiting_payment` order, **and an order cancelled by the expiry, at any time** (no limit), to cash. The result is method cash + `preparing`. A staff-cancelled order can't be brought back this way;
   - what "cancel the QR" means: it is hidden and no longer served, but a bank QR can't be revoked (PAY5). The QR route serves a renewed order again with the same amount and content but a new deadline;
   - the **late-transfer case**: staff **cannot** confirm a cancelled order as a bank transfer in the app (`confirm-payment` answers 409). A late transfer, a double payment, or money for a cancelled order is handled and refunded by hand, outside the app, which never moves money. A paid transfer order that staff cancel by mistake can't be moved back either (also by hand);
   - the countdown uses the phone's clock for display while the server decides;
   - settings (below); old orders read back as cash (PAY6); stored `pending` / `accepted` orders were turned into `preparing` by schema step 8 (PAY11, PAY12).
4. **"Shop and bank settings"**: the nine variables, their rules, that they are read at startup (a change needs a restart), that the startup lines print only enabled/disabled and variable names, and that **they are never committed** (an example start command with `read -r`, like the staff ID one, no real values). `SHOP_NAME` holds the whole first line of the report (RPT9: no prefix is added). `docs/runbook-local.md` gets the same as a step-by-step (where to put them, how to restart).
5. **"Exporting a month"**: the three outputs (the CSV, unchanged and still the default without `report`, RPT5; the summary; the detail), what each contains, that income counts only `delivered` orders, which day an order belongs to (the `placedAt` date as written, device clock, RPT3), that days without orders appear in the summary as 0 and are skipped in the detail, that the `tách` sheet's month total reads `Tổng tháng M`, that old USD test orders should be deleted first, and a `curl` example for each report. `sample/*.xlsx` is reference only and is git-ignored.
6. **"Storage"**: the "Step 7" bullet (adds `payment_method` and `payment_due_at`; existing orders stay NULL and read as cash) and the "Step 8" bullet (stored `pending` and `accepted` orders become `preparing`; cannot be undone; back up first). There is no step 9 (renewal needs no new column).
7. **"Notifications"** (restaurant): no Accept step any more; the chime and snackbar fire for every **new** order id arriving as `preparing` or `awaiting_payment`, and never again for a known id (so an expired order brought back as cash, or renewed, doesn't ring); the bell badge counts `awaiting_payment` + `preparing` orders (PAY10).
8. **"Known limitations"**: payment is confirmed by hand (no bank notification); the 5-minute countdown shown on the phone can be off with a wrong phone clock; prices are still trusted from the client (so the QR amount equals the order total the client sent); `placedAt` decides the report day; a customer browser tab opened before the change can't place orders until reloaded; the customer renew and switch routes have no login.

## Non-goals

Any code change, translating existing docs, the nginx/Caddy files.

## Tests written with the change

None (documentation). The reviewer checks every statement against the merged code.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Each documented route, status, field and rule matches the code; no `pending` left; examples contain no real values | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| The owner can follow the runbook to set the settings and download both reports | owner acceptance - "unverified" until done |

## Carried in from reviews of `shared-order-payment-model-and-client`

- Deploy order: restart the backend (after a dated backup) so schema step 8 runs before the apps are reloaded. The new apps skip unknown statuses, so old `pending` orders would be invisible against an un-migrated backend.

## Carried in from `docs/reviews/execute-restaurant-orders-show-payment-method.md`

- Update the "Notifications" section as listed in that review (chime rules, badge, expiry display). Pending/Accept no longer exist.
- The restaurant page has a copy of `transferReference` (backend `vietqr.dart`), and both sides pin `abc` to `DH920331`. Mention it under "Code" so a change touches both.

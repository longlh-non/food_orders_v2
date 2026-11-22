---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: [backend-order-payment-method, backend-shop-settings]
securityReview: required
---

# Backend: the bank-transfer QR (VietQR payload with the exact amount) and `GET /payment-info`

Planned 2026-11-19, updated the same day. **No open decisions block this card.** Changes the `CLAUDE.md` API table first (owner approval needed for this card).

## Owner decision (verbatim, 2026-11-19)

> If they pick "Chuyển khoản", generate a QR code for Vietnamese bank transfer with the exact same amount of money they need to pay.

- **PAY7, decided (owner, 2026-11-19):** "7. Yes" to showing the bank name, account number and amount as text next to the QR (a customer can't scan their own phone screen). The replies below carry the text fields, and `BANK_NAME` is part of the bank settings (see `backend-shop-settings`).
- **PAY8, decided (owner, 2026-11-19):** "7. Yes" to the transfer content `DH` + the last 6 digits of the order id (e.g. `DH482913`), ASCII only, well under the 25-character limit. The restaurant card shows the same text on the order.
- **PAY15, decided (owner, 2026-11-19):** an expired order can be renewed (`backend-order-payment-transitions`, within 15 minutes). A renewed order is `awaiting_payment` again with a fresh deadline, so this route serves it like any live transfer order: **same amount, same reference, new `dueAt`**. A still-cancelled (expired) order gets no QR.

## Design in plain words

The backend builds the **text** inside the QR (the VietQR / NAPAS EMVCo payload). The customer app only draws that text as a square code (card `customer-payment-qr-page`). Why the backend and not the app:
- the amount comes from the order **stored on the server**, so the QR can't differ from what the restaurant sees (also after a renewal);
- the bank settings stay in one place (`backend-shop-settings`);
- the payload is pure text logic, easy to test with `dart test`.

Trade-off: the app needs one more request, and the customer must be online to get the code. That is already true (they placed the order).

## Sources

`backend/lib/orders_api.dart` (`_findOrder`, routes), `backend/lib/shop_settings.dart`, `CLAUDE.md` -> "Backend". Public spec: NAPAS "VietQR" over EMVCo merchant-presented QR (tags below). The executor checks the layout against a published VietQR example and a bank app's own QR before relying on it; agents can't scan, so the real scan is owner acceptance.

## Goal

### Contract

| Method | Path | Purpose | Responses |
|---|---|---|---|
| GET | `/payment-info` | public: whether bank transfer is set up, and the account to show | 200 `{"transferEnabled": bool}`; when enabled also `bankName`, `accountNumber`, `accountName` |
| GET | `/orders/{id}/payment-qr` | the QR for an order that is `bank_transfer` and `awaiting_payment`, not past its deadline (**a renewed order qualifies**) | 200 `{"payload": string, "amount": int, "reference": string, "dueAt": string, "bankName": string, "accountNumber": string, "accountName": string}`; 404 unknown id; **409** not payable (cash, paid, switched, **cancelled / expired**, past its deadline); 503 bank transfer not set up |

- `amount` is the order total in whole VND, computed on the server from the stored items (`quantity x (price + toppings)`); an order with a non-whole or zero total never reaches this route (the earlier card rejects it).
- `reference` is the transfer content: `DH` + the last 6 digits of the order id (PAY8); an id with fewer than 6 digits uses all of them. It does not change when the order is renewed.
- `dueAt` is the order's current `paymentDueAt`, so the page can show its countdown (after a renewal, the fresh one).
- An `awaiting_payment` order past its deadline that the sweep hasn't cancelled yet is **not** served (409), same as expired.
- Never cached (`Cache-Control: no-store`). The account number is not secret (it is printed in the QR), but no request data is ever echoed in an error.

### The payload (pure function in `backend/lib/vietqr.dart`)

`String vietQrPayload({bin, account, amount, reference})`. Each field is `tag(2) + length(2 digits) + value`, in this order:

1. `00` = `01` (format version)
2. `01` = `12` (dynamic: this code has an amount)
3. `38` = merchant account information, containing: `00` = `A000000727` (NAPAS), `01` = containing `00` = the BIN and `01` = the account number, and `02` = `QRIBFTTA` (transfer to an account)
4. `53` = `704` (VND)
5. `54` = the amount, digits only, no separator, no decimals
6. `58` = `VN`
7. `62` = additional data, containing `08` = the reference
8. `63` = `04` + the CRC: CRC-16/CCITT-FALSE (polynomial 0x1021, initial 0xFFFF, no reflection, no final xor) over everything before it **including** the text `6304`, written as 4 upper-case hex digits.

Lengths count characters (all ASCII here). The reference is checked to be ASCII letters and digits, at most 25 characters.

## Non-goals

Drawing the QR (the app), confirming a payment, expiry and renewal (`backend-order-payment-transitions`), bank notifications, any other bank-specific format, a QR with no amount.

## Tests written with the change

`backend/test/vietqr_test.dart` and the API tests:
- CRC-16/CCITT-FALSE of the text `123456789` is `29B1` (the standard check value); the final 4 characters of a payload equal the CRC of the rest.
- Parse the payload back with a small test-local reader of tag/length/value: every tag above is present in order, nested values are right, the amount is exactly the order total (`2 x (25000 + 10000) + 4000` = `74000`), the reference is `DH` + the last 6 digits.
- The reader rejects a payload whose length fields don't add up (guards the writer against a length bug on long values, e.g. a 19-digit account).
- Route: 200 for a live transfer order with the text fields present; amount from stored items, not from any request value; 409 for cash / switched / confirmed / expired / cancelled / overdue-but-unswept; 404 unknown; 503 when `transferEnabled` is false; `no-store` header; `GET /payment-info` both states, account fields only when enabled.
- **A renewed order** (cancelled by expiry, then renewed): 200 with the same `amount`, `reference` and `payload` as before, a new `dueAt` equal to the fresh deadline; the same order while still cancelled: 409.
- Existing tests unchanged.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Payload layout, CRC, amount, reference, renewed order | `make backend-test` (gate) |
| Backend clean, no new dependency | `make backend-analyze` (gate) |
| Amount only from the stored order; no request data echoed; QR served only while payable | `security-reviewer` (review) |
| `CLAUDE.md` table matches the code | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| The payload, drawn as a QR and scanned by a real Vietnamese banking app, opens a transfer to the right account, with the exact amount and the content filled in | owner acceptance - "unverified" until done |

## Environment limits

Agents can't scan a QR or reach a bank. Use a fake BIN and account in tests; never the owner's real ones.

## Amendment after review (2026-11-19)

An order id with no digit at all gets 6 digits from a fixed FNV-1a hash of the id, so it doesn't get a bare `DH`. It is documented in `CLAUDE.md`. App ids are timestamps, so this shouldn't happen in practice. The executor added it, and the code review accepted it.

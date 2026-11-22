---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [shared-order-payment-model-and-client, backend-payment-qr-endpoint]
securityReview: required
---

# Customer: a small client for `GET /payment-info` and `GET /orders/{id}/payment-qr`

Planned 2026-11-19, updated the same day. Only the customer app needs the QR and the payment-info check, so this lives in `lib/customer/` (invariant 2), not in shared code. (Switching to cash is already in the shared `OrderApiClient` / `OrderRepository`.)

## Sources

`lib/shared/api/order_api_client.dart` (style: `/api` base, optional `http.Client`, one exception type, server text never shown), `lib/restaurant/api/export_client.dart` (a single-purpose client with typed failures), the backend card `backend-payment-qr-endpoint` (replies and status codes; PAY7 and PAY8 are decided there).

## Goal

New `lib/customer/api/payment_client.dart`:

- `PaymentClient({http.Client? client})`, `close()`.
- `Future<PaymentInfo> fetchInfo()` -> `GET /api/payment-info`. `PaymentInfo` has `transferEnabled` and, when enabled, `bankName`, `accountNumber`, `accountName` (text, cleaned like other server text, e.g. `displayText` from shared models). Enabled without those three fields is a malformed reply and throws.
- `Future<PaymentQr> fetchQr(String orderId)` -> `GET /api/orders/{id}/payment-qr` (id `Uri.encodeComponent`-ed). `PaymentQr` has `payload` (non-empty string), `amount` (int, > 0), `reference` (string, the `DH...` transfer content), `dueAt` (UTC `DateTime`), `bankName`, `accountNumber`, `accountName`. A reply with a wrong shape throws.
- One `PaymentException` with `failure`: `notPayable` (409), `notSetUp` (503), `notFound` (404), `other` (anything else, no answer, bad body), plus `statusCode`. The message is for developers only and never contains the server's text.
- No state, no caching, no timers (the pages decide when to call).

## Non-goals

The QR drawing, any page or state class, the switch-to-cash call, a repository for payment data.

## Tests written with the change

`test/payment_client_test.dart` with `MockClient`:
- `fetchInfo` both states; enabled without the account fields throws; a body that isn't an object or lacks `transferEnabled` throws.
- `fetchQr` success parses every field; the request path is exact, with a hostile id (`a/b?x=%`) encoded; 409 / 503 / 404 / 500 / network error map to the right `failure`; an empty `payload`, a missing or non-integer `amount`, an amount of 0 or less, a missing text field, or a bad `dueAt` throws.
- No exception text contains the server's reply body.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Format, analysis, boundaries (no import of restaurant code; nothing moved into shared) | `make format-check`, `make analyze`, `make boundaries` (gates) |
| Strict parsing; server text never shown | `security-reviewer`, `code-reviewer` (reviews) |
| `make check` green | `make check` exit 0 (gate) |

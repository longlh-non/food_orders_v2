---
task: shared-order-payment-model-and-client
status: passed
p0: 0
p1: 0
---

# Security review: shared-order-payment-model-and-client

Date: 2026-11-19. Reviewer: `security-reviewer` (independent, read-only, first pass). It did not see the code review.

## Gates

See `docs/reviews/execute-shared-order-payment-model-and-client.md`. The final `make check` exited 0 (orchestrator, this session).

## Findings

P0: none. P1: none.

P2 (optional, no exploit path):
- `renewableUntil` could leave `DateTime`'s range for an absurd server date. Theoretical, because the server sets the value. → `customer-payment-qr-page` guards it when it uses the getter.
- `copyWith` can't clear `paymentDueAt`. Display only.

## Checked and clean (summary)

- **Parsing:**
  - One bad order or SSE line is skipped, and the stream keeps going.
  - New values for the enums, a wrong type and a bad date all fail closed.
  - `paymentMethod: null` doesn't silently become cash.
- **Staff credentials:**
  - used only as headers on the two staff POSTs;
  - never stored, logged or put in messages;
  - never sent on customer calls.
- **URLs:** relative and same-origin. Every special character in an id is encoded, and the action segment is a constant.
- **Server-owned fields:** the client can't send them. `toJson` has no `paymentDueAt`, and the payment POSTs have no body.
- **The app changes add no capability:**
  - the cart posts `preparing` with cash, as before;
  - the restaurant only sends status moves the backend accepts;
  - the removed Accept reduces what the client sends.
- **No dependency change.**

## Unverified (needs the real environment)

- Caddy and nginx pass `POST /api/orders/{id}/<action>` with the `X-Staff-*` headers through to the backend.
- The proxy doesn't normalise an encoded `%2F` in an id into another path (at worst a 404).

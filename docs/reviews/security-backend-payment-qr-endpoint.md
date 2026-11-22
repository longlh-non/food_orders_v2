---
task: backend-payment-qr-endpoint
status: passed
p0: 0
p1: 0
---

# Security review: backend-payment-qr-endpoint

Date: 2026-11-19. Reviewer: `security-reviewer` (independent, read-only, first pass). It did not see the code review.

## Gates

See `docs/reviews/execute-backend-payment-qr-endpoint.md`. The final `make check` exited 0 (orchestrator, this session).

## Findings

P0: none. P1: none.

**P2: the transfer reference can collide** (`backend/lib/vietqr.dart:191-201`). Order ids are chosen by the client and are public, so an attacker can make an order whose reference matches a victim's `DHxxxxxx`. Honest timestamp ids also repeat their last 6 digits about every 16 minutes. Staff confirm transfers by hand, so they could confirm the wrong order. It isn't a money path: the amount always comes from the stored order. The format was decided by the owner (PAY8), so the risk is mitigated, not removed. **Follow-up:** `restaurant-confirm-bank-transfer` shows the amount, the name and the reference, and staff match all three (a note was added to the card).

## Checked and clean (summary)

- **The request can't change the QR.** The amount comes only from stored items, the reference from the id, and the account from `ShopSettings`. No query string, header or body is read.
- **No TLV injection.** Every field is length-checked (99 at most). The reference is `DH` plus digits only, and is re-validated. The BIN and account must be digits.
- **The bank settings are validated at startup.** An invalid value turns transfer off; nothing throws.
- **Little is exposed.** `/payment-info` gives only the bank name, account number and holder name, and both 200s are `no-store`.
- **Fixed error texts.** The id is JSON-quoted in logs.
- **The write inside a GET is harmless.** It only cancels an order that is already overdue, and the conditional UPDATE is idempotent. There is no CSRF gain.
- **The cost per request is negligible.**
- **A stale order gets no QR.** It answers 409 for every state except a live awaiting order before its deadline. A QR already on screen stays scannable, so the customer page must clear it at `dueAt` and on status changes (a note was added to `customer-payment-qr-page`).

## Unverified (needs the real environment)

- A real banking-app scan.
- `no-store` survives Caddy and nginx.

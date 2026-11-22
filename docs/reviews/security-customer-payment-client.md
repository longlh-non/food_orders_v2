---
task: customer-payment-client
status: passed
p0: 0
p1: 0
---

# Security review: customer-payment-client

Date: 2026-11-19. Reviewer: `security-reviewer` (independent, read-only, first pass). It did not see the code review.

## Gates

See `docs/reviews/execute-customer-payment-client.md`. The final `make check` exited 0 (orchestrator, this session).

## Findings

P0: none. P1: none.

The reviewer confirmed:
- **Strict parsing:** the body must be an object, the bool and the int are typed, and an impossible `dueAt` is rejected without rolling over.
- **Payload isolation:** the QR payload is passed through raw and is never mixed with the display fields.
- **Bidi and control-character spoofing:** `displayText` removes controls and embedding/override and isolate characters.
- **Ids:** encoded.
- **Leaks:** no body text in errors, and no logging.
- **Same origin:** the client only calls same-origin URLs.

P2, all applied before archiving (see the execute review, "Hardening after review"):
1. The account number and reference were only cleaned, not format-checked, so look-alike characters could survive. Now they are strict ASCII-digit rules.
2. The payload and the display fields weren't cross-checked. Now the payload must contain the account number and the amount.
3. `amount` had no upper bound. Now it is capped.
4. An id of `.` or `..` collapsed to another path (a harmless 404). Now it is refused before any request.

## Unverified (needs the real environment)

- `Uri(path: '/api/...')` resolves against the page origin in Flutter web. `OrderApiClient` already relies on this.
- A real banking-app scan (from the backend card).

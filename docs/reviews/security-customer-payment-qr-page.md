---
task: customer-payment-qr-page
status: passed
p0: 0
p1: 0
---

# Security review: customer-payment-qr-page

Date: 2026-11-19. Reviewer: `security-reviewer` (independent, read-only, first pass). It did not see the code review.

## Gates (first round)

See `docs/reviews/execute-customer-payment-qr-page.md`.

## Findings

P0: none. P1: none.

**Checked and clean:**

- **Supply chain:**
  - `qr_flutter` 4.1.0 (BSD-3-Clause) and `qr` 3.0.3 (BSD-style) are hosted on pub.dev, each with a sha256, and are the only entries added to the lockfile.
  - They pull in no new transitive packages.
  - There is no `dart:io`, `dart:html`, `package:web`, `dart:js`, http, socket or process use anywhere in their `lib/`.
  - Their maintenance and publisher were not checked (that needs pub.dev).
- **The QR shows only while the order is payable.** The clock is read fresh in every build. The QR clears in the same frame as any change to status, method or deadline. A late answer is dropped by a token, and a QR for a different window (more than 5 s off) is never shown.
- **The QR is built only from the payload**, and the text shown comes from the same verified `PaymentQr`.
- **Selectable text** is limited to the 5 bank and payment fields.
- **Error texts** are fixed, and no server text is shown.
- **The banner shows only this browser's own orders** (`MyOrders`).
- **Updates on the stream can't trigger a switch or a renew.** Only a tap does.

**P2:**

1. **The payload agreement check is a substring check** (`lib/customer/api/payment_client.dart:137`). An account `123456789` passes against a payload for `1234567890`. **Fixed in round 1:** an exact TLV read (tag 54 for the amount, tag 38/01/01 for the account).
2. **A phone clock running behind keeps the QR up past the true deadline** until the server's `cancelled` event arrives. The server still refuses afterwards. Accepted, because the server decides. The P1 re-read in the execute review helps.
3. **An expired banner row can stay listed past its 15 minutes.** Cosmetic. Deferred.

## Unverified (needs the real environment)

- A real banking-app scan.
- `qr_flutter` rendering in the Flutter web build.
- Phone clock skew on iOS Safari.

## Re-review 1

The security reviewer re-checked the fix diff. Its P2-1 is **closed**:
- the payload is parsed as EMVCo TLV (strict two-digit tags and lengths, no overrun, no repeated tag, no trailing junk);
- the parse agrees with `backend/lib/vietqr.dart`;
- the amount and the account are compared exactly.

`OrderRepository.refresh()` adds no exposure: same origin, no logging, errors swallowed, timed out by the page. The re-read can't cause a request storm (once per deadline; the button is disabled while busy). **Verdict: passed (P0 0, P1 0).**

New P2s:
1. The shown reference wasn't compared with 62 > 08. **Fixed by the orchestrator** (see the execute review), with tests.
2. The CRC (tag 63) and currency (tag 53) aren't checked. A bad CRC is refused by the bank app anyway. Deferred.
3. A refresh racing a stream event. Accepted (narrow window, recoverable).

The final `make check` exited 0 (orchestrator, this session; Flutter +498, backend +524).

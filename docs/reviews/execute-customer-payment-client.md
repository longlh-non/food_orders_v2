---
task: customer-payment-client
status: passed
p0: 0
p1: 0
---

# Execute review: customer-payment-client

Date: 2026-11-19. Reviewer: `code-reviewer` (independent, read-only, first pass). The security review is in `docs/reviews/security-customer-payment-client.md`.

## Candidate

`lib/customer/api/payment_client.dart` (new):
- `PaymentClient.fetchInfo()` and `fetchQr(id)`;
- typed failures: 409 `notPayable`, 503 `notSetUp`, 404 `notFound`, anything else `other`;
- strict parsing;
- error messages never contain the body.

`test/payment_client_test.dart` (new).

## Gates

| Command | Exit code | Output tail | Run by |
|---|---|---|---|
| `make analyze` | 0 | `No issues found!` | executor (first round) |
| `make test` | 0 | `+409: All tests passed!` (first run had 1 failure in its own new date test, fixed) | executor (first round) |
| `make boundaries` | 0 | `boundaries: ok` | executor (first round) |
| `make format-check` | 0 | `Formatted 73 files (0 changed)` | executor (first round) |
| `make check` | 0 | `0 changed`, `boundaries: ok`, analyze clean, Flutter `+424`, backend `+524: All tests passed!` | orchestrator, this session, final candidate |

## Findings

P0: none. P1: none.

The reviewer confirmed:
- the client matches the `CLAUDE.md` contract and the backend's real output;
- `dueAt` parsing accepts the backend's `...mmmZ` format;
- the extra strictness can't reject a valid reply;
- a dedicated client is justified (typed failures), so no new abstraction is needed;
- the tests are deterministic.

P2:
1. Only `http.ClientException` is caught. This matches `OrderApiClient`; accepted.
2. No request timeout, by design. **Follow-up:** `customer-payment-qr-page` gives the page a timeout or a Retry state (a note was added to the card).
3. Nothing tested Vietnamese text over the wire, and the backend sends `application/json` with no charset. **Fixed:** the body is decoded with `utf8.decode(bodyBytes)`, and a test sends accented bytes.
4. Cosmetic signature of `_invalid`. Deferred.

## Hardening after review (applied before archiving)

Applied by the executor, from both reviews' P2s:
- explicit UTF-8 decoding;
- `accountNumber` must be 1-19 ASCII digits;
- `reference` must be `DH` + digits;
- `amount` must be from 1 to 55,000,000,000 (50 lines × 100 × (1,000,000 + 10 toppings × 1,000,000));
- the QR payload must contain the account number and the amount digits;
- an empty or all-dot id gives `notFound` with no request.

**One correction by the orchestrator:** the executor's reference rule `^DH[0-9]{6}$` would have rejected a valid backend reply. The backend uses all the digits when an id has fewer than 6 (`backend/lib/vietqr.dart:41`). The rule is now `^DH[0-9]{1,6}$`, with a test for `DH123`.

These changes only tighten checks, and each has a test. They were checked by the final `make check`. No P0 or P1 was open, so the reviewers were not run again.

## Unverified (owner acceptance)

None for this card on its own. The page that uses it is checked with `customer-payment-qr-page`.

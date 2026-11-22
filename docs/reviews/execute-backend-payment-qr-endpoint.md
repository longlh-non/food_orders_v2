---
task: backend-payment-qr-endpoint
status: passed
p0: 0
p1: 0
---

# Execute review: backend-payment-qr-endpoint

Date: 2026-11-19. Reviewer: `code-reviewer` (independent, read-only, first pass). The security review is in `docs/reviews/security-backend-payment-qr-endpoint.md`.

## Candidate

- `backend/lib/vietqr.dart` (new): `crc16CcittFalse`, `transferReference` (`DH` + the last 6 digits of the id; an FNV-1a fallback for an id with no digits) and `vietQrPayload`.
- `backend/lib/orders_api.dart`: `GET /payment-info` and `GET /orders/{id}/payment-qr`.
- `backend/lib/shop_settings.dart`: U+2028 and U+2029 are rejected (a deferred P2 from `execute-backend-shop-settings.md`), with the deferred test gaps added.
- `CLAUDE.md`: the table rows, the QR layout bullet and the code list.
- Tests: `vietqr_test.dart`, `orders_payment_qr_test.dart` and `shop_settings_test.dart`.

## Gates

| Command | Exit code | Output tail | Run by |
|---|---|---|---|
| `make backend-analyze` | 0 | `No issues found!` | executor (first round) |
| `make backend-test` | 0 | `+523: All tests passed!` | executor (first round) |
| `make format-check` | 0 | `Formatted 70 files (0 changed)` | executor (first round) |
| `make analyze` | 0 | `No issues found!` | executor (first round) |
| `make test` | 0 | `+343: All tests passed!` | executor (first round) |
| `make boundaries` | 0 | `boundaries: ok` | executor (first round) |
| `make check` | 0 | `0 changed`, `boundaries: ok`, analyze clean, Flutter `+343`, backend `+524: All tests passed!` | orchestrator, this session, final candidate after the P2 fixes |

## Findings

P0: none. P1: none.

The reviewer confirmed the payload against the VietQR / EMVCo layout:
- tag order `00 01 38 53 54 58 62 63`, with lengths as 2 decimal digits;
- `01=12` (an amount is included);
- `38{00=A000000727, 01{00=BIN, 01=account}, 02=QRIBFTTA}`;
- `62/08`, the field banking apps prefill the transfer content from;
- the CRC-16/CCITT-FALSE over the text including `6304`, in upper-case hex.

Fields 59 and 60 are optional for a personal-account QR. Only a real scan can confirm that.

P2:

1. **Fixed before archiving.** `vietqr_test.dart` computed the expected CRC with the same function it tests. The orchestrator computed the CRC independently with a separate Python implementation: `2B85` for the fake-data payload, and `0x29B1` for `123456789` as a cross-check. The test now hard-codes `2B85`, and the final gate run passes with it, so the writer's CRC matches the independent value.
2. **Fixed before archiving.** The payment-qr total now checks `isFinite` and catches any error from a corrupt stored item, returning the fixed 500. A test covers a stored item that isn't a map.
3. **Fixed before archiving.** A comment says this GET can cancel an already-overdue order (same as the sweep).
4. **Accepted, card amended.** The FNV-1a fallback reference for an id with no digits.

The P2 fixes were small and test-covered. The orchestrator checked them by reading the code and running the final `make check`. No P0 or P1 was open, so the reviewers were not run again.

## Unverified (owner acceptance)

A real banking app scans the QR and opens a transfer to the right account, with the exact amount and `DH…` filled in. It must also accept a QR without fields 59 and 60.

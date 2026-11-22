---
task: customer-payment-qr-page
status: passed
p0: 0
p1: 0
---

# Execute review: customer-payment-qr-page

Date: 2026-11-19. Reviewer: `code-reviewer` (independent, read-only, first pass). The security review is in `docs/reviews/security-customer-payment-qr-page.md`.

## Candidate

- `pubspec.yaml` and `pubspec.lock`: `qr_flutter ^4.1.0` (4.1.0), with `qr` 3.0.3 as a transitive dependency. Owner-approved (PAY4), added with `flutter pub add`.
- `lib/customer/pages/payment_qr_page.dart`: replaces the stub with these states:
  - loading;
  - the QR with a countdown and the bank details;
  - error and Retry;
  - checking;
  - switching to cash;
  - paid or cash;
  - the expired question (switch to cash, or a new QR);
  - renewing;
  - renew 503;
  - past 15 minutes;
  - staff-cancelled;
  - order not found.
- `lib/customer/pages/menu_page.dart`: the banner also lists orders expired within the last 15 minutes ("Hết hạn thanh toán"), and transfer rows open the payment page.
- Tests: `test/payment_qr_page_test.dart` (new, 38 tests); `test/menu_page_test.dart` (3 banner tests); `test/cart_page_test.dart` (its fake now returns `paymentDueAt` like the real backend, and a bounded `pump` replaces `pumpAndSettle` because of the 1 s timer; no assertion was weakened).

## Gates (first round)

Run by the executor in this session.

| Command | Exit code | Output tail |
|---|---|---|
| `make analyze` | 0 | `No issues found!` |
| `make test` | 0 | `+473: All tests passed!` |
| `make boundaries` | 0 | `boundaries: ok` |
| `make format-check` | 0 | `75 files (0 changed)` |

## Findings

P0: none.

### P1-1: the "checking" state has no re-read and no way out

`payment_qr_page.dart:279-283`, `:143-164`, `:206-238`.

The card requires "a short grace re-read via the repository". There is none, and nothing gets the page out of this state:
- `OrderRepository` fetches once at start-up and never again after the live connection reconnects, so a `cancelled` event lost in a connection blip is gone for good;
- the page waits on its spinner forever;
- the timer is stopped;
- there is no button.

A 409 also only re-reads the cache. In the expired view it wrongly shows "Đã quá 15 phút". In the QR view it is silent.

**Fix:**
- `OrderRepository.refresh()` (the card's scope now includes `shared`);
- a one-shot re-read about 2 s after the deadline and after any 409;
- "Kiểm tra lại" and "Về menu" buttons in the checking view;
- tests.

### P2

1. **Clock skew.** A phone clock that runs ahead hides the QR or the buttons by the phone clock alone, while the server would still accept. The card allows the phone clock for display only. Deferred. **Follow-up:** estimate the clock offset from the server, or hide buttons only after a server 409. Noted for the owner.
2. **A 409 in the QR view is silent.** Fixed in round 1.
3. **A timed-out renew may have succeeded on the server.** Mostly cured by the P1 re-read.
4. **The banner doesn't re-check the 15-minute line on its own.** Tapping a stale row shows the correct "quá 15 phút" view. Deferred (cosmetic).
5. **The banner row has no tap hint (chevron).** The ripple is unverified. Deferred to `vi-translate-customer-ui` and the UI polish.
6. **The banner and cart tests reach a real `PaymentClient`.** flutter_test answers 400, so these tests are deterministic, not hidden network calls. Accepted.
7. **Test gaps:**
   - a late QR answer for the old window after a renewal, and the 5 s mismatch path: added in round 1;
   - the weak "never negative" assertion: deferred.
8. **The dependency note:** covered by the security review.

## Fix round 1

The batch was sent to the executor:
- P1-1;
- P2-2;
- the security P2-1 (an exact TLV comparison of the payload, in `payment_client.dart`);
- the P2-7 tests.

The results are appended under "Re-review 1".

## Re-review 1

The executor's fix round 1 covered:
- **P1-1:** `OrderRepository.refresh()` (shared; card scopes now `[customer, shared]`). It also adds a one-shot re-read 2 s after the deadline (once per deadline, cancelled on every path), a refresh before deciding on any 409, and "Kiểm tra lại" plus "Về menu" in the checking view.
- **P2-2:** "Đơn vừa thay đổi, đang kiểm tra lại".
- **The security P2-1:** an exact TLV comparison in `payment_client.dart`.
- **P2-7:** the tests.

Gates were run by the executor: analyze 0; test 0 (+495); boundaries 0; format-check 0.

The code reviewer re-checked the fix diff. **P1-1 closed. Verdict: passed (P0 0, P1 0).**

New P2s:
1. A refresh can briefly overwrite a newer stream event. There is no version field, the window is narrow, and the 2 s re-read and the button recover it. Accepted.
2. `refresh()` inserted unseen orders in reverse order. **Fixed by the orchestrator:** it iterates oldest-first, and a test checks newest-first.
3. The shown `reference` wasn't compared with the QR's tag 62 > 08 (also raised by the security re-review). **Fixed by the orchestrator:**
   - `_payloadMatches` now also requires `62 > 08 == reference`;
   - two client tests were added (a different content, and no content);
   - the page tests' fake payload now carries the reference in 62 > 08 and its marker in 62 > 05.

The two orchestrator fixes are small, tighten behaviour only, and each has a test. They were verified by the final `make check`, so the reviewers were not run again.

| Command (final candidate) | Exit code | Output tail | Run by |
|---|---|---|---|
| `make check` | 0 | `0 changed`, `boundaries: ok`, analyze clean, Flutter `+498: All tests passed!`, backend `+524: All tests passed!` | orchestrator, this session |

**Deferred, with the owner told:**
- clock skew (follow-up: estimate the server clock offset, or hide buttons only after a server 409);
- the banner doesn't re-check the 15-minute line on its own;
- no tap hint on banner rows;
- the weak "never negative" assertion.

**Strings for `vi-translate-customer-ui`:** all new Vietnamese texts are listed by the executor, including "Kiểm tra lại" and "Đơn vừa thay đổi, đang kiểm tra lại".

## Unverified (owner acceptance)

- A real banking app scans the QR (correct account, amount and `DH…` content).
- `qr_flutter` renders in the web build.
- The 5- and 15-minute flows on a phone, including a dropped connection at the deadline.
- Readability at the largest text size.

Card moved to `docs/tasks/done/`.

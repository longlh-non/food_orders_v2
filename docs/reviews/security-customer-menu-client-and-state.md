---
task: customer-menu-client-and-state
status: passed
p0: 0
p1: 0
reviewedFiles:
  - lib/shared/models/menu_item.dart
  - lib/shared/api/order_api_client.dart
  - lib/customer/state/menu_state.dart
  - test/menu_client_test.dart
  - test/menu_state_test.dart
---

# Security review — customer-menu-client-and-state

Independent first-pass review by `security-reviewer` (tool-restricted, read-only), 2026-11-10, on the same frozen candidate as the code review.

## Scope

- **Assets:** the customer UI's integrity and availability, the cart, and the order POST payload. Client-trusted prices are already an accepted risk.
- **Input:** the `GET /api/menu` body. It comes from database rows the owner edits, or from anyone who can reach the backend or proxy.
- **No new** trust boundary, dependency or network exposure.

## Checked with no issues found

- **No crash path.** `fetchMenu` throws only `FormatException` or `ClientException`. `MenuState.load` catches everything at the boundary, resets loading in `finally`, and its re-entrancy guard prevents requests piling up.
- **No partial menus.** A malformed item throws before the assignment, so items are never half-updated.
- **No NaN, Infinity or negative prices.** Nested values are also rejected, because only String and num fields are accepted.
- **No menu `id` in any URL.** The only `$id` interpolation is the order id in `updateStatus`, which predates this card.
- **Plain text only.** No UI renders names yet; keep them as plain `Text`.
- **The shared long-lived `http.Client`** changes no security property: same-origin relative URLs, no `withCredentials`, and no cookies or auth in this app.
- **Tests** use `package:http/testing.dart`, which is part of `http`, so there's no supply-chain change.

## Findings: P0 0 · P1 0 · P2 3 (deferred)

- **P2-1, unbounded menu size** (`order_api_client.dart:61`, `menu_item.dart:24`): there's no cap on the item count or string lengths, and the body is fully buffered, so a huge body could hang the tab (that tab only). **Deferred** to `backend-request-body-limit` (cap the response or the menu size server-side), with a note on the next card.
- **P2-2, `debugPrint` prints in release builds** (`menu_state.dart:43`): the exception text and a minified stack trace go to the browser console. Nothing secret is included: field names and status codes only. **Deferred**, with a note on the next card to wrap it in `if (kDebugMode)`.
- **P2-3, lenient values** (`menu_item.dart:32`): very large finite prices are accepted, and duplicate ids aren't detected; they would collapse into one cart entry. Not exploitable beyond a wrong cart. **Deferred**, noted on the next card. The backend already caps prices at 1e9.

**Counts:** P0 0 · P1 0 · P2 3 (deferred).

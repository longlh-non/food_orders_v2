---
task: customer-menu-client-and-state
status: passed
p0: 0
p1: 0
---

# Execute review — customer-menu-client-and-state

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-10. It ran in parallel with `security-reviewer` on the same frozen candidate, and neither saw the other's conclusions. Security report: `docs/reviews/security-customer-menu-client-and-state.md`.

## Implementation notes

- **`MenuItem`:** a defensive `fromJson` (each bad field gives a `FormatException` naming it), plus `==` and `hashCode` by id.
- **`OrderApiClient`:** takes an optional injected `http.Client`. No-arg callers are unchanged: `OrderRepository` and `MenuState.instance` are the only non-test callers.
  - New `fetchMenu()`: a non-200 status throws `ClientException`; a body that isn't a list, or a bad item, throws `FormatException`.
  - **Beyond the card's wording:** `streamUpdates` (SSE) also goes through the injected client. The card listed only get, post and patch. The reviewer judged this acceptable, and it fixes a pre-existing leak: `request.send()` created a new client on each reconnect and never closed it.
- **New `lib/customer/state/menu_state.dart`:** `MenuState` has a singleton plus an injectable constructor, tracks items, loading and error, can retry, and ignores a re-entrant load. Errors are caught at the UI boundary.
- **No visible UI change** (by design: the next card).

## Gates

| Command | Exit |
|---|---|
| `make analyze` | 0 |
| `make test` | **2** on the first attempt. The concurrent-load test counted requests before `MockClient`'s asynchronous handler had run (a test timing issue). Fixed with `await Future<void>.delayed(Duration.zero)` before counting; the code was unchanged. |
| `make test` (26 tests: 2 existing + 24 new) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make backend-analyze` | 0 |
| `make backend-test` (72) | 0 |
| `make check` (final candidate) | **0** |

## Findings: P0 0 · P1 0 · P2 2 (both carried to the next card)

- **P2-1** `lib/customer/state/cart.dart:27`: because items are equal by id and a `Map` keeps the original key, a cart item keeps its **old price and name** after the owner changes the menu and the customer reloads it. `total` and `toOrderItems()` use that stale object. **Carried** to `customer-menu-page-uses-backend-menu`: refresh cart items from the fresh menu on reload.
- **P2-2** `lib/customer/state/menu_state.dart:46`: `notifyListeners()` in `finally` would throw if the state were disposed mid-load. Fine for the never-disposed singleton. The UI should show a generic message, not `error.toString()`. **Carried** to the next card.

**Checked with no issues found:**
- All six acceptance rows are covered.
- The concurrent-load test is sound: the gate holds the first request open, so a second request would make the count 2.
- Notify order is pinned (`[true, false]`).
- The `Cart` singleton is cleaned up in tests.
- Boundaries hold.

## Unverified

The live order stream through the shared client, in a real browser through Caddy. Tests don't cover `streamUpdates` with the injected client. Owner smoke test: place an order and watch it appear live on restaurant.local after the web apps reload this code.

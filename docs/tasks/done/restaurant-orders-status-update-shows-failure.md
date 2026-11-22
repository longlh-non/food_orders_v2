---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [shared-order-calls-report-failure]
---

# Restaurant orders: show a message when a status change fails

## Why

In `lib/restaurant/pages/orders_page.dart` both the status button (`OrderRepository.instance.updateStatus(order.id, next)`) and the SnackBar "Accept" action (`repo.updateStatus(...)`) fire the call and ignore the result. If the backend rejects it (404, 400) or is down, the button looks like it did nothing, and the error goes into an unawaited future. After `shared-order-calls-report-failure` the call throws `OrderRequestException`; this card catches it.

## Sources

`lib/restaurant/pages/orders_page.dart` (`_onRepoChanged` Accept action, the `FilledButton` near the order total), `test/orders_page_test.dart`, the seam and exception from `shared-order-calls-report-failure`.

## Goal

1. One small private method in the page state, e.g. `_changeStatus(String id, OrderStatus status)`, that awaits `OrderRepository.instance.updateStatus`, catches `OrderRequestException` only, and on failure (if `mounted`) shows the fixed SnackBar 'Couldn't update the order. Try again.' (no exception text). Both call sites use it.
2. The status button is a method on a card widget; if that widget is stateless, pass the callback in from the page state rather than making the card stateful.
3. No per-button progress state: the SSE push or the repository merge updates the button label when it works, and a failure message appears when it does not. Double taps are harmless, because the backend accepts any known status and setting the same status twice is idempotent.

## Non-goals

No retry, no optimistic update, no rollback logic (the cache only changes after the server answers), no change to the new-order SnackBar/chime logic, no translation here (see below), no export button.

## Tests written with the change

In `test/orders_page_test.dart`, using the seam and `MockClient`:
- Tapping the action button with a 500 or network error shows the failure SnackBar and the order's status is unchanged.
- Tapping it with a 200 shows no failure SnackBar and the status updates.
- The SnackBar "Accept" action with a failure shows the failure message.
- Existing tests pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Failure shows the message; success shows none | `make test` |
| Only `lib/restaurant/` touched | `make boundaries` |
| `make check` green | `make check` exit 0 (gate) |
| With the backend stopped, pressing Accept shows the message | owner acceptance at `http://restaurant.local` - "unverified" until done |

## Interaction with other cards

`orders_page.dart` is also edited by `vi-translate-shared-and-restaurant-ui`, `restaurant-orders-month-export-button`, `restaurant-menu-editing-page` and `comments-restaurant-and-dev`. Recommended: run this card before `vi-translate-shared-and-restaurant-ui` (a note there asks it to translate the new text). If it runs after, write the text in Vietnamese. The edits touch different parts of the file, so a conflict is unlikely, but run cards one at a time. Not a hard `blockedBy`.

## Executor notes (2026-11-17)

- **The owner ran it as `restaurent-…`:** the owner invoked the card as `docs/tasks/restaurent-orders-status-update-shows-failure.md` (no such file), so this card ran.
- **One method for both buttons:** `_OrdersPageState._changeStatus(id, status)` awaits `updateStatus` and catches `OrderRequestException` only. On failure, if still mounted, it shows the fixed SnackBar "Couldn't update the order. Try again.".
- **Both call sites use it:** the new-order SnackBar's "Accept" action and the card's action button. `_OrderCard` stays stateless and gets an `onChangeStatus` callback from the page (Goal 2).
- **Tests:** the repository seam (`setApiForTest`) is reset to a real client and an empty cache in `setUp`/`tearDown`.

---
task: shared-order-and-menu-models-toppings
status: passed
p0: 0
p1: 0
reviewedFiles:
  - lib/shared/models/display_text.dart
  - lib/shared/models/topping.dart
  - lib/shared/models/order.dart
  - lib/shared/models/menu_item.dart
  - lib/shared/api/order_api_client.dart
  - test/toppings_models_test.dart
  - test/order_parsing_test.dart
---

# Security review — shared-order-and-menu-models-toppings

Independent first-pass review by `security-reviewer` (tool-restricted, read-only), 2026-11-12.

## Scope

- **Assets:** the restaurant and customer screens, and the shared `OrderRepository` cache.
- **Attacker input:** any `POST /orders` body on the LAN. The server echoes it through `GET /orders` and the live stream to every client.

## Findings (first pass): P0 0 · P1 1 · P2 2

- **P1-1, one malformed order emptied the list for every client.** `OrderRepository.init` wraps `fetchOrders` in a catch-all, so a single order that throws while parsing dropped the whole initial list. The stricter id and toppings parsing adds ways to throw. Today's exposure is low because the backend validates the same shapes, but the two validators drifting apart, or old database rows, are plausible routes. **Fixed:** each order is parsed on its own and a bad one is skipped.
- **P2-1, the live stream lost data on a bad event:** it reconnected and threw away its buffer. **Fixed:** the stream now skips the event and carries on.
- **P2-2, order names weren't cleaned.** They're fully client-controlled, and a hostile order could carry U+202E, U+2028 or `\n` to fake a price line or reorder text in the restaurant view. **Fixed:** `displayText` is applied at parse time to the customer, item and topping names.
  - **Residual, deferred:** name length is unbounded. That's tracked by `backend-request-body-limit`.

## Checked with no issues found

- **`fetchToppings`:** status code, list body and duplicate-id checks.
- **Strict parsing:** `Topping.fromJson` is strict and cleans names; `_optionalId` rejects empty or non-string ids; a non-list `toppings` is rejected.
- **`displayText` coverage:** U+2028/2029, U+0085, C0/C1 controls, bidi controls and U+2060–2069.
- **Numbers:** NaN can't occur, because prices must be finite. Overflow to Infinity in a total is display-only, and covered by the accepted, tracked quantity cap.
- **Hidden characters:** a grep of `lib/` and `test/` for literal bidi, zero-width, U+2028/2029 and U+0085 characters found none.

## Re-review 1

**Still passed.** The P1 is resolved and both P2s are fixed. No new findings.

## Needs real-environment confirmation

How `quantity` parses as an `int` in Flutter web for a JSON value like `1e3` (JavaScript number semantics).

**Counts:** P0 0 · P1 0 · P2 1 open (name length, tracked by `backend-request-body-limit`).

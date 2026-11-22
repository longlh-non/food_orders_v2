---
task: shared-order-and-menu-models-toppings
status: passed
p0: 0
p1: 0
---

# Execute review — shared-order-and-menu-models-toppings

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-12. It ran in parallel with `security-reviewer`, and neither saw the other's conclusions. Security report: `docs/reviews/security-shared-order-and-menu-models-toppings.md`.

## Implementation notes

- **`lib/shared/models/display_text.dart` (new):** `displayText` was moved verbatim from `MenuItem`'s private `_displayText`. The file is ASCII only, and the menu tests still pass, so behaviour is unchanged.
- **`Topping {id, name, price}` (new):** strict `fromJson`. The name is cleaned with `displayText` and must have visible text. Equal by id.
- **`OrderTopping {String? id, name, price}`:** `toJson` omits a null id.
- **`OrderItem`** gains `menuItemId` (JSON `id`) and `toppings`:
  - `unitPrice` is the base price plus the toppings; `subtotal` is `unitPrice × quantity`; `Order.total` follows from that.
  - `toJson` adds `id` and `toppings` only when they're set, so a plain item is unchanged.
  - `fromJson` treats missing fields as an older order, and rejects bad ids or a non-list `toppings`.
- **`fetchToppings()`:** the same checks as `fetchMenu` (status code, list body, duplicate ids).

## Gates — first candidate

| Command | Exit |
|---|---|
| `make analyze` | **2** on the first run: the analyzer (`text_direction_code_point_in_literal`) caught a **literal** U+202E and U+200B in `test/toppings_models_test.dart`. The `\u` escapes in the input had become real characters. They were replaced with escapes, and a check confirms none remain in any file of this change. |
| `make analyze` | 0 |
| `make test` (130 = 101 + 29 new) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make backend-analyze` | 0 |
| `make backend-test` (129) | 0 |

## Findings (first pass): P0 0 · P1 0 · P2 2

- **P2-1:** order item and order topping names weren't cleaned for display. **Fixed** in the fix round, at parse time (see below), rather than carried to the restaurant card.
- **P2-2:** the old fields threw `TypeError` while the new ones throw `FormatException`. **Moot:** `_parseOrder` now catches both and skips just that order.

**Checked with no issues found:**
- The contract matches `CLAUDE.md` and the backend validator.
- The cart's `OrderItem(name:, quantity:, price:)` call still compiles.
- The price maths is right, and the tests compare with a tolerance (`closeTo`).

## Fix round 1

Triggered by the security review's P1 and two P2s (see the security report). All in shared scope, which is the card's scope:

1. **`fetchOrders` parses each order on its own** through a new static `_parseOrder`. A malformed order is skipped and logged in debug builds, instead of emptying the whole list.
2. **`streamUpdates` skips a bad event** (invalid JSON or a bad order) and carries on: no reconnect, and no lost buffer.
3. **`displayText` is applied at parse time** to `Order.customerName`, `OrderItem.name` and `OrderTopping.name`. It covers both `GET /orders` and the live stream, and isn't applied in `toJson`. A name left empty by cleaning is kept, so no order is dropped because of its name.

**New `test/order_parsing_test.dart`** (3 tests), written with escapes and confirmed to contain no literal invisible characters:
- a bad order is skipped and the good ones are kept;
- the stream skips bad events and delivers the next good one;
- customer, item and topping names are cleaned.

| Command | Exit |
|---|---|
| `make analyze` | 0 (after an interim `use_null_aware_elements` lint was fixed) |
| `make test` (133) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make check` (final candidate) | **0** (133 app tests, 129 backend tests) |

**Re-review 1 (code-reviewer):** resolved, no new findings. `placeOrder` and `updateStatus` still throw on a bad response, which is accepted as the right behaviour for a user action.

## Unverified

None: this card has no browser step.

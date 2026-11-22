---
task: customer-state-cart-lines-and-toppings
status: passed
p0: 0
p1: 0
---

# Execute review — customer-state-cart-lines-and-toppings

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-12. No security review: the card isn't flagged, and the diff adds no new parsing (toppings arrive through the already-reviewed `fetchToppings`).

**Language:** the card's lines 10 and 25 ("strings in Vietnamese") are superseded by its own later note, "Order change (owner, 2026-11-11)", which says English, because translation now runs afterwards. The reviewer agreed.

## Implementation notes

- **`CartLine(item, [toppings])`:**
  - Toppings are de-duplicated by id, keeping the order they were picked in.
  - `unitPrice` is the dish price plus the toppings.
  - Two lines are equal when the dish id and the **set** of topping ids match; the hash is consistent with that.
- **`Cart`:** a `Map<CartLine, int>`.
  - `add(item, toppings:)` merges into an identical line, and `remove(line)` works per line.
  - `itemCount` and `total` include toppings.
  - `refreshItems(menu, toppings)` drops a line whose dish **or** any topping is gone, counts repricing by unit price, and merges lines that collapse into one.
  - `toOrderItems()` sets the dish id and each topping id (TOP3), with the base `price`.
  - The old `items` getter was replaced by `lines`, and every caller and test was updated.
- **`MenuState`** loads the menu and toppings together (`Future.wait`, `eagerError`), with one loading state and one error state.
- **The cart page** shows a "+ topping" line, the unit price including toppings, and −/+ per line.

## Gates

| Command | Exit |
|---|---|
| `make analyze` | 0 |
| `make test` | **2** first: the request-count test expected 1 request per load, but it's now 2 (menu + toppings). It was adjusted to check that a second concurrent load adds none. The menu-page test helper now answers `/api/toppings` on its own, so the toppings request no longer silently receives menu JSON. |
| `make test` (148 = 133 + 15 new) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make backend-analyze` | 0 |
| `make backend-test` (129) | 0 |
| `make check` (final candidate, after the follow-ups) | **0** (149 app tests, 129 backend tests) |

## Findings: P0 0 · P1 0 · P2 6

- **P2-1:** `refreshItems` defaulted to no toppings, so a caller that left them out would silently drop every line with toppings. **Fixed:** `toppings` is now a required argument, and the callers were updated.
- **P2-2:** the refresh test didn't check a changed **name**. **Fixed:** it now does, for the dish and the topping.
- **P2-3:** the cart page test never pressed "−". **Fixed:** "−" on the plain line removes it and leaves the topping line alone. (Placing an order is covered by the unit test on `toOrderItems`, as the card allows.)
- **P2-4:** retry after a failed toppings load wasn't tested. **Fixed:** a new test shows it recovers.
- **P2-5:** the `MenuState` tests live in `cart_lines_test.dart`. **Accepted:** a style point only.
- **P2-6:** a long topping list wraps at phone width. **Owner acceptance:** check it in the browser.

The follow-ups were applied as the reviewer suggested, with no further round. One script stopped halfway on a pattern mismatch; it was redone with an all-or-nothing check, and every edit was confirmed applied.

**Checked with no issues found:**
- The ids are set when the cart builds the order, as TOP3 requires.
- `Future.wait` leaves no unhandled second error, and the error type is kept for the UI.
- The refresh's merging and counts are right, and the snackbar text still matches.
- The scope stays customer-only.

## Unverified (owner acceptance)

At `http://customer.local`: plain adds, −/+ per line, placing an order, and how a long topping line looks at phone width. Lines with toppings only appear once the add-dialog card lands.

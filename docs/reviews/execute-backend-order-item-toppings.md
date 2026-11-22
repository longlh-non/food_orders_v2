---
task: backend-order-item-toppings
status: passed
p0: 0
p1: 0
---

# Execute review — backend-order-item-toppings

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-12. It ran in parallel with `security-reviewer`, and neither saw the other's conclusions. Security report: `docs/reviews/security-backend-order-item-toppings.md`. Owner decision applied: TAB3, so items and toppings carry the menu `id` (optional until MENU-DB3).

## Implementation notes

- **Items** must have `{name, quantity, price}`, may have `{id, toppings}`, and nothing else (checked by the new helper `_hasKeys`). `id` must be a non-empty string.
- **`toppings`:** a list of at most 10 (`maxToppingsPerItem`). Each entry must have `{name, price}`, may have `id`, and nothing else; `name` is a string, `id` is non-empty, and `price` follows the same rule as item prices (`_isValidPrice`: finite, at least 0).
- **Errors** use fixed messages; the only value interpolated is the constant 10.
- **Storage:** orders are stored exactly as sent, with no schema change, and old orders aren't rewritten.
- **`CLAUDE.md`:**
  - Order rules: the optional `id` and `toppings`; prices on a line (the item's `price` is the base price, one unit costs base plus toppings, the line total is that times `quantity`); ids required later by MENU-DB3; what isn't checked until MENU-DB3.
  - Known limitations: "Prices are trusted from the client".

## Gates

| Command | Exit |
|---|---|
| `make backend-analyze` | 0 |
| `make backend-test` (128 = 107 + 21 new) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make analyze` | 0 |
| `make test` (101) | 0 |
| `make check` (final candidate, after the follow-ups below) | **0** (101 app tests, 129 backend tests) |

**Compatibility check (the security reviewer asked for one):** today's `OrderItem.fromJson` reads only `name`, `quantity` and `price`, and ignores extra keys. Both apps therefore tolerate `id` and `toppings` in the live order stream; they simply don't show the toppings yet (`restaurant-orders-show-toppings`). Orders from today's app, with no id and no toppings, stay valid.

## Findings: P0 0 · P1 0 · P2 4

- **P2-1:** `maxToppingsPerItem` is public only for the tests. **Fixed:** a doc comment now says so.
- **P2-2:** `CLAUDE.md` didn't say what goes unchecked before MENU-DB3. **Fixed:** one bullet now lists toppings on a non-topping dish, unknown ids, and no upper limit on quantity or price, and says that a repeated topping is allowed.
- **P2-3:** nothing pinned the duplicate-topping behaviour. **Fixed:** a new test accepts the same topping twice on one line (a double portion), bringing the suite to 129.
- **P2-4:** the item-shape error doesn't name the bad field. **Accepted:** it's still a fixed message that never echoes the request.

**Checked with no issues found:**
- The validation matches the card exactly.
- `CLAUDE.md` matches the code, including the line-total wording.
- Backward compatibility holds.
- A null `toppings` is rejected.
- No request text is echoed.

The follow-ups were tests and docs only, applied as the reviewers suggested, with no further review round.

## Unverified

None for this card: it has no browser step. Toppings become visible to users only through the later Flutter cards.

---
task: backend-menu-category-and-toppings
status: passed
p0: 0
p1: 0
---

# Execute review — backend-menu-category-and-toppings

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-10/11. It ran in parallel with `security-reviewer` on the same frozen candidate, and neither saw the other's conclusions. Security report: `docs/reviews/security-backend-menu-category-and-toppings.md`.

Owner decisions applied:
- CUR1: prices in VND.
- TOP2b: soda removed.
- TOP2c: an `allow_toppings` switch per dish.
- FOOD1: two separate Xôi trứng dishes.
- FOOD2: five `an-nhe-*` snacks (the toppings sold on their own).
- Seed data exactly as the owner listed it.

## Implementation notes

- **`database.dart`, step 2:** its seed list is renamed `seedMenuV2`. The values and the step's code are unchanged, because step 2 has already run on real databases.
- **`database.dart`, step 3** (one transaction, rolled back on error):
  - adds `category` (`food`/`snack`/`drink`) and `allow_toppings` (0/1) to `menu_items`;
  - creates `toppings`, with type and price CHECKs;
  - deletes the placeholder ids in `removedInStep3`, using bound parameters;
  - inserts `seedMenu` (25 items) and `seedToppings` (5) with `INSERT OR IGNORE`.
- **`menu_api.dart`:** `GET /menu` returns `category` plus `allowToppings`, which is true only when the category is `food` and `allow_toppings` is 1. New read-only `GET /toppings`.
- **`CLAUDE.md`:**
  - the API table rows for `/menu` and `/toppings`;
  - Storage: three tables, how the menu got there, a backup tip before upgrades, and the warning that a topping's price must also be changed on its matching snack;
  - new `sqlite3` examples using the real ids;
  - what the tables refuse.
- **Old test expectations, changed:** `user_version` 2 → 3 in the order tests, as the card asked. The planned test "a v2 database keeps a changed burger price" was replaced by "the owner's own items and orders survive; the placeholders are removed", following the later owner decision to remove the placeholders. The reviewer agreed.

## Gates — first candidate

| Command | Exit |
|---|---|
| `make backend-test` | **2**: the old tests ran against the new menu, which was expected. This revealed that shelf now sends `application/json; charset=utf-8` (Vietnamese text), so the content-type checks now use `startsWith('application/json')`. A first test-editing script aborted on a pattern mismatch without writing anything, and was redone with an all-or-nothing check. |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make analyze` | 0 |
| `make test` (51) | 0 |
| `make backend-analyze` | 0 |
| `make backend-test` (89) | 0 |

**Real-data check:** a copy of the owner's `backend/data/orders.db` (version 2, 2 orders, the 5 placeholders) was opened with `openDatabase` in the scratchpad. Result:
- version 3, and both orders kept;
- food 9, snack 7, drink 9, toppings 5, with exactly the owner's names and VND prices;
- 0 placeholders left.

The real file was untouched: same size and modification time.

## Findings: P0 0 · P1 0 · P2 3

- **P2-1:** stale lines in the card (category `food`/`drink` only; CUR1 and the food list still marked open). **Fixed:** updated, or marked superseded.
- **P2-2:** the `startsWith` content-type check is the right call. Optional: test a Vietnamese round trip. **Added:** "Vietnamese names come back from GET /menu unchanged".
- **P2-3:** step 3 is correct (transactional DDL, bound parameters, statements closed in `finally`, step 2 untouched). No change.

**Checked with no issues found:**
- The seed data matches the card's tables line by line (ids, names, prices, categories, `allowToppings`).
- The fresh-database path is v1 → v2 placeholders → v3 real menu.
- Client compatibility: `MenuItem.fromJson` ignores the new fields.
- Owner-added items keep their older rowids, so they're listed before the new rows. That's acceptable, but worth telling the owner.

## Re-review (fix round)

Changes were tests, `CLAUDE.md` and notes on other cards only; no backend code changed:
- **A new rollback test** (asked for by the security review): step 3 is forced to fail after both `ALTER TABLE`s. The test checks that the database stays at version 2 with no new columns, every placeholder still present, and the order kept. It passes.
- **The Vietnamese round-trip test.**
- **The backup tip** in `CLAUDE.md`.
- **Security P2-2 and P2-3 carried** to `shared-order-and-menu-models-toppings` and `backend-order-item-toppings`.

| Command | Exit |
|---|---|
| `make backend-analyze` | 0 |
| `make backend-test` (91) | 0 |

**Security re-review:** still passed, no P2s left open. The code reviewer's findings were all addressed as it suggested, with no further round.

## Final candidate

`make check` → **exit 0** (format, boundaries, analyze, 51 app tests, backend analyze, 91 backend tests).

## Unverified (owner acceptance)

- Back up the database, restart the backend so the real database upgrades, then run `curl http://customer.local/api/menu` and `/api/toppings` and check the Vietnamese names and prices.
- Until `currency-vnd-display` lands, the customer app shows these prices as `$25000.00` and similar. That's expected.

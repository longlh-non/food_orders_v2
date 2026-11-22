---
task: backend-menu-category-and-toppings
status: passed
p0: 0
p1: 0
reviewedFiles:
  - backend/lib/database.dart
  - backend/lib/menu_api.dart
  - backend/bin/server.dart
  - CLAUDE.md
---

# Security review — backend-menu-category-and-toppings

Independent first-pass review by `security-reviewer` (tool-restricted, read-only), 2026-11-10/11, on the same frozen candidate as the code review.

## Scope

- **Assets:** the owner's `orders.db` (orders, menu items, toppings), and the menu and topping text sent to clients.
- **Attacker-controlled input:** only the path and method of a request to the two GET routes. The owner's `sqlite3` edits are trusted but typo-prone.
- **New capabilities:** a read-only `/toppings`, two new `/menu` fields, and a destructive migration step.

## Checked with no issues found

- **SQL injection:** no request data reaches SQL. Both routes use constant `SELECT`s and never read the request. The step-3 `DELETE` builds only `?` placeholders from a constant list, and every value is bound.
- **No way to write through `Cascade`:** `MenuApi` registers only GET routes, and `OrdersApi` registers only the `/orders` routes. Both were confirmed by grep.
- **Rollback:** SQLite runs DDL and `user_version` inside the transaction. Now covered by a test: a failed step 3 leaves version 2, with no new columns, and nothing deleted.
- **CHECK coverage:** `category` and `allow_toppings` are constrained. Topping prices follow the same rule as menu prices. `/menu` forces `allowToppings` to false for anything that isn't food.
- **The `sqlite3` examples** in the docs: every `UPDATE` and `DELETE` has a `WHERE`, there's no `DROP`, and the quoting is correct.

## Findings: P0 0 · P1 0 · P2 3

- **P2-1** `database.dart:120`: the destructive `DELETE` by fixed id would remove an item if the owner had reused one of the placeholder ids for a real dish. That's acceptable for a one-time migration, and the copy of the real database showed only placeholders. **Addressed:** `CLAUDE.md` now tells the owner to back up before upgrading and names the deleted ids.
- **P2-2:** topping names are owner-edited free text. **Carried** to `shared-order-and-menu-models-toppings`: clean them like menu names, reject empty ones, plain `Text` only.
- **P2-3:** price integrity (MENU-DB3) gets slightly worse with toppings, and the snack and topping prices can drift apart. **Carried** to `backend-order-item-toppings`: MENU-DB3 must recompute every price by id and reject unknown ids.

## Re-review 1

**Still passed.** No write route under `/menu` or `/toppings`, the rollback test covers the request, and all three P2s are addressed or carried. Nothing open for this card.

**Counts:** P0 0 · P1 0 · P2 0 open (2 carried to other cards).

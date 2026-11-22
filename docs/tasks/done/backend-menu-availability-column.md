---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: [backend-menu-endpoint, backend-menu-category-and-toppings, backend-menu-category-nibble, backend-menu-image-column]
securityReview: required
---

# Add an `available` (sold-out) flag to the menu table and to GET /menu

First card of the M1 "staff edit the menu from the restaurant app" set (owner: M1 = yes). Contract first, read-only, no write endpoint yet.

**Revised 2026-11-10, renumbered 2026-11-11:** this is now schema step **6**. `backend-menu-category-and-toppings` took step 3, `backend-menu-category-nibble` (the 4th category "Ăn vặt", a table rebuild, category tabs request) takes step 4, and `backend-menu-image-column` takes step 5; all have priority over sold-out. `GET /menu` items already carry `category` (four values), `allowToppings` and `image` by now, so the documented shape is `{id, name, description, price, category, allowToppings, image, available}`. Version numbers below are updated; if more schema cards land first, use the next free number.

## Why

Staff need a "sold out" switch so a customer cannot order what the kitchen ran out of. That needs one new fact per menu item. Delete is the wrong tool for this (see MENU-EDIT1 in `backend-menu-staff-write-endpoint`). This card only adds the column and shows it; nothing can change it yet except the `sqlite3` CLI.

## Sources

`backend/lib/menu_api.dart` and the migration function (the `if version < 2` to `< 5` steps), `backend/test/menu_api_test.dart`, `CLAUDE.md` "Backend" table.

## Goal

1. `CLAUDE.md` -> "Backend" table (owner approval for this edit is requested by this card): `GET /menu` items become `{id, name, description, price, category, allowToppings, image, available}`, `available` is a JSON boolean. Say it is read-only here.
2. Add an `if version < 6` migration step: `ALTER TABLE menu_items ADD COLUMN available INTEGER NOT NULL DEFAULT 1 CHECK (available IN (0, 1))`, then `PRAGMA user_version = 6`, in one transaction. Existing rows become available. Idempotent like the earlier steps.
3. `GET /menu` returns `available` as `true`/`false` (convert from 0/1). Insertion order unchanged.
4. The test in the earlier cards that says a fresh file gets `user_version` 5 becomes 6; say so in the change notes (same pattern as before).

## Non-goals

Any write endpoint (next card), Flutter changes (old clients ignore the extra field), authentication, price rules.

## Tests written with the change

In `backend/test/menu_api_test.dart`:
- every item in `GET /menu` has a boolean `available`, all `true` after a fresh migration; `category` and `image` still present;
- a database at version 5 with a changed price and orders migrates to 6 and keeps the price, the rows, the categories (including `nibble`), the image names and the orders; running the migration twice changes nothing;
- a row set to `available = 0` directly in SQL shows `false` on the next `GET /menu`;
- fresh file ends at `user_version` 6; existing order and menu tests still pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Documented shape equals real response | `make backend-test` (gate) |
| Migration 5 -> 6 keeps data, runs once | `make backend-test` (gate) |
| Backend clean | `make backend-analyze` (gate) |
| Parameterised/constant SQL only, no new dependency | `security-reviewer` (review; endpoint + DB trigger) |
| `CLAUDE.md` table matches code | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| `curl http://customer.local/api/menu` shows `available` on a real database that was already at version 5 | owner acceptance in the real environment - "unverified" until done |

## Environment limits

Agents cannot run the real backend behind Caddy; the owner restarts it and runs the curl.

## Owner decisions and executor notes (2026-11-13)

- **Owner approval:** the owner chose to run this card, then `backend-request-body-limit`, then `backend-menu-staff-write-endpoint`, and approved the `CLAUDE.md` edits for all three.
- **Version tests:** every "latest version" test now says 6 (it said 5 after the image card). The step-4 and step-5 tests compare rows without both new columns (`image`, `available`). The version 4 test fixture drops both columns.
- **Docs:** `CLAUDE.md` also gets a `sqlite3` example for marking an item sold out, and the "What the tables refuse" line, because this card is the only way to change the column until the staff write endpoint exists.
- **Flutter side:** `MenuItem.fromJson` ignores unknown keys, so the apps keep working with the extra `available` field (no Flutter change, as the card says).

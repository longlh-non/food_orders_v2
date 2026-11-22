---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: [backend-menu-category-and-toppings, backend-menu-category-nibble]
securityReview: required
---

# Menu items get an optional `image` (a file name): schema step 5 and `GET /menu`

First card of the "menu item images" set. Contract first, read-only, no Flutter change, no file serving yet (that is `backend-menu-image-file-serving`, next).

**Renumbered 2026-11-11 (category tabs request):** this was schema step 4; `backend-menu-category-nibble` (the 4th category, a table rebuild) now takes step 4 and runs first, so this card is step **5** and ends at `user_version` 5. All version numbers below are updated. `GET /menu` items by now carry `category` with four possible values. If more schema cards land first, use the next free number. Nothing of this card was started.

## Why

The owner wants a picture per menu item (the grid tile has a placeholder block waiting for it). The database needs one new fact per item: which image file belongs to it.

## Decisions this card carries (owner to confirm, recommended answers)

- **IMG1, what the column stores:** a plain **file name** such as `burger.webp`, not a URL and not the picture itself. The files live in one folder on the backend machine (`backend/data/images/`) and the backend serves them at `/api/images/<file-name>` (next card). Why: the page and the pictures come from the same address, so there is no CORS, no mixed-content (`http` image on an `https` page) problem, no third-party site learning who looks at the menu, no broken-link rot, and nothing extra to allow in a Content-Security-Policy. It also works unchanged behind Caddy locally and on the VM. Rejected: (a) a full external URL: every customer's browser would contact someone else's server, links die, and the app would be putting database text into a network request. (c) picture bytes in the database: the file doubles in size, every backup and every `GET /menu` carries them, and the owner cannot just copy a file.
- **IMG3, no photo is normal:** the column is nullable. `GET /menu` always has the key `image`: a string or `null`. `null` means "show the placeholder".
- **IMG4, scope:** menu items only. Drinks are menu items (category `drink`), so they get it for free. Toppings get no image.

## Sources

`backend/lib/database.dart` (steps 1 to 4), `backend/lib/menu_api.dart`, `backend/test/menu_api_test.dart`, `CLAUDE.md` "Backend" table, "Storage", "Editing the menu".

## Goal

1. `CLAUDE.md` (owner approval for the edit is requested by this card), in this order:
   - "Backend" table: `GET /menu` items become `{id, name, description, price, category, allowToppings, image}`, with `image` a string file name matching `^[a-z0-9][a-z0-9-]{0,63}\.(jpg|jpeg|png|webp)$` or `null`. Say it is a file name, not a URL, and that the picture itself is served by a later row.
   - "Storage" and "Editing the menu": describe step 5 and the column; the `sqlite3` examples `UPDATE menu_items SET image = 'burger.webp' WHERE id = 'burger'` and `UPDATE menu_items SET image = NULL WHERE id = 'burger'`; lowercase letters, digits and `-` only, one of the four extensions (an iPhone photo called `IMG_1234.JPG` must be renamed). Mention that setting the name does nothing visible until the file is in the images folder (see the serving card).
2. `database.dart`: `if (db.userVersion < 5)` step, in one transaction, ending with `db.userVersion = 5`: `ALTER TABLE menu_items ADD COLUMN image TEXT CHECK (image IS NULL OR (typeof(image) = 'text' AND length(image) BETWEEN 5 AND 80 AND image NOT GLOB '*[^a-z0-9.-]*'))`. Existing rows get `NULL`. The executor confirms the installed SQLite accepts a CHECK on `ADD COLUMN` and records it; if not, use the table-rebuild pattern (as step 4 does) and say so. No image values are seeded (no sample pictures are committed).
3. The database check above is the coarse guard (character set and length, so a hand edit cannot put `/`, `..`, spaces or `%` in). The **exact** pattern is enforced in code: `GET /menu` returns `image` only when the stored value matches the full regex, otherwise `null`. Put the regex in one place (a small exported constant/function in `backend/lib/`) so the serving card reuses it.
4. `menu_api.dart`: select `image`, return it as string or `null`. Insertion order unchanged.
5. Tests that said a fresh file ends at `user_version` 4 (after `backend-menu-category-nibble`) now say 5 (change notes, same pattern as earlier migrations).

## Non-goals

Serving files, any write endpoint, upload, Flutter changes (old clients ignore the extra field), image variants/thumbnails, topping images.

## Tests written with the change

In `backend/test/menu_api_test.dart` (in-memory database per test):
- every `GET /menu` item has the key `image`, `null` on a fresh database; array shape and order unchanged;
- after `UPDATE ... SET image = 'burger.webp'` the next GET returns `"burger.webp"`; `SET image = NULL` returns `null`;
- direct SQL refused by the CHECK: `'../x.png'`, `'a/b.png'`, `'a b.png'`, `'%2e%2e.png'`, `''`, a number, a 200-character name;
- a value that passes the CHECK but not the exact regex (`'Burger.webp'` is refused by the CHECK; use `'burger.gif'` and `'.hidden.png'`) is returned as `null` by `GET /menu`;
- a version 4 database with a changed price, an owner item (including one in category `nibble`) and an order migrates to 5 and keeps them; migrating twice changes nothing; a fresh file ends at version 5.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Documented shape equals the real response | `make backend-test` (gate) |
| Migration 4 -> 5 keeps data, runs once | `make backend-test` (gate) |
| Bad values refused by the table and never leaked by the endpoint | `make backend-test` (gate) + `security-reviewer` (review; endpoint, DB, trust of hand-edited data) |
| Backend clean, no new dependency | `make backend-analyze` (gate) + empty `pubspec.yaml` diff (code-reviewer) |
| `CLAUDE.md` matches code | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| `curl http://customer.local/api/menu` on the owner's real database shows `"image": null`; after the `sqlite3` UPDATE it shows the name | owner acceptance in the real environment, "unverified" until done |

## Environment limits

Agents cannot run the real backend behind Caddy or the `sqlite3` CLI; the owner restarts the backend and runs the curls.

## Owner decisions and executor notes (2026-11-13)

- **Owner approval:** the owner confirmed IMG1, IMG3 and IMG4 as recommended, chose to run this card before `backend-menu-image-file-serving`, and approved the `CLAUDE.md` edits for both cards.
- **SQLite:** the installed SQLite accepts a CHECK on `ALTER TABLE ... ADD COLUMN`, so no table rebuild was needed. The "table refuses ..." tests prove the CHECK is active.
- **The rule:** the exact name rule lives in `backend/lib/menu_image.dart` (`menuImageName`, `isValidImageName`), ready for the serving card.
- **Step-4 tests:**
  - They now end at version 5, because step 5 runs too.
  - The "same menu before and after" test reads the version 3 rows from the table, since today's `GET /menu` selects `image`.
  - The "keeps every row" test compares rows without the new `image` column and checks it's NULL.
- **Flutter side:** `MenuItem.fromJson` ignores unknown keys, so the customer app keeps working with the extra `image` field (no Flutter change, as the card says).

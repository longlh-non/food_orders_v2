---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: [docs-menu-add-contract]
securityReview: required
---

# Backend: staff-only `POST /menu` (add a menu item)

## Why

Today a new dish needs the `sqlite3` CLI. Staff should add one from the restaurant app. This card is the server half and nothing else: the contract is already in `CLAUDE.md` (previous card), UI comes later.

## Sources

`CLAUDE.md` API table row for `POST /menu`; `backend/lib/menu_api.dart` (`PATCH /menu/<id>`, `_readSmallBody`, `_menuEditProblem`, `_itemJson`); `backend/lib/staff_gate.dart`; `backend/lib/menu_image.dart` (`isValidImageName`); `backend/lib/database.dart` (`menu_items` CHECKs: category in four values, price number 0 to 1e9, allow_toppings 0/1, image coarse CHECK, available 0/1); existing menu API tests in `backend/test/` (copy their in-memory-database and gate setup); review `docs/reviews/security-restaurant-menu-editing-page.md` and `docs/reviews/security-backend-menu-staff-write-endpoint.md` if present, for what the reviewer looked at last time.

## Goal

Add `router.post('/menu', ...)` in `menu_api.dart`:

1. `_gate.check(req)` first (so 401/403/429 never read the body, and a disabled gate gives 403: fail closed). Then `_readSmallBody` (4 KB, 413), `jsonDecode` (400 on `FormatException`), then a new `_newItemProblem(decoded)` returning a **fixed** message (never echoing request text), like `_menuEditProblem`. Rules as in the contract; unknown keys are 400 (so `id`, `available` can't be sent); wrong types are 400 (`allowToppings: "yes"`, `price: "5"`, `price: 1e999`/NaN, fractions, negative, above `maxMenuPrice`).
2. Id: made on the server by a small pure function (new file `backend/lib/menu_slug.dart`, so it is unit-testable): lowercase the name, map Vietnamese letters to plain ones with a hand-written table (no new dependency; `đ`→`d`, `ă â ê ô ơ ư` and tone marks stripped), turn every run of anything else into one `-`, trim `-`, cut to 48 characters (cut then trim `-` again). The result must pass `^[a-z0-9][a-z0-9-]*$`. A name that gives an empty slug (Lao, emoji, only symbols) uses `item`. On collision with an existing id add `-2`, `-3` ... until free (cap the loop at, say, 1000, then 409). The id must never be one that breaks the picture-name or URL rules: only `[a-z0-9-]`. Stable once made (CLAUDE.md "Keep ids stable").
3. Cap (ADD4): `SELECT count(*) FROM menu_items` at or above `maxMenuItems` (300) answers 503 "Menu is full" (fixed text).
4. Duplicate (ADD3): same category and same name after trim and case-fold (ASCII lower plus the same Vietnamese folding as the slug, so "Xôi Thịt" and "xoi thit" clash) answers 409 with a fixed message. Check, cap, id pick and INSERT run inside one `BEGIN IMMEDIATE ... COMMIT` (roll back on any error) so the sqlite file stays consistent even with the sqlite3 CLI writing at the same time; the busy wait already set on the handle applies.
5. Insert with bound parameters only (name, description, price, category, `allow_toppings` 0/1, `image`, `available` = 1). Reply **201** with `_itemJson(row)` re-read from the table, header `Cache-Control: no-store`, `Content-Type: application/json`.
6. Doc comments on the new route and function, in the style of the PATCH route. Update the class doc ("the one write" is no longer true). Add `maxMenuItems`, `maxMenuNameUnits`, `maxMenuDescriptionUnits` constants next to `maxMenuPrice`.
7. No schema step: every rule is already enforceable in code and the existing CHECKs are looser, so nothing in `database.dart` changes (do not edit shipped steps).

## Non-goals

Rename, delete, editing description/category/image of an existing item, image upload or checking that the image file exists, price check against anything, client or UI code, any new package.

## Tests written with the change

`backend/test/menu_add_test.dart` and `backend/test/menu_slug_test.dart` (in-memory database, a real `StaffGate` with test credentials, as the PATCH tests do):

- slug: ASCII, Vietnamese with tone marks and `đ`, symbols only, emoji/Lao only, very long name, double spaces, leading/trailing symbols; every output matches the id rule.
- 201 with the full item shape; new item appears last in `GET /menu`; `available: true`; defaults for description and allowToppings; `image: null`.
- `allowToppings: true` accepted for food, 400 for snack/drink/nibble.
- 400: not JSON, JSON array, empty object, unknown key (`id`, `available`, `paymentDueAt`), missing name/price/category, empty or whitespace name, name over limit (counted in UTF-16 units: an emoji counts 2), control character in name, description over limit, bad types, price negative/fraction/over limit/string/huge, unknown category, image with `/`, `..`, capitals, `.gif`, a URL, a non-string.
- 401 wrong password, 401 missing headers, 403 gate disabled (no usable credentials), 429 after repeated wrong tries; in each case nothing is inserted, and the body is not read (a huge body with wrong password still answers 401, not 413).
- 413 for a body over 4 KB (declared and chunked); nothing inserted.
- 409 duplicate name (case and accent differences, same category); same name in another category is allowed and gets a suffixed id (`xoi-2` style); id collision with a hand-inserted row gets the next suffix.
- 503 at the cap (seed the table up to `maxMenuItems`).
- A failed request leaves the table unchanged (count before/after); price sent as `25000` and `25000.0` both store 25000.
- SQL-looking names (`'); DROP TABLE menu_items;--`) are stored as plain text and the table survives.
- Existing `GET /menu`, `PATCH /menu/{id}` and `/toppings` tests still pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour and every status code above | `make backend-test` (gate) |
| Analyzer and format clean | `make backend-analyze`, `make format-check` (gates) |
| Gate before body read; fixed error texts; bound parameters only; id can't escape `[a-z0-9-]`; no secret in logs or replies | `security-reviewer` (review, `docs/reviews/security-backend-menu-staff-add-endpoint.md`) |
| Implementation matches the CLAUDE.md table row | `code-reviewer` (review) |
| No new dependency (empty `pubspec` diffs) | `code-reviewer` (review) |
| `make check` exit 0 | gate |
| Real call: `curl -X POST ... http://customer.local/api/menu` with the staff headers, then the item shows in `customer.local` | owner acceptance (needs the running backend and real credentials, agents can't) |

## Environment limits

Agents can't run the backend with real credentials or Caddy. Do not edit `CLAUDE.md` here (the previous card did). Never print or log the staff ID or password. First `dart test` may need network for the sqlite binary (see CLAUDE.md).

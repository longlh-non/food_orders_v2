---
executor: task-executor
scopes: [docs]
workKinds: [documentation]
blockedBy: []
---

# Docs: write the `POST /menu` contract into CLAUDE.md (before any code)

**Needs explicit owner approval to edit `CLAUDE.md`** (Safety policy; approval does not carry over from other tasks). Running this card with that approval given in the message is the approval. Without it, stop and report.

## Why

Architecture invariant 3: the API table changes first, then the backend, then the client. This card is only the table, so the backend card has a written contract to build against and the review has something to compare to.

## Sources

`CLAUDE.md` ("Backend" API table, "Editing the menu", "Staff ID and password", "Known limitations"), `backend/lib/menu_api.dart` (the PATCH route it mirrors), the decisions below.

## Goal

Edit `CLAUDE.md` only:

1. API table: add a `POST /menu` row, **staff only** (`X-Staff-Id` + `X-Staff-Password`). Body: `{"name": string, "description"?: string, "price": number, "category": "food"|"snack"|"drink"|"nibble", "allowToppings"?: bool, "image"?: string|null}`, nothing else (so a client can never send `id` or `available`). Rules (use the values the owner chose in ADD1 to ADD9, defaults below):
   - `name`: after trimming, 1 to 100 UTF-16 units, no control characters.
   - `description`: optional, default `""`, at most 500 units, no control characters other than newline.
   - `price`: whole number 0 to 1,000,000 (same as PATCH).
   - `category`: required, one of four.
   - `allowToppings`: optional, default `false`; `true` only with `category: food` (else 400).
   - `image`: optional, `null` or a name passing the shared picture-name rule. The file is **not** checked to exist.
   - The new item starts **available**. The server makes the `id` (ADD1) and returns it.
   - Replies: **201** the new item (same shape as `GET /menu` items) with `Cache-Control: no-store` · 400 invalid body · 401 / 403 / 429 as the staff gate (checked first, before the body is read) · 409 an item with the same name in the same category already exists (ADD3), or no free id could be made · 413 body over 4 KB · 503 menu is full (ADD4).
   - Check order: staff gate, body size, JSON, field rules, menu cap, duplicate name, insert.
2. "Editing the menu": say that **adding** an item can now be done from the restaurant app (or `curl`), while rename and delete still need `sqlite3`. Keep the sqlite3 examples.
3. "Staff ID and password": add `POST /menu` to the list of staff routes.
4. Remove or reword the line "Adding, renaming or deleting items still needs `sqlite3`" and "There's no editing screen yet" so they stay true (the screen exists since `restaurant-menu-editing-page`).

## Non-goals

Any code, `runbook-local.md` (own card), rename/delete/image upload.

## Tests written with the change

None (docs only).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Table row lists every status code and the check order above | `code-reviewer` (review, read against the backend card) |
| No other part of CLAUDE.md changed | `code-reviewer` (review: diff) |
| Owner agrees with the recorded limits and the 201 | owner acceptance |

## Environment limits

None. No gate covers prose; `make format-check` is unaffected.

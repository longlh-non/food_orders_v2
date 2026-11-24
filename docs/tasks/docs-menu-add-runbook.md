---
executor: task-executor
scopes: [docs]
workKinds: [documentation]
blockedBy: [restaurant-menu-add-form]
---

# Docs: owner steps for adding a menu item from the restaurant app

## Why

Staff and owner need the real steps (including the one thing the app can't do: put the picture file into the images folder).

## Sources

`docs/runbook-local.md` (existing menu and staff sections), `CLAUDE.md` "Editing the menu" (already updated by `docs-menu-add-contract`; read, do not edit), the finished behaviour of the three code cards.

## Goal

Edit `docs/runbook-local.md` only (`CLAUDE.md` is not touched here, so no approval is needed):

1. A short "Add a menu item" section: open the restaurant app, menu button, add button, fill the form, enter the staff ID and password, check on `customer.local`.
2. What the id will look like (made from the name, `xoi-ga`, with `-2` if taken) and that it never changes.
3. The picture: copy the file to `backend/data/images/` first (name rule: lowercase letters, digits, `-`, `.webp/.jpg/.jpeg/.png`), then type the same name in the form; the app doesn't check the file exists and an unknown name just shows the placeholder.
4. What the errors mean (same name already in the category, menu full at 300 items, too many wrong tries, editing disabled) and that rename/delete/changing description or picture of an existing item still need `sqlite3` (link the existing commands).
5. A line saying a dated backup before bigger menu edits is still advised.

## Non-goals

CLAUDE.md edits, code, screenshots.

## Tests written with the change

None (docs only).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Steps match the shipped behaviour and limits | `code-reviewer` (review) |
| Owner can follow the steps end to end | owner acceptance |

## Environment limits

No gate covers prose. Walking the steps needs the real backend and browser: owner acceptance, "unverified" until done.

---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: [qr-static-api-contract]
---

# Backend: the `STATIC_QR_IMAGE` setting (this card replaced the "QR payload function" idea; the slug is historical)

Planned 2026-11-26, rewritten the same day after the owner's design change (2026-11-26): the QR of the second transfer option is a **third-party payment service's QR supplied as an image**, so the backend builds **no** QR text and there is no `vietQrStaticPayload`. The slug `qr-static-backend-payload` is kept only because other cards list it in `blockedBy`.

## Sources

`backend/lib/shop_settings.dart` (how `SHOP_*` and `BANK_*` are read and validated, the startup lines), `backend/lib/menu_image.dart` (the shared picture-name rule), `backend/lib/images_api.dart` (how the images folder is found, and how folders, symbolic links and big files count as missing), `backend/bin/server.dart` (startup lines), `backend/test/shop_settings_test.dart` and the images tests.

## Goal

A new setting **`STATIC_QR_IMAGE`**: the file name of the QR picture the owner copied into the images folder (`IMAGES_DIR`, default `backend/data/images/`, the same folder `GET /images/{file}` serves).

- Read from the environment **when the backend starts**, like the other settings. Not a secret. Spaces around the value are ignored; empty = unset. A control character inside the value makes it invalid.
- **Valid** means the value matches the picture-name rule in `menu_image.dart` (`^[a-z0-9][a-z0-9-]{0,63}\.(jpg|jpeg|png|webp)$`; reuse that function, do not copy the regex).
- **Enabled** (`staticQrEnabled`, name is a suggestion) means: valid **and** the file exists in the images folder as a **regular file** (not a folder, not a symbolic link, not over 1 MiB), by the same check the images route uses (share the check, don't duplicate it). A missing file = disabled.
- The existence is checked **at start** (for the startup line) **and again each time it is asked** (so the owner can copy the file in without a restart; the name itself still needs a restart). The check is cheap and read-only.
- It does **not** need the `BANK_*` values; they stay only for the old, suspended `bank_transfer`. A missing or invalid value switches off only this feature and never stops the backend.
- Startup line: `static QR transfer: enabled` or `static QR transfer: disabled (missing or invalid: STATIC_QR_IMAGE)`. Never print the value or the folder path.
- Where it lives: in `shop_settings.dart` (a new field next to the others) or one new small class beside it; choose the smaller change. Expose the file name when enabled and a way to ask "enabled now?" that takes the images folder.
- Nothing reads it yet; `qr-static-backend-schema-and-create` wires it into `GET /payment-info` and `POST /orders`.

## Non-goals

Routes, schema, any QR drawing or payload code, any Flutter code, resizing or uploading the picture.

## Tests written with the change

- valid names (`qr-thanh-toan.png`, `a.webp`, `qr2.jpeg`) with the file present -> enabled, name returned.
- invalid names -> disabled, never an exception: capitals, `/`, `..`, spaces, `%`, no extension, `.gif`, `.svg`, a name over 64 + extension, a control character inside.
- empty or whitespace-only value, and not set -> disabled; leading/trailing spaces are trimmed.
- valid name but no file -> disabled; the file is then created in a temp folder -> enabled on the next ask (no restart).
- a **folder** with that name, a **symbolic link** with that name, and a file over 1 MiB -> disabled, same as the images route.
- the five `SHOP_*` and four `BANK_*` settings behave exactly as before (existing tests stay green); this setting works with every `BANK_*` value unset.
- the startup line text for enabled and for disabled, and that neither prints the value (test the line-building function, as the existing startup tests do).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make backend-test` (gate) |
| `make backend-analyze`, `make format-check` | gates, exit 0 |
| Picture-name rule and file check shared, not copied | `code-reviewer` (review) |
| The real server starts with the owner's file and prints `enabled` | owner acceptance, "unverified" until done |

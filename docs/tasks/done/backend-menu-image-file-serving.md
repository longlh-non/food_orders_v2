---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: [backend-menu-image-column]
securityReview: required
---

# Backend serves menu pictures: `GET /images/{file}` from one folder

Second card of the "menu item images" set. The backend learns to hand out the files named in `menu_items.image`. No Flutter change.

## Why

The column only holds a name. Something must return the bytes from the same address the app already uses (`/api/...`, which Caddy already forwards to the backend), so nothing in `dev/**` or the production Caddyfile has to change.

## Decisions this card carries (recommended answers)

- **IMG2, who puts files there, and where:** the owner copies photos into `backend/data/images/` and sets the column with `sqlite3`. There is **no upload screen or upload endpoint**: uploading needs auth, size/type checks on incoming bytes and a write path, a much bigger and riskier card, deferred on purpose (it would follow the staff-token work). The folder is under `backend/data/`, which is already git-ignored: owner photos are never committed, and no sample pictures are committed (the grid shows the placeholder until the owner adds one). Override the folder with `IMAGES_DIR=/path` (a compiled binary must set it, like `ORDERS_DB`). The server creates the folder at start if missing; an empty or missing folder just means every image answers 404.
- **IMG5, deploy:** the folder is real data like the database. See the note added to `deploy-production-config`.
- **IMG6, formats and size:** `jpg`, `jpeg`, `png`, `webp` only (no `svg`: it can carry script; no `gif`). The server refuses files over **1 MiB** (answers 404). Advice to the owner in `CLAUDE.md`: webp or jpg, about 800 px wide, ideally under 200 KB; the tile crops to fit. No server-side resizing for now (it would need an image library, a new dependency needing approval).
- **Why not `shelf_static` or Caddy `file_server`:** `shelf_static` is a new dependency (owner approval; and its path handling is more than we need). A Caddy static block splits the picture folder away from the backend, needs `dev/**` edits for dev plus nginx, and different config in deploy. A 40-line handler in the backend with a strict file-name pattern is smaller and easier to review.

## Sources

`backend/lib/menu_api.dart`, `backend/bin/server.dart` (Cascade of APIs; unknown paths fall through), the file-name regex from `backend-menu-image-column`, `dev/Caddyfile` and `dev/nginx.conf` (both strip `/api` and forward everything under it: no change needed), `CLAUDE.md` "Backend", "Storage".

## Goal

1. `CLAUDE.md` (approval requested by this card), table first: row `GET /images/{file}` -> 200 the picture with its `Content-Type` · 400 the name does not match the pattern · 404 no such file (also: not a regular file, or over 1 MiB). Then "Storage"/"Editing the menu": the folder, the `IMAGES_DIR` variable, how to add a picture (copy the file, run the `sqlite3` UPDATE), the size advice, "no upload; back up the folder together with the database", and a note that replacing a photo under the same name can look stale for up to 5 minutes in a browser, so use a new file name when changing a photo.
2. New `backend/lib/images_api.dart` with class `ImagesApi(Directory dir)`, built like `MenuApi` (shelf_router, `late final Handler handler`):
   - route `GET /images/<file>`; the value is checked **after** URL-decoding against `^[a-z0-9][a-z0-9-]{0,63}\.(jpg|jpeg|png|webp)$` (the one shared regex); no match -> 400 with a fixed plain message that does not echo the input;
   - the path is `dir` + a validated name only; raw request text is never joined into a path; no directory listing; no other route;
   - before reading: the entry must be a regular file and not a symbolic link (`FileSystemEntity.typeSync(path, followLinks: false)`), size at most 1 MiB, else 404;
   - `Content-Type` from a fixed extension map (`image/jpeg`, `image/png`, `image/webp`), never guessed from content or the request; `X-Content-Type-Options: nosniff`; `Cache-Control: public, max-age=300`;
   - read errors answer 404, never a stack trace or a path.
3. `server.dart`: resolve the folder like the database path (default `backend/data/images` relative to the script, `IMAGES_DIR` override, empty value counts as unset), create it, add `ImagesApi(dir).handler` to the Cascade (before `OrdersApi`, which stays last), and print the folder next to the database line.

## Non-goals

Upload or delete endpoints, resizing or thumbnails, ETag/conditional requests, CDN, Flutter changes, any change to `dev/**` or the Caddyfile, a restaurant-side picture screen.

## Tests written with the change

New `backend/test/images_api_test.dart`, handler called directly with `Request`, a temp directory per test (deleted afterwards):
- valid names for each of the four extensions -> 200, exact bytes, right `Content-Type`, `nosniff`, `Cache-Control` present;
- missing file -> 404;
- traversal and bad names -> 400 and nothing outside the folder is read: `../secret.png`, `..%2Fsecret.png`, `%2e%2e/secret.png`, `%2e%2e%2fsecret.png`, `%252e%252e`, `/etc/passwd`, `C:\x.png`, `a/b.png`, a name with a NUL (`%00`), `burger.png%00.txt`, `Burger.PNG`, `burger.gif`, `burger.svg`, `burger`, `.png`, `.hidden.png`, `a..b.png`, a 100-character name; a file placed **outside** the folder is never returned by any of them;
- a symbolic link inside the folder pointing outside -> 404 (skip with a clear reason on a platform that cannot create links);
- a file of 1 MiB + 1 byte -> 404; a directory named `x.png` -> 404;
- a POST/PUT/DELETE to `/images/burger.png` is not served (404/405);
- `bin/server.dart` wiring is checked by the owner (below), but the folder-resolving helper (default, override, empty override) gets a unit test if it is a separate function.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Documented responses equal real responses | `make backend-test` (gate) |
| Traversal, encoded tricks, absolute paths, wrong extensions refused; nothing outside the folder is readable | `make backend-test` (gate) + `security-reviewer` (review; file serving is the main risk of this set) |
| No new dependency | empty `pubspec.yaml` diff (code-reviewer) |
| Backend clean | `make backend-analyze` (gate) |
| `CLAUDE.md` matches code | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| Put a real photo in `backend/data/images/`, restart the backend, open `http://customer.local/api/images/<name>` and see it; `http://customer.local/api/images/..%2Forders.db` is refused | owner acceptance in the real environment, "unverified" until done |

## Environment limits

Agents cannot run the real backend behind Caddy or add the owner's photos; the owner does it.

## Owner decisions and executor notes (2026-11-13)

- **Owner approval:** the owner confirmed IMG2, IMG5 and IMG6 as recommended (with IMG1, IMG3 and IMG4 on the column card) and approved the `CLAUDE.md` edits for this card.
- **URL decoding:** `shelf_router` 1.1.5 hands the handler the still-encoded path segment. The handler decodes it with `Uri.decodeComponent` (malformed `%` answers 400), then applies `isValidImageName`.
- **Paths with real `..` or `/` segments:** for example `/images/../secret.png`, which is normalised by URL parsing or doesn't match the one-segment route. These never reach the handler and answer 404, not 400. The tests check that no secret is ever returned for them. Every single-segment trick (`..%2F`, `%2e%2e`, `%252e`, NUL, capitals and so on) answers 400.
- **Cascade:** `ImagesApi` sits between `MenuApi` and `OrdersApi`. Its own 404 lets Cascade fall through to `OrdersApi`, which also answers 404, so the status is the same but the body text differs. A 400 stops the cascade.

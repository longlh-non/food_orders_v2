---
task: backend-menu-image-file-serving
status: passed
p0: 0
p1: 0
---

# Review: backend-menu-image-file-serving

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-backend-menu-image-file-serving.md`.

## Candidate

- **`backend/lib/images_api.dart` (new):** `ImagesApi(Directory)` with `GET /images/<file>`.
  - **Name check:** URL-decode the name (shelf_router passes it still encoded), then check it with the shared `isValidImageName`. A bad name answers 400 with the fixed body "Invalid image name".
  - **Path and file checks:** the path is folder + validated name only. The entry must be a regular file and not a link (`typeSync(followLinks: false)`), at most 1 MiB (checked before and after reading). Otherwise 404 "Image not found", and read errors also answer 404.
  - **Headers:** content type from a fixed map, `nosniff`, `Cache-Control: public, max-age=300`.
  - **Folder helper:** `imagesDirPath` (`IMAGES_DIR`, where empty counts as unset; default `backend/data/images`).
- **`backend/bin/server.dart`:** creates the folder, adds `ImagesApi` to the Cascade between `MenuApi` and `OrdersApi`, and prints the folder.
- **`backend/test/images_api_test.dart` (new):** 47 tests.
- **`CLAUDE.md` (owner-approved edit):**
  - the `GET /images/{file}` table row and a Code bullet;
  - under Editing the menu: adding a picture, size and format, changing a photo (new file name, because of the 5-minute cache), and no upload, so back up the folder with the database.

Owner decisions (2026-11-13): IMG2, IMG5 and IMG6 as recommended. The `CLAUDE.md` edits were approved for this card.

Deviation, accepted by the reviewer: paths with real `..` or `/` segments answer 404, not 400. URL normalisation or the one-segment route stops them before the handler. The tests assert exactly 404 and that nothing outside the folder is returned.

## Round 1: changes requested. P0 0, P1 1, P2 3

- **P1:** `Uri.decodeComponent` throws `FormatException` (not `ArgumentError`) for escapes that aren't valid UTF-8 (`%FF`, `%C0%AF`, `%E1`). The handler only caught `ArgumentError`, so the request would answer 500.
- **P2:** the Cascade comment in `server.dart` didn't mention that a missing picture falls through to `OrdersApi`'s 404 body.
- **P2:** the check-then-read gap and the synchronous reads weren't documented as accepted risks.
- **P2:** the multi-segment tests asserted `400 or 404` instead of the 404 that actually happens.

## Fix round 1

- **P1:**
  - A Dart probe confirmed `FormatException` for invalid UTF-8 and `ArgumentError` for `%zz`.
  - shelf itself refuses to build a `Request` for invalid-UTF-8 URLs, and shelf_io answers them before any handler runs, so the path wasn't reachable in practice.
  - The handler now catches `FormatException` too, as a safety net, and 3 tests assert shelf refuses those URLs.
- **P2s:**
  - the Cascade comment is extended;
  - an "Accepted risk" comment covers the check-then-read gap and synchronous reads;
  - the multi-segment tests assert exactly 404.

## Re-review 1: passed. P0 0, P1 0, P2 0

## Deferred follow-ups

- **Docs (security, optional):** say in `CLAUDE.md` that the images folder must stay writable by the owner only.
- **Optional hardening:** async reads, or a cap on concurrent image reads, if traffic ever grows.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make backend-analyze` (round 1 and after fixes) | 0 |
| `make backend-test` (246 tests, then 249 after fixes) | 0 |
| `make format-check` (round 1 and after fixes) | 0 |
| `make boundaries` (round 1 and after fixes) | 0 |
| `git diff --stat backend/pubspec.yaml` (empty) | 0 |
| `make check` (final candidate; 208 app + 249 backend tests) | 0 |

## Unverified (owner acceptance)

- Put a real photo in `backend/data/images/` and restart the backend (after a dated backup: the database moves to version 5).
- Open `http://customer.local/api/images/<name>` and see the photo.
- `http://customer.local/api/images/..%2Forders.db` is refused (through Caddy).

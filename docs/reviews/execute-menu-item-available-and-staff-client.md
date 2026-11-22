---
task: menu-item-available-and-staff-client
status: passed
p0: 0
p1: 0
---

# Review: menu-item-available-and-staff-client

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-menu-item-available-and-staff-client.md`.

## Candidate

- **`lib/shared/models/menu_item.dart`:** `MenuItem.available`, defaulting to true.
  - `fromJson`: a missing key means true (older backend); a present non-bool (including null) throws `FormatException('menu item available must be true or false')`.
  - Equality is still by id.
- **`lib/restaurant/api/menu_admin_client.dart` (new):**
  - `MenuAdminClient.updateItem(id, {required token, price?, available?})` sends `PATCH /api/menu/<encoded id>` with `X-Staff-Token`; the body holds only the given fields.
  - It throws `ArgumentError`, without sending anything, when no field is given or the id is empty, `.` or `..`.
  - Failures come back as `MenuAdminException(MenuAdminFailure, message, statusCode)`: 400 `invalid`, 401 `wrongToken`, 403 `editingDisabled`, 404 `notFound`; anything else (another status, a network error, an unreadable 200) is `other`.
  - The message is fixed text plus the status, never the token or the reply.
  - Restaurant-only (not in `lib/shared/`); the token is never stored.
- **Tests:**
  - `test/menu_item_test.dart`: a group "available (sold out)".
  - `test/menu_admin_client_test.dart` (new): request shape, body fields, id encoding, refused ids, no fields, the status mapping (400/401/403/404/413/500), a network error, bad 200 replies, and that the token is absent from errors (the mocked bodies deliberately contain it).

## Round 1: passed. P0 0, P1 0, P2 2

- **P2-1:** an id of exactly `.` or `..` (or empty) isn't changed by `encodeComponent`, and could be normalised to another path. **Fixed:** refused with `ArgumentError` before sending, with 3 tests.
- **P2-2:** only `http.ClientException` is caught for transport errors (that's what `BrowserClient` throws). **Deferred:** `restaurant-menu-editing-page` should confirm it in a real browser.

Confirmed:
- Goals 1–3;
- the per-call `token:` argument meets the card;
- the error mapping matches the card;
- nothing else constructs `MenuItem` and loses `available` (only the constructor and `fromJson`);
- no vacuous tests;
- the style matches `OrderRequestException`.

## Re-review 1 (security reviewer, on the fix): passed. P0 0, P1 0, P2 0

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` (round 1 and after fixes) | 0 |
| `make test` (296 tests, then 299 after fixes) | 0 |
| `make format-check` (round 1 and after fixes) | 0 |
| `make boundaries` (round 1 and after fixes) | 0 |
| `git diff --stat pubspec.yaml` (empty) | 0 |
| `make check` (final candidate; 299 app + 306 backend tests) | 0 |

## Unverified

No browser step in this card. Nothing calls the client yet. The real request through Caddy and nginx (the header passing, and transport errors in the browser) is checked by `restaurant-menu-editing-page`.

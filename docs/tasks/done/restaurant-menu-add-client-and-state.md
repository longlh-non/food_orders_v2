---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [backend-menu-staff-add-endpoint]
securityReview: required
---

# Restaurant: `addItem` in `MenuAdminClient` and `MenuAdminState`

## Why

The page needs something to call. Keeping the client and the state in their own card, with no widgets, means the HTTP contract is exercised by tests before any screen exists. `securityReview: required` because it parses a server reply and sends the staff credentials on a new route.

## Sources

`CLAUDE.md` `POST /menu` row; `lib/restaurant/api/menu_admin_client.dart` (`updateItem`, `MenuAdminFailure`, `MenuAdminException`); `lib/restaurant/state/menu_admin_state.dart` (`_save`, `MenuSaveError`, `MenuSaveResult`, `parseMenuPrice`); `lib/restaurant/state/staff_credentials.dart`; `lib/shared/models/menu_item.dart`; existing tests `test/restaurant/` for the client and state (fake `http.Client`, fake clients).

## Goal

1. **Client.** `Future<MenuItem> addItem(NewMenuItem draft, {required StaffCredentials credentials})`, restaurant-only. `NewMenuItem` is a small immutable class in `menu_admin_client.dart` (name, description, price int, category `MenuCategory`, allowToppings, image `String?`) with a `toJson()` that sends only those keys (and `image` only when set). Same safety as `updateItem`: `ArgumentError` without sending when credentials aren't sendable; fixed exception messages; never the credentials or reply text in an error. `POST` to `/api/menu` (constant path, no user text in the URL). Accepts **201** (and treats other 2xx as `other`); parses with `MenuItem.fromJson`, `FormatException`/`TypeError` -> `other`. Add `MenuAdminFailure.duplicate` (409) and `MenuAdminFailure.menuFull` (503); 413 maps to `invalid`. Existing 400/401/403/429 mapping and `Retry-After` unchanged.
2. **State.** `Future<MenuSaveResult> addItem(NewMenuItem draft)`: same rules as `_save` (credentials from the holder else `needsCredentials`; 401 clears the holder; a single `isAdding` flag, a second call while adding is `ignored`; on success append the server's item to `items`; on failure items are unchanged and `saveError` is set). Add `MenuSaveError.duplicate` and `MenuSaveError.menuFull`. Pure helper `validateNewItem(...)` (top-level, like `parseMenuPrice`) that checks the same limits as the server (name 1 to 100 after trim, description at most 500, price via `parseMenuPrice`, `allowToppings` only for food, image through the shared `menuImageName`) and returns an enum of the first problem or null, so the form can show a message without a request. The constants live next to `maxMenuPrice`. Update the exhaustive `switch` in `_save` for the new failure values (they can't occur there; map them to `other`).
3. Keep `StaffCredentialsHolder` as is. No new package; no change to `lib/shared/`.

## Non-goals

Widgets, strings, ARB files, rename/delete, image upload, caching the draft.

## Tests written with the change

- Client (fake `http.Client`): request is `POST /api/menu` with JSON body of exactly the draft keys, both staff headers, content type; 201 returns the item; mapping 400/401/403/409/413/429 (with `Retry-After`)/503/500; no answer -> `other`; malformed 201 body -> `other`; unsendable credentials -> `ArgumentError` and no request; exception text contains neither the ID nor the password.
- State (fake clients): success appends and keeps order; each failure keeps the list and sets the matching `saveError`; 401 clears the holder and returns `needsCredentials`; no credentials -> `needsCredentials` with no request; double call ignored; disposed state doesn't notify; `isAdding` true during the call.
- `validateNewItem`: every limit at the edge and one past it; emoji name counts as 2 units; image rule; toppings with non-food.
- Existing `updateItem` / `setPrice` / `setAvailable` tests unchanged and green.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Client and state behave as listed | `make test` (gate) |
| Analyzer and format clean | `make analyze`, `make format-check` (gates) |
| Restaurant imports nothing from customer | `make boundaries` (gate) |
| Credentials only sent in headers, never kept, printed or in errors; reply parsed defensively | `security-reviewer` (review) |
| No new dependency, still plain `ChangeNotifier` | `code-reviewer` (review) |
| `make check` exit 0 | gate |

## Environment limits

Fakes only; agents can't reach a real backend. No user-visible text here (the state exposes enums, the page translates them).

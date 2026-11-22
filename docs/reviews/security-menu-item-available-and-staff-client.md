---
task: menu-item-available-and-staff-client
status: passed
p0: 0
p1: 0
---

# Security review: menu-item-available-and-staff-client

Independent reviewer: `security-reviewer` (read-only). It reviewed the same candidate as `execute-menu-item-available-and-staff-client.md`.

- **Assets:** the staff token, and the integrity of `MenuItem`s built from server replies.
- **Attacker inputs:** 200 and non-200 reply bodies, and the item id (it comes from the server menu).
- **Boundary:** the restaurant browser → same-origin `/api/*`.

## Round 1: passed. P0 0, P1 0, P2 1

Checked and clean:
- **Token leaks:**
  - the token is used only in the request header;
  - `MenuAdminException` messages and `toString` hold fixed text and the status;
  - the `ClientException`'s message and URL are discarded;
  - reply bodies are never copied;
  - no logging.
- **No token storage:** a per-call argument; the class holds only the HTTP client.
- **Same origin:** `Uri(path: '/api/menu/...')` has no scheme or host, and `encodeComponent` escapes `/ ? # : @ %` and backslash, so an id can't add a host, query or fragment.
- **Catches:** `jsonDecode` and `MenuItem.fromJson` throw only `FormatException`; `TypeError` is extra cover.
- **Hostile 200 body:** `fromJson` validates every field (names cleaned, price finite and ≥ 0, category, toppings for food only, image name pattern).
- **`available` parse:** strict (`containsKey`, so null isn't treated as missing).
- **Boundaries:** the client is restaurant-only and imports only the shared model. No dependency.

P2:
- An id of `.` or `..` would be sent as a dot segment and could be normalised to another same-origin path. The impact is a wrong or failed PATCH; the token can't leave the origin.

## Fix

Ids that are empty, `.` or `..` are refused with `ArgumentError` before any request; 3 tests.

## Re-review 1: passed. P0 0, P1 0, P2 0

- The check runs before the URL is built or the token used.
- There's no bypass: `%2e%2e` is encoded to `%252e%252e`, which stays one literal segment.

## Gates

See `execute-menu-item-available-and-staff-client.md`. `make check` exits 0.

## Needs real-environment confirmation (later card)

`restaurant-menu-editing-page`: the PATCH with `X-Staff-Token` through Caddy and nginx in a browser.

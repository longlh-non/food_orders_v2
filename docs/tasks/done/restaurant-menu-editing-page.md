---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [menu-item-available-and-staff-client, customer-menu-sold-out-items, vi-translate-shared-and-restaurant-ui, restaurant-staff-id-password-clients]
securityReview: required
---

# Restaurant app: menu editing screen (change price, sold-out switch)

> Amended 2026-11-19: the staff credential is now a shared staff ID + password (`STAFF_ID`, `STAFF_PASSWORD`, headers `X-Staff-Id` / `X-Staff-Password`), not a token. Everywhere below that says "token" means this pair. Use the holder from `restaurant-staff-id-password-clients` (`StaffCredentialsHolder`); do not build another. Handle 429 ("too many tries") as well as 401 and 403.

## Why

M1: staff edit the menu from the restaurant app. Last card of the set; it is the first thing the owner can click.

Ordering with translation: this card runs AFTER `vi-translate-shared-and-restaurant-ui` (it edits `orders_page.dart` for the navigation button, the same file that card rewrites, so running it second avoids a merge conflict) and writes its new strings in Vietnamese directly (VI1/VI2), so no later translation pass is needed. Wording is drafted by the agent and accepted by the owner. It also runs after `customer-menu-sold-out-items` so the switch has a visible effect when first tried.

## Sources

`lib/restaurant/pages/orders_page.dart` (AppBar actions), `lib/restaurant/main.dart`, `lib/restaurant/api/menu_admin_client.dart` and `MenuItem` (previous card), `lib/restaurant/state/staff_credentials.dart`, `lib/shared/api/order_api_client.dart` (`fetchMenu`), `lib/customer/state/menu_state.dart` as a style example only (restaurant cannot import customer, invariant 1; the restaurant gets its own small state).

## Goal

1. A restaurant-only `ChangeNotifier` (e.g. `lib/restaurant/state/menu_admin_state.dart`, plain `ChangeNotifier`, constructor takes the clients so tests can fake them): loads the menu with `fetchMenu` (loading / error / loaded, retryable, second load while loading ignored); reads the staff ID and password from `StaffCredentialsHolder` (memory only: lost on reload, on purpose: staff re-enter them; nothing in `localStorage`/cookies); `setPrice(id, price)` and `setAvailable(id, value)` call `updateItem` and replace the item from the server reply. While a row is saving it is disabled; on failure the row keeps its old value and an error message is shown. 401 clears the credentials and asks again; 403 shows "editing is disabled on the server"; 429 shows "too many tries, wait a minute".
2. A `MenuEditPage` reached from an AppBar button on `OrdersPage` (plain `Navigator.push`, no router package). Asks for the staff ID and password once in a dialog (ID plain, password obscured, not pre-filled except from the holder, neither shown in any message; reuse the export dialog's fields/widget if practical) before the first save. List: name, current price, an "edit price" action (dialog with a numeric field, rejects empty / non-number / negative / above 1,000,000 before sending, shows two decimals like the rest of the app) and a sold-out `Switch`. Loading spinner, error + Retry, empty state.
3. Existing `OrdersPage` behaviour (chime, badge, snackbar) unchanged; the new button must not break the existing restaurant widget test.

## Decisions carried (owner)

- MENU-EDIT1: only price and sold-out here. Add/rename/delete are not in this card (recommended; write them later if wanted: server-generated ids, soft-hide instead of delete).
- MENU-EDIT0 shared-secret option (b) must be accepted, otherwise this card is rewritten. Since 2026-11-19 the owner chose one shared staff ID + password instead of a token (same option, different shape).
- Go-live: this card does not change the rule that editing is blocked until the runbook supplies `STAFF_ID` and `STAFF_PASSWORD` (see the backend gate card).

## Non-goals

Add/rename/delete, images, categories, live push to customers, login/accounts, remembering the credentials, order-page redesign, customer changes, backend changes.

## Tests written with the change

Widget and unit tests in `test/` with fake clients (no network):
- state: loading -> loaded, loading -> error -> retry; `setPrice` success replaces the item; failure keeps the old value and surfaces an error; 401 clears the credentials; 403 and 429 messages; double tap on a saving row ignored;
- page: renders items with prices and switches; toggling a switch calls `updateItem` with the right fields; the price dialog rejects invalid input without calling the client and sends a valid one; the credentials dialog appears before the first save, the password field is obscured; neither the ID nor the password string is found anywhere in the widget tree after saving;
- `OrdersPage`: the menu button navigates to the page; existing orders-page tests pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| State and page behave as listed | `make test` (gate) |
| Restaurant imports nothing from customer | `make boundaries` (gate) |
| Analyzer, format clean | `make analyze`, `make format-check` (gates) |
| Credentials only in memory, never rendered/logged; input validated before sending | `security-reviewer` (review; credentials trigger) |
| No new dependency, no router/state package | `code-reviewer` (review: empty `pubspec.yaml` diff) |
| `make check` green | `make check` exit 0 (gate) |
| Vietnamese wording and layout acceptable | owner acceptance at `http://restaurant.local` - "unverified" until done |
| Backend started with `STAFF_ID` and `STAFF_PASSWORD`; on `restaurant.local` change a price, then reload `customer.local` -> the new price shows | owner acceptance in the real environment (Caddy path) |
| Toggle sold-out -> reload `customer.local` -> item shows sold out, Add disabled; toggle back -> addable | owner acceptance in the real environment |
| Wrong ID or password -> asks again; backend started without the variables -> "editing disabled" | owner acceptance in the real environment |
| Works on the tablet/phone browser staff will use | owner acceptance on the device - optional |

## Environment limits

Agents cannot run the backend with real credentials, the browser, Caddy, or a phone. The owner chooses and exports `STAFF_ID` and `STAFF_PASSWORD`. Agents never run `sudo`.

## Deviation recorded 2026-11-23 (found while executing)

The Goal's "two decimals" for prices is a leftover from the USD era. Prices are whole VND and are shown only with `formatVnd` ("25.000 VNĐ"), as `CLAUDE.md` says; the price dialog takes plain whole digits (0 to 1,000,000) and rejects "25.000". Implemented that way, and the reviewer agreed.

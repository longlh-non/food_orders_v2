---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [backend-orders-month-export-endpoint]
securityReview: required
---

# Restaurant app: "Export month" button that downloads the month's CSV

Planned 2026-11-12 (owner: EXP3 = b, EXP1 = pick the month, EXP2 = CSV now). Security review because it handles the staff token and downloads customer data.

## Why

Staff get the month's orders as a spreadsheet from the restaurant app, with no terminal.

## Design (plain words, with the trade-off)

- An icon button in the `OrdersPage` AppBar (tooltip "Export month") opens a small dialog:
  - **Month:** a dropdown of the current month and the 11 before it, newest first, current month selected (EXP1). Built from the device date, formatted `YYYY-MM`. Only these values can be sent.
  - **Staff token:** a password field (obscured), kept **in memory only** for this page session so staff type it once per visit. Never `localStorage`, never a cookie, never in a URL, never logged or shown in an error. A page reload forgets it.
  - Buttons "Cancel" and "Download".
- Download: `GET /api/orders/export?month=…` with header `X-Staff-Token`, then save the bytes as `orders-YYYY-MM.csv` through the browser (a `Blob` and a temporary link, `package:web`, which the project already uses). The web-only code sits behind a conditional import like `lib/shared/chime.dart` (stub on the VM), so `flutter test` still compiles.
- Errors in the dialog, short and fixed: 401 "Wrong staff token" (clears the remembered token), 403 "Export is turned off on the server", 400/other/network "Couldn't export. Try again." The dialog stays open on error.
- New text in **English**, like the rest of the restaurant UI today; `vi-translate-shared-and-restaurant-ui` translates it if it runs later.
- **Restaurant-only code** (invariant 2): the HTTP call lives in `lib/restaurant/` (e.g. `lib/restaurant/api/export_client.dart`, optional `http.Client` for tests, token passed per call, not stored by the client). The in-memory token holder (e.g. `lib/restaurant/state/staff_token.dart`) is reused later by the menu editing page (`restaurant-menu-editing-page`), so keep it small and generic.

## Sources

`lib/restaurant/pages/orders_page.dart` (AppBar), `lib/shared/chime.dart`, `chime_stub.dart`, `chime_web.dart` (conditional-import pattern), `lib/shared/api/order_api_client.dart` (HTTP style, `/api` base), `CLAUDE.md` -> "Backend" (the export row added by the endpoint card).

## Goal

The button, dialog, client, token holder and download as designed. Chime, badge, SnackBar, status buttons and the toppings lines unchanged. Fits at 360 px and text scale 2.0.

## Non-goals

`.xlsx` (separate card), any backend change, choosing a date range other than one month, storing the token across reloads, the menu editing page.

## Tests written with the change

- Client (MockClient): sends `GET /api/orders/export?month=2026-11` with the token header; returns the bytes on 200; maps 401/403/400/500 and network errors to typed errors; the token never appears in an error message or `toString`.
- Dialog (widget tests, fake client, download function injected so no browser API runs):
  - opens from the AppBar button; the month list has 12 entries, newest first, current month selected (fixed `now` injected);
  - Download with a token calls the client once with the chosen month and passes the bytes and `orders-YYYY-MM.csv` to the download function, then closes;
  - 401 shows "Wrong staff token", stays open and clears the remembered token; 403 and other errors show their messages;
  - Cancel and dismiss call nothing;
  - the token is remembered for a second export in the same session;
  - fits at 360 px, text scale 1.3 and 2.0.
- Existing orders-page tests still pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour above | `make test` (widget and client tests) |
| No import across apps; web-only code behind the conditional import | `make boundaries`, `make analyze` (gates) |
| Token only in memory, never logged/shown/put in URLs; no new dependency | `security-reviewer`, `code-reviewer` (reviews) |
| `make check` green | `make check` exit 0 (gate) |
| On `http://restaurant.local`: pick a month, type the token, the CSV downloads and opens in Excel; wrong token shows the error; on the staff phone/tablet the download works (iOS Safari may open the file in a preview first) | owner acceptance - "unverified" until done |

## Environment limits

Agents cannot click a browser download or open Excel; the owner does.

## Executor notes (2026-11-19)

- **Files, all restaurant-only:**
  - `lib/restaurant/api/export_client.dart`: `ExportClient.fetchMonth(month, {required token})`; `ExportFailure` = `wrongToken` / `disabled` / `other`; `ExportException`. It refuses a non-`YYYY-MM` month before sending.
  - `lib/restaurant/state/staff_token.dart`: the `StaffTokenHolder.instance.value` singleton, memory only.
  - `lib/restaurant/download/save_file.dart`: a conditional export of `save_file_stub.dart` (VM; throws `UnsupportedError`) and `save_file_web.dart` (`Blob` + temporary hidden `<a download>`, then revoked).
  - `lib/restaurant/pages/export_month_dialog.dart`: `showExportMonthDialog(context, {client, saveFile, now})` and `recentMonths(now)`.
  - The `orders_page.dart` AppBar gets an `IconButton` (`Icons.download`, tooltip "Export month").
- **Small choices:**
  - "Download" stays disabled until a token is typed, and while a request runs.
  - The month dropdown is disabled while busy.
  - The error text is a live region for screen readers.
  - The remembered token pre-fills the obscured field.
  - The MIME type is `text/csv;charset=utf-8`.
- **New English strings for `vi-translate-shared-and-restaurant-ui`:** "Export month", "Month", "Staff token", "Download", "Cancel", "Wrong staff token", "Export is turned off on the server", "Couldn't export. Try again.".

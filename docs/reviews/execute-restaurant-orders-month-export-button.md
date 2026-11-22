---
task: restaurant-orders-month-export-button
status: passed
p0: 0
p1: 0
---

# Review: restaurant-orders-month-export-button

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-restaurant-orders-month-export-button.md`.

## Candidate

All restaurant-only; nothing in `lib/shared/`.

- **`lib/restaurant/api/export_client.dart` (new):** `ExportClient.fetchMonth(month, {required token})` and `close()`.
  - It refuses a non-`YYYY-MM` month before sending.
  - It sends `GET /api/orders/export?month=` with `X-Staff-Token` (never in the URL).
  - 401 → `wrongToken`, 403 → `disabled`, anything else or no answer → `other`.
  - The message is fixed text plus the status.
- **`lib/restaurant/state/staff_token.dart` (new):** `StaffTokenHolder`, in memory only.
- **`lib/restaurant/download/save_file.dart` (new):** a conditional export, like `chime.dart`.
  - `save_file_stub.dart` (VM) throws.
  - `save_file_web.dart` uses a `Blob` and a hidden `<a download>`, and revokes the URL after 10 s.
- **`lib/restaurant/pages/export_month_dialog.dart` (new):** `showExportMonthDialog` and `recentMonths`.
  - **Fields:** a month dropdown (12 months, newest first); an obscured token field pre-filled from memory (no autofill, no IME learning).
  - **Download:** disabled while empty or busy.
  - **Success:** remember the token, save `orders-YYYY-MM.csv`, close.
  - **Failures:** 401 clears the token and shows "Wrong staff token"; 403 "Export is turned off on the server"; anything else "Couldn't export. Try again.".
  - Its own client is closed when the dialog closes.
- **`lib/restaurant/pages/orders_page.dart`:** an AppBar `IconButton` "Export month".
- **`test/export_month_test.dart` (new):** 22 tests.
- **`docs/runbook-local.md`:** a bullet that the token crosses the wifi in plain text (security P2).

## Round 1: passed. P0 0, P1 0, P2 5

- **P2-1:** a failure in `saveFile` (or any non-`ExportException`) left the dialog stuck busy. **Fixed:** an `on Object` catch resets it and shows the fixed message, with a test.
- **P2-2:** a dismiss during the request still downloaded. Now moot for the real client: closing it aborts the request. Accepted for injected clients.
- **P2-3:** `revokeObjectURL` right after `click()` can cancel downloads on some Safari versions. **Fixed:** revoked after 10 s.
- **P2-4:** the default `ExportClient` was never closed. **Fixed:** `close()`, called in `whenComplete`.
- **P2-5:** the month-list test used `toSet()`. **Fixed:** it also asserts a non-selected month appears once.

Confirmed:
- every item on the card's Design, Goal and test list;
- `recentMonths` across a year end;
- the `initialValue` API;
- the controller lifecycle and `mounted` checks;
- the chime, badge, SnackBar, status buttons and toppings lines unchanged;
- the conditional import pattern;
- no new dependency.

## Re-review 1: passed. P0 0, P1 0, P2 0

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` (first run: one unnecessary-import info in the new test, fixed) | 2, then 0 |
| `make test` (324 tests, then 325 after fixes) | 0 |
| `make format-check` (round 1 and after fixes) | 0 |
| `make boundaries` (round 1 and after fixes) | 0 |
| `git diff --stat pubspec.yaml` (empty) | 0 |
| `make check` (final candidate; 325 app + 327 backend tests) | 0 |

## Unverified (owner acceptance)

On `http://restaurant.local`, with the backend running with `STAFF_TOKEN`:
- pick a month, type the token, and the CSV downloads and opens in Excel;
- a wrong token shows the error;
- the browser doesn't offer to save the token;
- on the staff phone or tablet, the download works (iOS Safari may preview first).

New English strings, for `vi-translate-shared-and-restaurant-ui`: "Export month", "Month", "Staff token", "Download", "Cancel", "Wrong staff token", "Export is turned off on the server", "Couldn't export. Try again.".

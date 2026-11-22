---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: []
---

# Backend: shop and bank settings read from the environment at startup

Planned 2026-11-19, updated the same day. Part of the payment-method and two-report-export plan (owner decision 4: shop info and bank details live in backend settings, never committed). This card only reads, checks and reports on the settings. No route uses them yet; the next cards do (`backend-order-payment-method`, `backend-payment-qr-endpoint`, `backend-report-summary-xlsx`).

## Why

The summary report needs the shop's name, tax code, address, business location and the representative's name. The bank-transfer QR needs the bank, account number and account holder, and the customer page shows them as text too. All of it is the owner's real data, so it must not live in the repo. `STAFF_ID` / `STAFF_PASSWORD` already work this way (`backend/lib/staff_gate.dart`, printed in `backend/bin/server.dart`); this follows the same pattern.

## Sources

`backend/lib/staff_gate.dart` (pattern: fail closed, trimmed values, never print values), `backend/bin/server.dart` (startup lines), `CLAUDE.md` -> "Backend" -> "Staff ID and password".

## Goal

New `backend/lib/shop_settings.dart` with a small immutable class `ShopSettings`, built from a `Map<String, String?>` (so tests pass a map; `bin/server.dart` passes `Platform.environment`). Every value is trimmed; an empty value counts as unset.

| Variable | Used for | Rule |
|---|---|---|
| `SHOP_NAME` | report line 1 (the full text, e.g. the "HỘ KINH DOANH ..." line) | 1-200 characters |
| `SHOP_TAX_CODE` | "Mã số thuế: ..." | 1-20 characters, digits and `-` only |
| `SHOP_ADDRESS` | "Địa chỉ: ..." | 1-200 characters |
| `SHOP_LOCATION` | "Địa điểm kinh doanh: ..." | 1-200 characters |
| `SHOP_REPRESENTATIVE` | the name under "NGƯỜI ĐẠI DIỆN HỘ KINH DOANH" | 1-100 characters |
| `BANK_BIN` | the bank's 6-digit NAPAS code (e.g. 970436 is Vietcombank; the owner looks up his own) | exactly 6 digits |
| `BANK_ACCOUNT` | account number | 1-19 digits |
| `BANK_ACCOUNT_NAME` | account holder name, shown to the customer | 1-100 characters |
| `BANK_NAME` | the bank's name, shown to the customer as text next to the QR (PAY7, decided by the owner 2026-11-19: "7. Yes") | 1-100 characters |

- Text values may contain Vietnamese letters (unlike the staff ID, which is plain ASCII because it travels in an HTTP header; these never do). A value with a control character (newline, tab, NUL) is invalid, so a pasted newline can never break a report or a log line.
- Two flags: `reportEnabled` (all five `SHOP_*` valid) and `transferEnabled` (all four `BANK_*` valid, `BANK_NAME` included). A missing or invalid value turns only its feature off; nothing crashes at startup.
- `String describe()` for the startup printout: `shop details for reports: enabled` or `disabled (missing or invalid: SHOP_TAX_CODE, ...)`, and the same for `bank transfer`. Only variable **names** are printed, **never values**, not even lengths. `bin/server.dart` prints both lines next to the `staff routes:` line.
- `bin/server.dart` builds one `ShopSettings` and keeps it for the cards that follow (no use yet beyond printing).

## Non-goals

Any route, any use of the values, a settings file, hot reload (a change needs a backend restart, like the staff password), documentation in `CLAUDE.md` / the runbook (card `docs-payment-and-reports`).

## Tests written with the change

`backend/test/shop_settings_test.dart`:
- all values valid -> both flags true; values read back unchanged, Vietnamese letters intact (`Lê Văn Hưng`);
- each variable missing / empty / spaces only -> its feature off and its name in `describe()`; the other feature unaffected (a missing `BANK_NAME` turns transfer off);
- tax code with a letter, BIN with 5 or 7 digits or a letter, account with 20 digits, a value with `\n`, over-long values -> invalid;
- `describe()` never contains any configured value (set distinctive values and assert none appear).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Rules and flags as listed | `make backend-test` (gate) |
| Backend clean, no new dependency | `make backend-analyze` (gate) |
| No value (or its length) is ever printed or logged | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| Starting the real backend with the real values prints `enabled` for both; with none set prints `disabled` and the names | owner acceptance - "unverified" until done |

## Environment limits

Agents never put the owner's real tax code, address or bank account in a file, a test or a log. Tests use obviously fake values.

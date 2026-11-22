---
task: backend-shop-settings
status: passed
p0: 0
p1: 0
---

# Execute review: backend-shop-settings

Date: 2026-11-19. Reviewer: `code-reviewer` (independent, read-only, first pass). No security review: the card sets none and the diff adds no endpoint, JSON parsing, dependency, network exposure or CI change.

## Candidate

- `backend/lib/shop_settings.dart` (new): `ShopSettings` reads `SHOP_NAME`, `SHOP_TAX_CODE`, `SHOP_ADDRESS`, `SHOP_LOCATION`, `SHOP_REPRESENTATIVE`, `BANK_BIN`, `BANK_ACCOUNT`, `BANK_ACCOUNT_NAME` and `BANK_NAME` from a map. Values are trimmed, empty means unset, and control characters are rejected. It has two flags (`reportEnabled`, `transferEnabled`), and `describe()` prints variable names only.
- `backend/test/shop_settings_test.dart` (new).
- `backend/bin/server.dart`: imports the class, builds one `ShopSettings(Platform.environment)` and prints `describe()` after the `staff routes:` line. Only these three additions. The other uncommitted changes in this file are from earlier work and outside this review.

## Gates

Run by the executor in this session, from the repo root, on the candidate as reviewed.

| Command | Exit code | Output tail |
|---|---|---|
| `make backend-analyze` | 0 | `No issues found!` |
| `make backend-test` | 0 | `+385: All tests passed!` |
| `make format-check` | 0 | `Formatted 62 files (0 changed)` |

## Findings

P0: none. P1: none.

P2, deferred as follow-up hardening. They're not required by the card. They're written down here and can be done together with `backend-payment-qr-endpoint`, the next card to read these values:

1. `backend/lib/shop_settings.dart:3`: the control-character class does not include U+2028 or U+2029 (line and paragraph separator). One in the middle of a value passes. Suggested fix: add both to the class, with a test.
2. `backend/test/shop_settings_test.dart:98-127`: no test case for DEL (`\x7F`) or a C1 character (`\u0085`), although the code rejects both. Suggested fix: add two `SHOP_NAME` cases.
3. `backend/test/shop_settings_test.dart:129`: the exact-limit test doesn't cover `SHOP_ADDRESS`, `SHOP_LOCATION`, `SHOP_REPRESENTATIVE` or `BANK_NAME`. Low risk, because other fields already catch an off-by-one. Suggested fix: add the four maximum and 1-character cases.

## Checked and correct (summary)

- The rules match the card's table.
- The flags are independent of each other.
- `describe()` is built only from fixed names, and a test checks that it never contains a value.
- The server change is minimal, with no new dependency and no route.
- The tests cover the card's list.

## Unverified (owner acceptance)

Starting the real backend with the real values should print `enabled` on both lines. With none set, it should print `disabled` and the variable names.

## Final gate before archiving

| Command | Exit code | Output tail |
|---|---|---|
| `make check` | 0 | format-check `0 changed`, analyze clean, `boundaries: ok`, Flutter and backend tests `All tests passed!` (backend +411) |

Run 2026-11-19 in this session on the final candidate, with no fix round needed. The tree also held the frozen `backend-xlsx-writer` candidate at the time. Card moved to `docs/tasks/done/`.

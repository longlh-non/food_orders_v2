---
task: restaurant-menu-add-client-and-state
status: passed
p0: 0
p1: 0
---

# Review: restaurant-menu-add-client-and-state

## Gates

| Command | Exit | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | 732 tests, re-run after the P2 edits below |
| `make backend-analyze` | 0 | |
| `make backend-test` | 0 | |
| `make analyze` / `make check` | 2 | 28 baseline `deprecated_member_use` infos, unchanged; `make check` stops at analyze |

One small edit outside the two named files: the `_saveErrorText` switch in `lib/restaurant/pages/menu_edit_page.dart` maps the new `duplicate` / `menuFull` values to the existing `menuSaveFailed` text (needed to compile; no new strings).

## Findings (code-reviewer): P0 0, P1 0, P2 5

`validateNewItem` has no mismatch with the server rules; the client maps 201/400/401/403/409/413/429/503 as the card says.

- Fixed: comments naming `backend/lib/menu_api.dart` next to the duplicated constants; doc comments on `MenuAdminException` and the result enum now mention `addItem`.
- Deferred: no test pinning the duplicated constants (100, 500, 1,000,000); `toJson` sends the name untrimmed (kept, per the card; the server trims); the dispose test has no explicit listener counter; no state test for credentials the client refuses to send.

## Security review: `docs/reviews/security-restaurant-menu-add-client-and-state.md`

## Unverified

Nothing was tested against a real backend (fakes only).

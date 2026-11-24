---
task: restaurant-menu-add-form
status: passed
p0: 0
p1: 0
---

# Review: restaurant-menu-add-form

16 new keys (`menuAddTooltip` ... `menuAddedSnack`) in all 10 ARB files; new `lib/restaurant/widgets/menu_item_form_dialog.dart`; add button and `_addItem` flow in `lib/restaurant/pages/menu_edit_page.dart`; 31 new tests in `test/menu_add_form_test.dart`. No security review (plain UI and text; the credentials path reuses `_withCredentials` and was reviewed in the previous card).

## Gates

| Command | Exit | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | 764 tests, re-run after the P2 edits below |
| `make backend-analyze` | 0 | |
| `make backend-test` | 0 | |
| `make analyze` / `make check` | 2 | 30 `deprecated_member_use` infos: 28 baseline + 2 `flutter/material.dart` imports in the two new files; no other finding; `make check` stops at analyze |

## Findings (code-reviewer): P0 0, P1 0, P2 3

- Fixed P2-1: cancelling the reopened form left the add error in the page banner (for a 400 it read as the price error). `_addItem` now calls `clearSaveError()` on cancel; the cancel test asserts the duplicate text is gone.
- Fixed P2-3: comment on `_maxImageLength` (hand-copied server rule).
- Deferred P2-2: no test drives the over-long description error (`maxLength` blocks typing; pasting emoji past 500 units would).

Deviation accepted: after a failed add the error shows at the top of the reopened form, not in the page banner (the banner lives inside the list and would be hidden on an empty menu). Price-edit behaviour is unchanged (`_saveErrorText` defaults to `adding: false`).

Checked: button visibility rules; credentials first, 401 re-asks and resends the same draft; reopen prefilled on 409/503/429/403/400/500; snackbar on success; no hard-coded user text; all four controllers disposed; `mounted` checks; 360 px / text x2 fit in de, ru, lo; ID and password never in the widget tree; ARBs consistent (`{name}` placeholder, no ICU or apostrophe problems; the fr text uses a typographic apostrophe).

## Unverified (owner acceptance)

- Vietnamese wording of the 16 new strings, written without a Vietnamese reader and **pending owner acceptance** (for example "Mục" for category, which the owner may prefer as "Loại" or "Danh mục"). The reviewer found no errors.
- The wording of zh, lo, es, fr, ru, de, ko, ja (machine drafts).
- Layout on the real tablet or phone, adding an item against the real backend and seeing it on `customer.local`, and a picture added by file name.

## Verdict

**Passed**, P0: 0, P1: 0.

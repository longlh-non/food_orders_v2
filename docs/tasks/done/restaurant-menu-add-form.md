---
executor: task-executor
scopes: [restaurant, shared]
workKinds: [flutter, quality-gate]
blockedBy: [restaurant-menu-add-client-and-state]
---

# Restaurant: "add item" button and form on the menu edit page, in all 10 languages

## Why

The staff-facing part: an add button on `MenuEditPage` that opens a form and calls `MenuAdminState.addItem`. `scopes` includes `shared` because the new strings live in `lib/shared/l10n/*.arb` (all 10 files).

## Sources

`lib/restaurant/pages/menu_edit_page.dart` (`_withCredentials`, `_saveErrorText`, `_PriceDialog`), `lib/restaurant/widgets/staff_login_dialog.dart`, `lib/restaurant/state/menu_admin_state.dart` (previous card), `lib/shared/l10n/README.md`, `test/shared/arb_completeness_test.dart`, existing `menu*` and `customerCategory*` ARB keys, the existing menu edit page test.

## Goal

1. **Button.** An "add item" action that is visible in every page state, including the empty menu and a failed load is **not** required (hide it until the menu has loaded): put it in the AppBar `actions` (an `IconButton` with a tooltip) or a `FloatingActionButton`; do not put it inside the list, the empty state has no list. Disabled while `isAdding`.
2. **Form** (`AlertDialog`, `scrollable: true`, fits large text like `_PriceDialog`; private widget in the same file unless it gets long, then `lib/restaurant/widgets/menu_item_form_dialog.dart`):
   - Name (required), Description (optional, multi-line, max 3 lines), Price in VND (digits only, same as the price dialog), Category (`DropdownButtonFormField` of four, labels reuse `customerCategoryFood/Snack/Drink/Nibble`; start with none selected so staff must choose, ADD6), "Allows toppings" `SwitchListTile` shown **only** while Food is selected and reset to off when the category changes away from Food, Image file name (optional, plain text, hint text says the file must already be in the images folder, see the runbook).
   - Validates with `validateNewItem` before sending and shows a message under the field; nothing is sent while invalid. Text fields have `maxLength` set to the limits.
   - Returns a `NewMenuItem` or null on cancel.
3. **Flow.** Ask for credentials first through the existing `_withCredentials` (so a 401 loop works), show the form, call `state.addItem`. Not `saved` -> show the matching banner text (the existing banner area, extended in `_saveErrorText` with `duplicate` and `menuFull`) and **reopen the form prefilled** with what staff typed, so a duplicate-name error doesn't lose the input. `saved` -> a `SnackBar` "Added: {name}" and the item is in the list (the list is already driven by the state).
4. **Strings.** New keys, added to **all 10 ARBs** (`app_vi.arb` template first, with `@key` descriptions and placeholders): `menuAddTooltip`, `menuAddTitle`, `menuAddNameLabel`, `menuAddDescriptionLabel`, `menuAddCategoryLabel`, `menuAddCategoryRequired`, `menuAddAllowToppingsLabel`, `menuAddImageLabel`, `menuAddImageHelp`, `menuAddNameError`, `menuAddDescriptionError`, `menuAddImageError`, `menuAddDuplicate`, `menuFull`, `menuAddedSnack` (placeholder `{name}`), plus a `menuAddAction` for the confirm button if `commonSave` doesn't fit. Reuse `commonCancel`, `menuPriceLabel`, `menuPriceRangeError`, `menuSaveFailed`. Wording: `vi` is written by the agent in plain Vietnamese and marked pending owner acceptance in `lib/shared/l10n/README.md`; `en` drafted; `zh lo es fr ru de ko ja` machine drafts, **unverified**, recorded in the README under a new "Menu add form" heading (how many keys, which languages unverified). No plural messages needed; if one is added, give ru its `few`/`many` forms. Run `flutter gen-l10n` through `flutter test`; never hand-edit generated files.
5. Existing page behaviour (price edit, sold-out switch, banner, retry) unchanged.

## Non-goals

Rename, delete, editing an existing item's category/description/image, image upload or a file picker, drag ordering, changes to the customer app, any backend change.

## Tests written with the change

Widget tests with fake state/clients, in the existing menu edit page test file or a new one next to it:
- the add button is hidden before load and while the menu failed to load, visible with an empty menu and with items;
- credentials dialog appears first when none are held; wrong credentials (401) re-asks;
- the form blocks submit with an empty name, an over-long name, a missing category, a bad price, a bad image name, and sends nothing; the toppings switch only appears for Food and resets when the category changes;
- a valid form calls `addItem` with exactly the typed values, then the new item shows in the list and the snackbar appears;
- 409 shows the duplicate text and the form reopens with the typed values; 503, 429 (with and without wait), 403 each show their text;
- neither the staff ID nor the password appears in the widget tree;
- with large text scale and a narrow width the form scrolls with no overflow;
- `test/shared/arb_completeness_test.dart` stays green (every key in all 10 files, same placeholders); one test pumps the form in `vi` and `en` and finds the labels.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Page and form behave as listed | `make test` (gate) |
| All 10 ARBs have every new key | `make test` (arb completeness) |
| Analyzer, format, boundaries | `make analyze`, `make format-check`, `make boundaries` (gates) |
| No hard-coded user text, no new dependency | `code-reviewer` (review) |
| `make check` exit 0 | gate |
| Vietnamese wording and layout acceptable on the staff tablet/phone | owner acceptance at `http://restaurant.local`: "unverified" until done |
| Add an item, reload `customer.local`, it shows in its tab (and a food shows the topping sheet only if allowed) | owner acceptance in the real environment |
| Copy a picture into `backend/data/images/`, add an item with that name, picture shows | owner acceptance in the real environment |
| zh/lo/es/fr/ru/de/ko/ja wording | **unverified** (machine drafts); no agent can check them |

## Environment limits

Agents can't run a browser, Caddy or the backend with real credentials. Do not run `sudo`.

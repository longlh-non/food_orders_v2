---
task: backend-orders-month-export-format
status: passed
p0: 0
p1: 0
reviewedFiles:
  - backend/lib/orders_export.dart
  - backend/test/orders_export_test.dart
---

# Security review — backend-orders-month-export-format

Independent first-pass review by `security-reviewer` (tool-restricted, read-only), 2026-11-12.

## Scope

- **Asset:** the machine of whoever opens the CSV (Excel, Google Sheets or LibreOffice).
- **Attacker input:** `customerName`, item and topping names, and `id`. Each can be any string, sent through an unauthenticated `POST /orders`.
- **The boundary:** stored orders → `csvBytes` → file → spreadsheet parser.
- **No new** endpoint, file I/O or dependency.

## Checked with no issues found

- **Leading characters:** `=`, `+`, `-`, `@`, TAB and CR are covered, even after leading spaces. NBSP, full-width ＝, a leading LF, `|` or `'` don't trigger formulas (judged from knowledge, not tested). DDE payloads start with `=`, so they're neutralised.
- **Breaking out of a quoted cell:** `"` is doubled, and cells are quoted when they contain `;`, `"`, CR or LF. So `a";=cmd` becomes `"a"";=cmd"` and can't start a new cell with `=`.
- **Order of steps:** neutralising happens before quoting, so the prefix lands at the start of the cell. Neutralising twice is harmless, because `'` isn't a trigger.
- **The `sep=` line** is a constant, not something a user controls.
- **Month matching** only compares a text prefix; it builds no paths and no SQL.

## Findings: P0 0 · P1 0 · P2 2

- **P2-1:** the date and time cells weren't neutralised. They're cut from `placedAt`, which the backend validator makes start with a digit today, but legacy rows or a looser validator could change that. **Fixed:** both cells now go through `neutralise`. New test: a short `placedAt` of `=1+1` comes out as `'=1+1`.
- **P2-2:** legacy or malformed data makes the export throw `TypeError` (on a string price, or a null name). Text can never reach a bare number cell, because the cast fails first. So there's no injection path, only a crash of the export. **Carried** to `backend-orders-month-export-cli`: catch it, name the order id, and exit with an error.

## Carried to the CLI card

- **File safety:** create the export with mode 0600, outside any web-served directory. Don't follow symlinks, and don't overwrite a file unexpectedly.
- **Inputs:** validate the month with `isValidMonth` before putting it in a file name, and take the output path only from command-line arguments.

## Needs real-environment confirmation

- Whether Excel honours `sep=;` together with the byte order mark, and how the `'` prefix shows.
- That LibreOffice and Google Sheets don't evaluate NBSP or full-width leading characters.

**Counts:** P0 0 · P1 0 · P2 0 open (1 fixed, 1 carried to the CLI card).

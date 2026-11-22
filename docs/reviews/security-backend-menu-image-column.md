---
task: backend-menu-image-column
status: passed
p0: 0
p1: 0
---

# Security review: backend-menu-image-column

Independent reviewer: `security-reviewer` (read-only). It reviewed the same candidate as `execute-backend-menu-image-column.md`.

- **Assets:** the `menu_items.image` values (hand-edited with `sqlite3`), the `GET /menu` output, and the future images folder.
- **Attacker input:** only a hand-edited database value. No client can write it.
- **New capability:** read-only.

## Round 1: passed. P0 0, P1 0, P2 0

Checked and clean:
- **The rule is safe for the serving card:**
  - The regex allows exactly one dot and must start with a letter or digit. `..`, `a..b.png`, `.hidden.png`, a leading `-`, `/`, `\`, `%`, spaces, NUL and capitals all fail.
  - It's ASCII-only, so there are no Unicode tricks. Lowercase only, so a case-insensitive filesystem gives no alias.
  - Dart's `$` rejects a trailing newline.
  - At most 69 characters.
- **The CHECK:** `NOT GLOB '*[^a-z0-9.-]*'` is a correct, case-sensitive negated class. It's only the coarse guard; the regex is the exact rule.
- **Output:** every `image` in `GET /menu` passes `isValidImageName` or becomes `null`; non-text values become `null`. The output is JSON-encoded.
- **Migration:** BEGIN/COMMIT with ROLLBACK, the version is bumped inside the transaction, it's idempotent, and it adds no data.
- **Docs:** the `sqlite3` examples are accurate and safe.

## Notes for the next card

- **`backend-menu-image-file-serving`:**
  - apply `isValidImageName` to the URL-decoded value;
  - keep the symlink and regular-file checks.
- **Later rebuilds:** any rebuild of `menu_items` must carry `image` and its CHECK forward. Recorded as a follow-up in the execute report.

## Gates

See `execute-backend-menu-image-column.md`. `make check` exits 0.

## Needs owner confirmation

The `curl` against the real database (owner acceptance).

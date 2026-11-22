---
executor: task-executor
scopes: [docs]
workKinds: [documentation]
blockedBy: [backend-staff-id-password-gate, restaurant-staff-id-password-clients]
---

# Docs: staff ID + password instead of the staff token (runbook, decisions, card notes)

Why a separate card: `CLAUDE.md` is already rewritten by the backend card (it must be, contract first). The rest is owner-facing prose that should describe what really shipped, so it runs last. No code, no `CLAUDE.md`, `dev/**` or `.github/**` edits (those need per-task approval; if one is found to be needed, stop and ask).

## Requirements

1. `docs/runbook-local.md`: section 4 becomes "Staff ID and password" (start with `read -r STAFF_ID`, `read -rs STAFF_PASSWORD`, export both, then `dart run bin/server.dart`; what 401, 403 and 429 mean; how to rotate: restart with new values; the one-minute lockout and why). Update the startup snippet near line 25, the sentence near line 118, the curl example near line 150 and the env var table near line 246 (`STAFF_ID`, `STAFF_PASSWORD` >= 12 characters, printable ASCII; `STAFF_TOKEN` removed with a note "no longer used; ignored"). Add a "what changed for you" note: after this change start the backend with the two new variables or export and menu editing stay disabled (403).
2. `docs/ci-cd-decisions.md` D13: list `STAFF_ID` and `STAFF_PASSWORD` instead of `STAFF_TOKEN` (still server-only; CI never sees them). Add a short D-entry or note only if the file's style records such changes; do not renumber.
3. Active cards, wording only (names of the variables and "staff token" phrases): `docs/tasks/cd-github-deploy-workflow.md` (D13 line), `docs/tasks/cd-server-deploy-script.md` (the "staff token" line), `docs/tasks/deploy-production-config.md` (check; add the two variables to any server env file list if it names the token or lists variables), `docs/tasks/deploy-runbook.md` (check), `docs/tasks/backend-orders-month-export-xlsx.md` ("same staff token"), `docs/tasks/customer-menu-sold-out-items.md` (acceptance line), `docs/tasks/comments-backend.md` ("do not paste a real staff token": say "staff ID or password"). Do not touch `docs/tasks/done/` or `docs/reviews/`.
4. Note for the demo access gate (`deploy-demo-access-gate`): the Caddy `basic_auth` uses the `Authorization` header, and staff credentials use `X-Staff-*`, so they don't clash. Add one line to that card.
5. **"How to check my staff ID and password"** (owner request, 2026-11-19). Add a subsection to the runbook's "Staff ID and password" section, in plain copy-paste steps. Rule for every step: it must never print the ID's partner (the password) or put it in shell history. Placeholders only, no real values anywhere. The writer verifies each command against `backend/bin/server.dart` and `backend/lib/staff_gate.dart`.
   1. **In the shell that will start the backend** (before `dart run`):
      - Set check: `[ -n "$STAFF_ID" ] && echo "STAFF_ID is set" || echo "STAFF_ID is NOT set"`, and the same for `STAFF_PASSWORD`. The ID is not secret-grade, but don't print it either; keep both checks symmetrical.
      - Length without printing the password: use `[ "${#STAFF_PASSWORD}" -ge 12 ] && echo "password long enough" || echo "password too short (needs 12+)"`. Do NOT print the length itself (see open decision 1). Same idea for the ID: `[ "${#STAFF_ID}" -ge 1 ] && [ "${#STAFF_ID}" -le 64 ]`.
      - Printable ASCII check without echoing: `printf %s "$STAFF_PASSWORD" | LC_ALL=C grep -q '[^ -~]' && echo "has accents or special characters: not allowed" || echo "characters OK"`. Same for `STAFF_ID`. (`LC_ALL=C` makes `[^ -~]` mean "anything outside space..tilde", which is exactly the backend's `^[\x20-\x7E]+$`.) The writer runs this once with a throwaway value containing an accent and once without, to prove both branches.
      - Whitespace note: the backend trims both values, so spaces at the start or end are ignored; the 12-character minimum counts after trimming. Tell the owner not to rely on edge spaces.
      - Reminder: a value typed with `read -rs STAFF_PASSWORD` is not shown on screen and not saved in history; `export STAFF_PASSWORD=...` typed on the command line is saved in history. Variables only exist in that terminal and children started from it; a second terminal does not have them.
   2. **After starting the backend, read the startup line.** Exact texts (copy from `server.dart`):
      - good: `staff routes: enabled (STAFF_ID and STAFF_PASSWORD set)`
      - bad: `staff routes: disabled (STAFF_ID / STAFF_PASSWORD unset or invalid: ID 1-64 characters, password at least 12, printable ASCII)`
      - and, only if the old variable is still exported: `note: STAFF_TOKEN is no longer used; set STAFF_ID and STAFF_PASSWORD`. Fix: `unset STAFF_TOKEN` (and remove it from any env file or shell profile the owner uses).
      - "enabled" only says both values are usable; it does not prove staff will type the right ones (step 3).
   3. **Prove the pair works** with one request, taking the values from the same shell so nothing is typed or kept in history:
      ```bash
      curl -s -o /dev/null -w '%{http_code}\n' \
        -H "X-Staff-Id: $STAFF_ID" -H "X-Staff-Password: $STAFF_PASSWORD" \
        "http://customer.local/api/orders/export?month=YYYY-MM"
      ```
      (use a real month such as the current one; `restaurant.local` works too, and `http://localhost:3000/orders/export?...` straight to the backend works without the `/api` prefix). Say plainly: `-o /dev/null` throws the CSV away, `-w` prints only the status code. The `ps` warning: while curl runs, the header values are visible to other users of the machine in `ps`; fine on the owner's own laptop, don't do it on a shared server.
      - Codes: **200** the pair is right. **401** wrong ID or password (the server never says which). **403** staff routes are disabled: ID or password unset or invalid, see step 2. **429** locked: too many wrong tries; wait the number of seconds in the `Retry-After` header (up to 60; see `curl -i`, but `-i` prints headers sent back, not the password, which is fine) and a correct pair is refused during the lock too. **400** means the pair was accepted but the month was not `YYYY-MM` (the check runs before the month is read): fix the month.
      - **Warning:** 5 wrong tries within 60 s lock staff out for 60 s, for everyone (global, not per person). Test the right pair once; don't test wrong passwords repeatedly, or staff at the counter cannot export or edit the menu for a minute.
   4. **"Does the backend that is already running have them?"** The honest answer: the runbook cannot tell without restarting. `ps` does not show environment variables. `/proc/<pid>/environ` would, but it prints the password in clear text, so the runbook says: do NOT do that, and do not paste its output anywhere. Instead, if unsure, stop the backend and start it again from a shell where steps 1 to 3 passed. Looking at the "staff routes:" line in that terminal's scrollback is also valid. If the run is owner-only on their own machine, step 3's curl against the running backend is the safe test (200 = it has them).
   5. **In the restaurant app**: open the export dialog (and the menu editor), type the ID and password. What each message means (copy exact texts from `lib/restaurant/pages/export_month_dialog.dart`): "Wrong staff ID or password" = 401; "Too many wrong tries. Try again in N seconds." (or "...Try again later.") = 429; "Export is turned off on the server" = 403 (the backend was started without valid values). The browser does not remember them: reloading the page asks again, and the browser's password manager does not store them (owner decision).
   6. **Changing them:** stop the backend (Ctrl+C), set new values with `read`, start it again, check with steps 1 to 3, then tell staff the new pair. There is no other place they are stored; the old pair stops working at once on restart, and a staff member's open tab fails with "Wrong staff ID or password" until they type the new pair. Nothing to migrate or clean in the database.
   Keep this subsection short (about one screen); link to the env table instead of repeating it. If the final wording of an error message in the app differs from what is above, the app's actual text wins.

## Tests / acceptance

| Criterion | Verified by |
|---|---|
| No stale mention: `grep -rn "STAFF_TOKEN\|X-Staff-Token\|staff token" docs README.md CLAUDE.md` finds hits only in `docs/tasks/done/`, `docs/reviews/` and the runbook's "no longer used" note | grep result in the review report (reviewer re-runs it) |
| Runbook steps match the real commands and variable names | `code-reviewer` (review against `backend/bin/server.dart`) |
| Every command in requirement 5 is valid bash, never prints the password (not even its length), matches the startup line texts in `backend/bin/server.dart`, the rules in `backend/lib/staff_gate.dart` (1-64 ID, 12+ password, printable ASCII, trimmed, 5 failures / 60 s, 401/403/429, header names) and the app messages in `lib/restaurant/pages/export_month_dialog.dart` | `code-reviewer`, checking each command line by line; writer ran the ASCII check on a throwaway value with and without an accent |
| No real ID or password in any doc (placeholders only) | reviewer's grep/read of the diff |
| `make check` green (nothing broken, no code touched) | `make check` exit 0 (gate) |
| Owner can follow section 4 from a cold start, run the check steps and export a month | owner acceptance - "unverified" until done |

No security review needed (docs only, no new behaviour); the secrets rule still applies: no real ID or password in any example, placeholders only.

## Decided by the owner (2026-11-19)

Every recommendation was accepted:
- **`STAFF_ID`:** 1–64 characters.
- **`STAFF_PASSWORD`:** at least 12 characters.
- Both trimmed, printable ASCII only, stored as plain text in the env, with no hash.
- **Headers:** `X-Staff-Id` and `X-Staff-Password`, never `Authorization`/Basic.
- **Comparison:** constant time, with one fixed 401 that doesn't say which half was wrong.
- **Lockout:** global, in memory. After 5 failures in 60 s, every staff request gets 429 with `Retry-After` for 60 s. The deliberate lock-out risk is accepted.
- **Clean switch:** `STAFF_TOKEN` and `X-Staff-Token` stop working, and the backend prints a hint if `STAFF_TOKEN` is still set.
- **No browser password manager or autofill.**

## Open (owner, for requirement 5)

1. Print the password length, or only "long enough"? Recommended: only "long enough" (no length printed).
2. Optional `CLAUDE.md` pointer: one sentence in "Staff ID and password" saying "to check the values, see `docs/runbook-local.md` > Staff ID and password > How to check". Useful, but `CLAUDE.md` edits need explicit owner approval for this task; not part of this card unless the owner says so.

## Also covers (owner request, 2026-11-19)

"Update runbook-local.md about using STAFF_ID and STAFF_PASSWORD" is requirement 1 (the runbook's "Staff ID and password" section, the env-var table and the examples), plus requirement 5 for the check steps. No separate card.

## Executor notes (2026-11-19)

- **Open decision 1:** the card's recommendation is used. Checks print only "long enough" / "too short", never the length (the owner wasn't asked again; the recommendation stood).
- **Open decision 2: no `CLAUDE.md` edit needed.** `CLAUDE.md` line 47 already points to `docs/runbook-local.md` for "staff ID and password, checks".
- **Runbook:**
  - the startup snippet;
  - the menu-editing sentence;
  - section 4 rewritten, with a "How to check your staff ID and password" subsection (steps 1–5; changing them is a bullet in section 4);
  - section 9's env table: `STAFF_ID` and `STAFF_PASSWORD`, plus `STAFF_TOKEN` "no longer used; ignored".
  - The menu-editor screen doesn't exist yet, so step 5 only names the export dialog.
- **The ASCII check was run this session on throwaway values:** `mật-khẩu-thử` → not allowed, `plain-test-value` → OK, a value with a tab → not allowed. The too-short and unset-ID branches were also checked.
- **Requirement 3 extras:** `comments-backend.md` and `comments-shared.md` named the deleted `backend/lib/staff_token.dart`; that's now `staff_gate.dart`. `deploy-production-config.md` didn't name the token, but it lists the unit's `Environment=` values, so it now says `STAFF_ID`/`STAFF_PASSWORD` come from a server-only `EnvironmentFile`. `deploy-runbook.md` was checked: nothing to change.
- **Requirement 4:** `grep` confirms nothing in `backend/lib` or `backend/bin` reads `Authorization`.

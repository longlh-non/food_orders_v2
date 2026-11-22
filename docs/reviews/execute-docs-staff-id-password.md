---
task: docs-staff-id-password
status: passed
p0: 0
p1: 0
---

# Review: docs-staff-id-password

Independent reviewer: `code-reviewer` (read-only). This is a docs-only card, so no security review was required.

## Candidate

- **`docs/runbook-local.md`:**
  - the startup snippet;
  - the menu-editing sentence;
  - section 4 "Staff ID and password", including "How to check your staff ID and password";
  - section 9's env table.
- **`docs/ci-cd-decisions.md` D13.**
- **Wording in open cards:** `cd-github-deploy-workflow`, `cd-server-deploy-script`, `backend-orders-month-export-xlsx`, `customer-menu-sold-out-items`, `comments-backend`, `comments-shared`, `deploy-production-config`, `deploy-demo-access-gate`.
- **No code**, and no edits to `CLAUDE.md`, `dev/**`, `.github/**`, `docs/tasks/done/` or `docs/reviews/`.
- **Owner decisions:**
  - "long enough" only, never the length (the card's recommendation);
  - no `CLAUDE.md` pointer needed, since line 47 already points to the runbook.

## Round 1: passed. P0 0, P1 0, P2 5

Checked against `backend/bin/server.dart`, `staff_gate.dart`, `orders_api.dart` and `export_month_dialog.dart`:
- every command is valid bash and never prints the password or its length;
- the startup texts, rules, codes and app messages are exact;
- 400 after the gate is correct;
- placeholders only;
- the stale grep (re-run by the reviewer) hits only the intentional "no longer used" notes, `CLAUDE.md:304` and the card.

Findings:
- **P2-1:** the check subsection is longer than one screen. **Accepted as is:** all five steps were asked for.
- **P2-2:** the ASCII check says OK for an all-space value. **Fixed:** a note says an all-space value counts as unset.
- **P2-3:** the code table missed `000`/`502` (nothing answering). **Fixed:** a row was added.
- **P2-4:** "set them again in another terminal" didn't say how. **Fixed.**
- **P2-5:** it didn't say the ID is echoed while typing. **Fixed** in both places.
- **Noted, out of scope:** an awkwardly wrapped comment at `backend/lib/orders_api.dart:54`, left for the `comments-backend` card.

These fixes are wording only, so there was no re-review round.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make check` (round-1 candidate) | 0 |
| `make check` (final, after the wording fixes) | 0 |
| ASCII check on throwaway values (accented → not allowed, plain → OK, tab → not allowed); too-short and unset branches | as expected |

## Unverified (owner acceptance)

Follow section 4 from a cold start, run the check steps, and export a month through `customer.local`.

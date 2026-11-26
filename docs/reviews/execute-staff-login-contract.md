---
task: staff-login-contract
status: passed
p0: 0
p1: 0
---

# Review: staff-login-contract

Changed: `CLAUDE.md` (owner-approved for this task only, 2026-11-26) and the card (an "Owner decisions" table, review-fix notes). Docs only: no code, no runbook, no l10n README, no `dev/**` or `deploy/**`, and `docs/deploy.md` (the owner's earlier uncommitted edit) was not touched. The staff login is written into the contract as **agreed, not built**: two new routes (`POST /staff/login`, `POST /staff/logout`), the `X-Staff-Session` header, a 16-hour fixed lifetime with no refresh token, schema step 11 (`staff_sessions`, token hashes only), `crypto` recorded as an approved direct dependency, and the "Contract ahead of code" note widened to cover all of it.

## Gates

| Command | Exit | Note |
|---|---|---|
| `make format-check` | 0 | re-run by the main session after the last fixes |
| `make boundaries` | 0 | re-run by the main session after the last fixes |
| `make check` | 2 | stops at `make analyze`: 30 known infos (`deprecated_member_use`), no Dart changed; the test and backend gates did not run. Not claimed as passed. |

## Round 1 (code-reviewer): P0 0, P1 0, P2 4, all fixed

- The login body over 4 KB is 400 on purpose (the menu routes answer 413): now stated.
- The logout row now gives 204 / 401 / 403 when staff routes are disabled, and says it is never counted or refused by the lock.
- The five staff rows say 429 applies only to the password headers; a session request is never 429.
- The "no hash" Weak points sentence now says the configured password stays unhashed and `crypto` is approved only for the token HMAC.

## Round 2 / re-review (code-reviewer): P0 0, P1 0, P2 2, both fixed

- The Known limitations lock-out sentence now names the login and the export, like the Weak points bullet.
- The card's planner text now says the "Owner decisions" table supersedes it, and its logout line includes the 403.

## Security review: see `security-staff-login-contract.md`.

## Deferred (written down)

- The backend and client cards must test, not assume: the CORS preflight for `x-staff-session` is refused; `X-Staff-Session` passes both deployed Caddyfiles unchanged; the request logger never prints the header; session lookup compares the HMAC value, not the raw token; malformed or oversize login bodies are not counted as wrong passwords; the startup deletion of rows made under a different key actually runs. These are written into the later cards' tests.

## Unverified (owner acceptance)

Nothing is implemented, so every rule is "agreed, not built". Real-browser behaviour of `localStorage` (private windows, several tabs) and the whole login flow over the real HTTPS demo gate are unverified until the later cards ship.

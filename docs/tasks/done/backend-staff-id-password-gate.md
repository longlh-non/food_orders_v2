---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: []
securityReview: required
---

# Backend: replace the staff token with one shared staff ID + password (contract first)

Owner choice: one shared staff ID and one shared password, set on the server like the token today. No per-person accounts.

## Approval needed

This card edits `CLAUDE.md`. That needs the owner's explicit approval for THIS task. Ask before editing it. No edits to `dev/**`, `.github/**`, `Makefile`.

## Why

A single token is hard to remember and share; staff want "an ID and a password". The security rules stay the same: fail closed, constant-time compare, nothing secret in logs, bodies or URLs.

## Design (plain words, with trade-offs)

1. **Server config.** Two env vars, read in `backend/bin/server.dart`: `STAFF_ID` and `STAFF_PASSWORD`. Both are trimmed; "empty counts as unset" as today. Staff routes are enabled only if:
   - the ID is 1 to 64 characters,
   - the password is at least 12 characters (a human-chosen password is weaker than the old 16-character random token, so the floor is not lower than 12; the owner can still pick a random one),
   - both are printable ASCII only (see Transport).
   Otherwise every staff request gets 403 (fail closed), even with matching headers. Startup prints `staff routes: enabled` or `disabled (STAFF_ID / STAFF_PASSWORD unset or invalid)`, never a value. If the old `STAFF_TOKEN` is set, print a one-line hint that it is no longer used (the name only).
2. **No password hash.** Dart has no password hashing (KDF such as bcrypt/argon2/PBKDF2) in the SDK. `package:crypto` has only plain hashes (SHA-256), which are NOT a safe way to store a human password, and would be a new dependency needing owner approval. The plaintext sits in the process environment, exactly where the token sat, and anyone who can read that can read the hash file next to it too. So: plaintext in the env, no new dependency. Revisit only if per-person accounts ever happen.
3. **Transport: two custom headers** `X-Staff-Id` and `X-Staff-Password`. Not HTTP Basic, for three reasons:
   - `Authorization` is already used by the planned demo access gate (Caddy `basic_auth`, `deploy-demo-access-gate`); the browser would send the gate's credentials there and the two would collide.
   - `shelf_cors_headers` 0.1.5 allows `authorization` cross-origin and reflects any Origin (archived security review), so Basic would be sendable from another website. The custom names are not in its allow list, so the browser preflight blocks them. Do NOT add them to CORS.
   - A 401 with `WWW-Authenticate` makes browsers show their own login popup. Never send that header.
   Because header values must stay plain, ID and password are limited to printable ASCII (browsers reject other characters in headers).
   A login endpoint with short-lived session tokens was considered and rejected: it adds server state, expiry and a new route for no gain at this size.
4. **Comparing.** Compare both fields every time, in constant time, with the existing `constantTimeEquals`, and combine the results with a non-short-circuit AND (compute both first). A missing header counts as an empty string. One fixed 401 body, `Missing or wrong staff ID or password`, so nothing says which half was wrong.
5. **Brute force.** A human password needs a limit. Simple in-memory, global (not per IP: behind the proxy every request comes from 127.0.0.1, and trusting `X-Forwarded-For` would be spoofable unless the proxy is configured to overwrite it). Rule: after 5 wrong attempts within 60 seconds, every staff request gets **429** with `Retry-After` (seconds) for the next 60 seconds, correct credentials included; the counter lives in the `StaffGate` instance, needs no map, and resets on restart. Trade-off, stated honestly: anyone who can reach the apps can lock staff out for a minute at a time by failing on purpose; that is a nuisance, not a breach, and is accepted. The clock is injectable so tests don't sleep. The 429 body is fixed text.
6. **Migration: clean switch.** `STAFF_TOKEN` and `X-Staff-Token` stop working in this card (no dual support: one owner, local dev). The owner must start the backend with `STAFF_ID` and `STAFF_PASSWORD` from now on. Between this card and `restaurant-staff-id-password-clients` the restaurant export and menu editing give 401 (client still sends the old header). Run the two cards back to back and test only after the second.
7. **Naming.** The class stays `StaffGate` (same job). Rename the file `backend/lib/staff_token.dart` to `backend/lib/staff_gate.dart` and the test `backend/test/staff_token_test.dart` to `staff_gate_test.dart`; constants `staffIdHeader = 'x-staff-id'`, `staffPasswordHeader = 'x-staff-password'`; drop `staffTokenHeader`, `minStaffTokenLength` (add `minStaffPasswordLength = 12`). Constructor takes `StaffGate({String? id, String? password, DateTime Function()? now})`.

## Sources

`backend/lib/staff_token.dart`, `backend/bin/server.dart`, `backend/lib/menu_api.dart` and `backend/lib/orders_api.dart` (they call the gate; check comments), `backend/test/staff_token_test.dart`, `backend/test/orders_export_api_test.dart`, `backend/test/menu_api_test.dart`, `CLAUDE.md` ("Staff token", the `PATCH /menu/{id}` and `GET /orders/export` rows, "Exporting a month", the curl examples, Known limitations), `docs/tasks/done/backend-staff-token-gate.md` and the archived security reviews (the reasons).

## Requirements (order: contract, then backend)

1. `CLAUDE.md`: rewrite "Staff token" as "Staff ID and password" (env vars, rules above, headers, 401/403/429, weak points: shared credentials, plaintext env, plain HTTP on wifi, global lockout can be triggered by anyone). Update the two API rows (new headers; add 429 with `Retry-After`), the curl examples (`-H "X-Staff-Id: $STAFF_ID" -H "X-Staff-Password: $STAFF_PASSWORD"`, with the existing `ps` warning), "Exporting a month", and the Known limitations line. Keep the sentence that the credentials don't make customer data private.
2. Backend: implement the gate as designed, rename files, update `server.dart`, the doc comments in both APIs, and the existing export and menu tests to send the new headers.
3. No new dependency; `pubspec.yaml` and `backend/pubspec.yaml` unchanged. No Flutter files touched (the client card follows).

## Non-goals

Restaurant app changes, runbook/ci-cd docs (separate card), password hashing, sessions, per-IP limits, per-person accounts, logging of attempts beyond a count-free fixed line (do not log IDs or passwords, not even wrong ones).

## Tests written with the change (`backend/test/staff_gate_test.dart` plus the two API tests)

Use obviously fake values built in the test (e.g. `'test-id'`, a 12+ character dummy), never real secrets.
- Enabled only when ID (1..64) and password (>=12) are valid printable ASCII; unset, empty, whitespace-only, too short, too long, non-ASCII all give 403 even with matching headers; values are trimmed.
- Correct pair passes; wrong ID, wrong password, both wrong, missing either header, empty headers: all 401 with the identical body; old `X-Staff-Token` alone gives 401.
- Response bodies and headers never contain the configured or sent values; no `WWW-Authenticate` header.
- `constantTimeEquals` cases kept; both fields are always evaluated (test with a fake that counts calls, or a wrong ID plus right password still counts as one failure).
- Lockout with an injected clock: 5 failures then 429 with `Retry-After`; correct credentials during lockout still 429; passes again after 60 s; 4 failures do not lock; 403 (disabled) is not counted or changed.
- `GET /orders/export` and `PATCH /menu/{id}`: 403 disabled, 401 wrong, 429 locked, success with the new headers.
- CORS: an `OPTIONS` preflight asking for `x-staff-id` / `x-staff-password` is not allowed (the allow list is unchanged), and the report states the installed `shelf_cors_headers` version checked.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour above | `make backend-test` (gate) |
| Analyzer, format, boundaries clean | `make backend-analyze`, `make format-check`, `make boundaries` (gates) |
| Flutter side still compiles and its tests pass | `make analyze`, `make test` (gates; the restaurant tests don't call the backend) |
| No secret in logs, bodies, URLs; constant time; fail closed; CORS list unchanged; no `WWW-Authenticate`; lockout is bounded in memory | `security-reviewer` (review; `security-backend-staff-id-password-gate.md`) |
| Contract table matches the code | `code-reviewer` (review) |
| No new dependency | `code-reviewer` (empty `pubspec.yaml` / `pubspec.lock` diff) |
| `make check` green | `make check` exit 0 (gate) |
| Start backend with `STAFF_ID` and `STAFF_PASSWORD`: `curl` export and menu PATCH with the headers give 200; wrong ID or wrong password give 401; unset vars give 403; 5 wrong tries give 429 | owner acceptance in the real environment - "unverified" until done |

## Environment limits

Agents cannot run the real backend with real credentials, the browser or Caddy, and never run `sudo`. The owner chooses the ID and password and starts the backend with them (see the typed-in `read -rs` pattern in CLAUDE.md, now for both variables).

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

## Owner approval and executor notes (2026-11-19)

- **Owner approval:** the owner approved the `CLAUDE.md` edits for this card.
- **Renamed files:** `backend/lib/staff_token.dart` → `staff_gate.dart` and `backend/test/staff_token_test.dart` → `staff_gate_test.dart`. Both old files were tracked by git, so `git status` shows them as deleted plus the new untracked files. Nothing was staged.
- **Gate:** `StaffGate({id, password, now})`. The failure list is capped at 5 entries, then cleared when the lock starts. `Retry-After` is the remaining whole seconds, rounded up.
- **Tests updated:** the existing export and menu tests now use `StaffGate(id: testStaffId, password: token)` and a `staffCreds(password)` helper at the end of each file.
- **CORS:** checked against `shelf_cors_headers` 0.1.5. A test sends a cross-site `OPTIONS` asking for `x-staff-id, x-staff-password`, and the allow-list contains neither.

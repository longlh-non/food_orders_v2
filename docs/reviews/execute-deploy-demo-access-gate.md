---
task: deploy-demo-access-gate
status: passed
p0: 0
p1: 0
---

# Review: deploy-demo-access-gate

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `caddy validate --config deploy/Caddyfile --adapter caddyfile` (throwaway env hash of `x`, exported only for the command) | 0 | "Valid configuration"; re-run by the orchestrator after the final comment edit. Automatic HTTP→HTTPS redirect still on |
| `caddy validate` with only `FOOD_ORDERS_AUTH_HASH` unset | 1 | refuses: "username and password cannot be empty or missing" (fails closed, but the whole site would not load) |
| `caddy validate` with both variables unset | 0 | loads; implementer's functional test showed 401 for everyone (not re-run by the orchestrator) |
| `make check` | 2 | stops at `analyze`: the 19 pre-existing `deprecated_member_use` infos; no Dart changed in this card |

Implementer's functional test (temp copy in the scratchpad with `auto_https off`, high ports, python `http.server` as upstream, curl with Host headers): no/wrong credentials → 401 on `/`, `/api/x`, `/api/orders/stream`, `/deep/link` on both hosts; right credentials → 200, `/api/x` reached the upstream, unknown paths fall back to `index.html`; the upstream log held only authenticated requests. Orchestrator did not re-run it. `caddy adapt --pretty` route walk (implementer): the authentication handler precedes the `/api/*` subroute and the file-serving subroute on both hosts.

## Changed paths

`deploy/Caddyfile` only (owner approved this file for the task). `deploy/` is untracked in git, so it appears as `??`.

## Design

`(demo_gate)` snippet with `basicauth { {$FOOD_ORDERS_AUTH_USER} {$FOOD_ORDERS_AUTH_HASH} }` imported first in both site blocks; user and bcrypt hash come from the Caddy service environment (server-only env file, owner-run commands in the file header); no hash or password in the repo (grep: only the placeholder `'$2a$14$...'` in a comment). `basicauth` spelling because the installed Caddy is 2.6.2 (newer Caddy keeps it as a deprecated alias of `basic_auth`).

**Beyond the card (pre-existing bug fixed):** the bare `try_files {path} /index.html` ran before `handle_path`, rewriting every `/api/*` path that is not a file on disk to `index.html`, so API calls returned the app page. `root`, `try_files` and `file_server` now sit in a catch-all `handle { }`. Earlier reviews missed it because they only walked the compiled route list.

## Findings

Code review: P0 0, P1 0, P2 6. Security review (`docs/reviews/security-deploy-demo-access-gate.md`): P0 0, P1 0, P2 4. Fixed in this round (comment-only, re-validated): the inaccurate "answers 401 to everyone" comment and its dangling "see the check in the owner steps" (now states the real behaviour and a `curl -sI` check), and the imprecise "restart not reload" reason. Deferred P2 follow-ups:
1. **Cache headers (pre-existing, not fixed):** `@nocache path /index.html /flutter_service_worker.js` does not match `/` or SPA deep-link fallbacks (the `header` route runs before `try_files`), so those responses carry no `Cache-Control: no-cache` and a returning visitor may get a stale `index.html` after a deploy. Unverified (`curl -sI https://host/ | grep -i cache-control`); fix idea: add `/` to the matcher, or set the header inside the `handle` block after `try_files`.
2. No HSTS: add `Strict-Transport-Security` once the certificates work, so a first plain-http visit can't leak the shared password.
3. No rate limit and bcrypt cost 14: wrong-password requests burn CPU; use a strong random password; add to the runbook's weak-points list.
4. `web/index.html` manifest link has no `crossorigin="use-credentials"`: Chrome may fetch the manifest without credentials and get 401 (broken PWA install / console noise); owner browser checklist.
5. Ambient-credential CSRF on the unauthenticated customer POST routes (backend may not require `Content-Type: application/json`); within the accepted "no customer auth" risk, not worsened by the gate.
6. Card/implementation deviations to record in `deploy-runbook`: `basicauth` vs `basic_auth`; two env vars (user and hash); a shared snippet; the `handle` restructure; "same layout as dev/Caddyfile" is only loosely true; a Caddy upgrade may warn about the old spelling; a stale 401 would make the SSE client reconnect every 2 s.

## Unverified (owner acceptance)

In a real browser: one login prompt then `fetch` and `EventSource` resending credentials on same-origin `/api/*`, including after an SSE reconnect; live order appearing on the restaurant site; the Flutter service worker and `/api/images/*` `<img>` loads authenticated; the manifest fetch; cache headers on `/` and deep links; `caddy validate` and real certificates on the server with real hostnames; `curl -i https://<host>/api/orders/stream` → 401 without credentials.

## Verdict

**Passed**, P0: 0, P1: 0.

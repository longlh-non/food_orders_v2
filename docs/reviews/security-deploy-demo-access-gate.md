---
task: deploy-demo-access-gate
status: passed
p0: 0
p1: 0
---

# Security review: deploy-demo-access-gate

## Scope

`deploy/Caddyfile` (full file, untracked). Read-only review; Caddy was not run by the reviewer.

## Findings: P0 0, P1 0, P2 4. No path that bypasses the gate was found.

1. No HSTS: a first plain-http visit can leak the shared password on hostile wifi. Add `Strict-Transport-Security` once certificates work; tell viewers to use https only.
2. No rate limit, bcrypt cost 14: wrong-password requests cost CPU (0.3–1 s each). Use a strong random password (16+ chars); optional fail2ban/ufw limits. The decision records rate limiting as a non-goal.
3. Ambient-credential CSRF: after a demo viewer authenticates, a cross-origin form post can carry the cached credentials to the unauthenticated customer POST routes if the backend doesn't require `application/json`. Within the accepted "no customer auth" risk, not made worse by the gate; optional backend fix.
4. Documentation accuracy: the empty-variable behaviour comment — **fixed in the fix round** (see `execute-deploy-demo-access-gate.md`); a stale 401 makes the app's SSE client reconnect every 2 s (noisy, harmless).

## Checked and clean

`import demo_gate` at site level in both blocks; Caddy's fixed directive order puts basic auth before `handle`, `handle_path`, `file_server`, `encode`; no `route`/`redir`/header-only route answers before auth; `/api/*`, SSE, static files, SPA fallback and Caddy-generated error responses are behind the gate; `request_body` 64KB still inside `handle_path` ahead of `reverse_proxy` on both hosts; security headers still present (and also on 401s); case variants (`/API/...`) can't bypass; unmatched Host gets no site block; the backend binds 127.0.0.1:3000 and never reads `Authorization`; no hash or password in the repo (placeholder `'$2a$14$...'` only); `$` handling in the systemd `EnvironmentFile` (single quotes) and `{$VAR}` is right; `install -m 600` + `sudoedit` safe; `caddy hash-password` prompts (no password on the command line); no `log` directive so no access-log credential exposure (re-check if one is added).

## Needs the real environment

`caddy validate`/`adapt` with variables set, both unset and only hash unset (orchestrator ran these after the review: only-hash-unset refuses to load, both-unset loads and the implementer's functional test shows 401); browser SSE/fetch credential reuse; service worker and `<img>` loads; `curl` 401 on both hosts over HTTPS.

## Verdict

**Passed**, P0: 0, P1: 0.

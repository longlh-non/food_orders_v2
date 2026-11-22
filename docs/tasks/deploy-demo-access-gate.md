---
executor: task-executor
scopes: [dev-infra]
workKinds: [infra]
blockedBy: [deploy-production-config]
securityReview: required
---

# Gate the public demo behind a shared password (Caddy basic auth)

## Why

The app has no auth (`CLAUDE.md` "Known limitations"). Today that risk is limited to the home wifi. On the public internet anyone who finds the URL can create, change, or cancel orders and read customer names. This is a security decision for the owner (HOST3), not a detail.

Important limit to understand: protecting only the restaurant site does NOT help. Both hostnames proxy `/api/*` to the same backend, so someone could `PATCH /api/orders/{id}` or `GET /api/orders` through the customer hostname. A real gate therefore has to cover the API on every hostname.

## Open decision (owner) - HOST3

- A. Demo only, gated: one shared username/password via Caddy `basic_auth` on BOTH sites (covers the API too, including SSE, because browsers resend the credentials same-origin). Cheap, no code, no change to Flutter. Not real per-customer auth; the password is shared and travels over HTTPS only. Recommended for a demo shown to a few people.
- B. Demo ungated: accept the risk, fake data only. Acceptable only if nobody enters real names and the owner is fine with strangers editing orders.
- C. No go-live until a real auth card exists (tokens or accounts, restaurant-only status changes, customers see only their own orders). Needed before any real customers. Not planned here because it needs product decisions (who logs in, how restaurant staff are created); ask the owner and write it as a separate backend contract-first card.

This card implements option A only. If the owner picks B or C, drop this card and record that in `deploy-runbook`.

## Goal

`deploy/Caddyfile` gains `basic_auth` on both site blocks (API and static files). The password hash is NOT committed: the Caddyfile reads it from an environment variable or a separate file outside the repo (for example `{$FOOD_ORDERS_AUTH_HASH}` supplied through the systemd unit's `EnvironmentFile` that lives only on the server). The runbook (next card) tells the owner to generate the hash with `caddy hash-password` on the server.

No clash with the staff ID and password: Caddy `basic_auth` uses the `Authorization` header, while staff routes use `X-Staff-Id` and `X-Staff-Password`, so a request can carry both. The backend never reads `Authorization`.

Check also: `OrderApiClient` needs no change (same-origin credentials are sent automatically by the browser); executor confirms by reading the client, and states that live SSE behind basic auth is unverified until the owner tests it.

## Non-goals

Per-user accounts, login page, backend auth, rate limiting, IP allow-lists (mention as alternative: poor fit because a phone on mobile data has a changing IP), Flutter changes.

## Tests written with the change

None runnable by agents (config only). Review checks that no hash, password, or token appears in any committed file.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Both hostnames and `/api/*` are behind auth | `security-reviewer` (review) + owner test: `curl https://<host>/api/orders` returns 401 without credentials |
| No credential or hash in the repo | `security-reviewer` (review) |
| SSE/live updates still work after login | owner acceptance in the real environment: place an order on the phone, see it appear live on the restaurant site - "unverified" until done |
| `make check` still green | `make check` exit 0 (gate) |

## Environment limits

Agents cannot run Caddy or test over the internet. Owner supplies the password and runs `caddy hash-password`.

## Decided by the owner (2026-11-13)

**HOST3 = A:** one shared username and password through Caddy `basic_auth` on both sites. This is recorded in `docs/ci-cd-decisions.md`.

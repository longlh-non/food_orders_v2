---
executor: task-executor
scopes: [docs]
workKinds: [documentation]
blockedBy: []
---

# Docs: a DigitalOcean section in the deploy guide (Docker, pre-deploy checks, domain)

## Why

The owner chose DigitalOcean (HOST1) and wants a step-by-step guide in `docs/deploy.md`. Today the guide covers Oracle and Google (section 3) and a generic Docker path (section 11a). Nothing is written for DigitalOcean, nothing says exactly what to check before each deployment, and domain setup is only sketched in section 6.

## Sources

`docs/deploy.md` (all of it, especially sections 3, 4, 6, 8, 11, 11a and 12), `docs/ci-cd-decisions.md`, `deploy/docker/*` (compose.yaml, Caddyfile, both `.env.example` files, backup.Dockerfile), `backend/Dockerfile`, `CLAUDE.md` "Backend" (Storage, Shop and bank settings, Staff ID and password). Read, do not edit, anything outside `docs/`.

## Decided by the owner

- HOST1 = **DigitalOcean** (Droplet). HOST2 (domain) is still open: the guide offers a free DuckDNS subdomain as the default and a bought domain as the alternative, and says the owner picks one.
- Docker is the path for this section (DOCKER1 stays "alternative to systemd": this section is just the DigitalOcean walkthrough of 11a).

## Goal

Edit `docs/deploy.md` (and a one-paragraph update of `docs/ci-cd-decisions.md` recording HOST1 = DigitalOcean). Add a new section **"11b. DigitalOcean: step by step with Docker"** (after 11a, before the acceptance table) and a short **3.3 DigitalOcean** entry in section 3 that points to it. Same style as the rest (placeholders such as `SERVER_IP`, "On your laptop" / "On the Droplet", "unverified until you do it"). It has three parts, in this order:

1. **Dockerisation of the three parts.** Explain what runs where and how each is built, with the real commands and file names:
   - **Backend:** `backend/Dockerfile`, built on the Droplet (`docker compose build backend`), data in `/var/lib/food-orders/data`.
   - **Frontend:** the two Flutter web apps are **not** containers of their own. They are built on the laptop with `deploy/build.sh` and served as static files by the stock Caddy container (read-only mounts of `/var/www/food-orders/customer` and `restaurant`). Say why (no Flutter in Docker, 11a / DOCKER4).
   - **Database:** there is **no database server and no database container**. The database is one SQLite file (`orders.db`) inside the backend's data folder, with the pictures next to it, kept on the Droplet disk through a host-folder mount so it survives container rebuilds. Say what that means for backups (`backup` service), for sizing the Droplet, and that a Droplet destroy deletes it unless backups were pulled off.
   - The Droplet size and region choice (at least 1 GB RAM; 512 MB may fail while building, swap as the fallback; region decides CPU type and latency), Ubuntu LTS, SSH key at creation, optional DigitalOcean Cloud Firewall allowing only 22, 80 and 443 (and that Docker's published ports bypass `ufw`, so the cloud firewall is a useful second layer here), and that DigitalOcean's pricing and trial credit must be checked on their site (the guide must not state prices as facts).
   - Then the ordered first-install steps, pointing to 11a.x for the details instead of copying them.
2. **Configuration before each deployment: what to focus on and double check.** A checklist table or list the owner runs through before every deployment (first install and every release). At least: the secrets files exist with the right mode and owner and contain no placeholder (`CHANGE-ME`, `REPLACE_ME`, `example.com`); the staff password length rule; `CUSTOMER_HOST` and `RESTAURANT_HOST` are the real names and DNS already points to the Droplet **before** `up -d`; `docker compose config --quiet` passes; the web build folders contain `index.html` and were built from the intended revision; a dated backup was made **before** any backend update (schema step 8 cannot be undone) and one copy is off the Droplet; the data and backups folders exist and are owned by uid 10001; ports (only 80/443 published, `ss -tlnp` / `docker ps` show no `->` for 3000; port 3000 fails from another machine); disk space and memory (`df -h`, `free -m`); the Caddy 2.6.2 pin and the unpinned base images are known risks; the shop and bank settings (`SHOP_*`, `BANK_*`) are the real ones if reports and transfers are wanted; the clock; `down -v` is never used; and what to check right after (401 without the gate password, 200 with it, a test order live on both sites, the stream, logs). Mark each item with why it matters in a few words.
3. **Domain setup.** Step by step:
   - Why a hostname is needed (Let's Encrypt cannot issue for a bare IP) and that the app needs **two** names (customer and restaurant).
   - **Free option, DuckDNS:** create two subdomains, point both at the Droplet's public IP, verify with `nslookup`/`dig`, what the update-IP story is (a Droplet keeps its IP until destroyed; a Reserved IP is an option, check pricing). Put the two names in `/etc/food-orders/caddy.env` (`CUSTOMER_HOST`, `RESTAURANT_HOST`). Caddy requests certificates by itself on first start once ports 80 and 443 reach it.
   - **Quick test option:** sslip.io / nip.io style names, with the warning that they share rate limits with other users and are for tests only. State the limits as "check before relying on it", not as facts.
   - **Paid option:** buying a domain at any registrar and adding two A records (or DigitalOcean DNS), TTL advice, and that this is the owner's decision (HOST2).
   - Not recommended: free `.tk`/`.ml`-style TLD services (unreliable).
   - What to do when certificates fail (DNS not yet pointing, port 80 blocked by a firewall, rate limits: do not repeat `down -v`; read `docker compose logs caddy`), and how to confirm HTTPS works.
   - A note that the shared gate password and staff password are separate things.

Also: add 2 or 3 DigitalOcean rows to the acceptance table, all **unverified**, and a line in `docs/ci-cd-decisions.md` recording HOST1 = DigitalOcean (decided in this task) with HOST2 still open. Fix any cross-reference this breaks. Do not rewrite the Oracle/Google sections or 11a (point to them).

## Non-goals

Any change outside `docs/` (no `deploy/**`, `.github/**`, `Makefile`, `CLAUDE.md`, code); automating DNS or DigitalOcean API calls; Terraform; the cd-* cards; a managed database; stating DigitalOcean prices, quotas or trial terms as facts.

## Tests written with the change

None (documentation). The executor checks every file name, path, variable, service name and command against the actual Docker files and the existing 11a, and that no real secret, hostname or key appears (placeholders only; `myshop-order.duckdns.org` style examples are fine if clearly marked as examples).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Every command, path and variable matches the Docker files and 11a | `code-reviewer` (review) |
| The three parts exist in the requested order, and the database part says plainly that there is no database container | `code-reviewer` (review) |
| The pre-deployment checklist is concrete and complete (secrets, DNS before up, backup before update, port 3000, disk/memory, post-deploy checks) | `code-reviewer` + `security-reviewer` (review) |
| No secrets or real hostnames; port 3000 never published; the `ufw` bypass is stated | `security-reviewer` (review) |
| No price or free-tier claim presented as fact | `code-reviewer` (review) |
| `make check` exit 0 or only the known analyze baseline | gate |
| The owner can follow it on a fresh Droplet | **owner acceptance, "unverified" until done** |

## Environment limits

Nothing here is run: no Docker, no sudo, no DigitalOcean account access, no DNS. State "unverified" in the section and in the review report.

Approvals: none needed for `docs/**`.

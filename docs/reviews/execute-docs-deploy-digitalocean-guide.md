---
task: docs-deploy-digitalocean-guide
status: passed
p0: 0
p1: 0
---

# Review: docs-deploy-digitalocean-guide

Changed: `docs/deploy.md` (new 3.3 "DigitalOcean" and section 11b with three parts: what runs where, a checklist for every deployment, domain setup; small edits in the title note, sections 1 and 3, 11a.1 and the acceptance table) and `docs/ci-cd-decisions.md` (HOST1 = DigitalOcean recorded 2026-11-25; HOST2 still open). No other file changed. The card is docs only; no approvals were needed.

## Gates

| Command | Exit | Note |
|---|---|---|
| `make format-check` | 0 | re-run after the last fixes |
| `make boundaries` | 0 | re-run after the last fixes |
| `make check` | 2 | stops at `make analyze`: 30 known infos, no Dart changed |

Nothing in the guide was run: no Docker, sudo, DNS or DigitalOcean access.

## Round 1 (code-reviewer): P0 0, P1 1, P2 5

- **P1 fixed:** the sudo user created in 11b.1 had a password, so `sudo` in 11a.5/11a.8 (`ssh ... 'sudo mkdir'`, `rsync --rsync-path="sudo rsync"`, the backup pull) would fail without a terminal. Now `adduser --disabled-password`, a `/etc/sudoers.d/90-SSH_USER` drop-in (mode 440, `visudo -c -f`), a `sudo -n true` check, and the trade-off stated.
- **P2 fixed:** checklist rows 8-9 could not pass before the source is sent: added a When column (A before sending, B after sending, C after `up -d`) and reordered first-install steps 6-10. Cross-reference 11a.4 to 11a.5 corrected. 3.3 list of applicable sections corrected. "Let's Encrypt does not issue for a bare IP" softened. Title and section 1 note added. Root SSH login disable added (`PermitRootLogin no` drop-in, `sshd -t`, second terminal, `sshd -T` check).
- **Minor fixed:** greps no longer use `\|`; `ss -ltn 'sport = :3000'` used for the port check.

## Round 2 / re-review (code-reviewer): P0 0, P1 0, P2 4, all fixed

- 3.3 now says 5.5, 5.6 and 5.9 are still read as references.
- Step 7 and checklist row 9 no longer build twice (skip if already built).
- Row 11 says it does not apply on a first install (no backup exists yet).
- Title note says "apart from two pointers to DigitalOcean"; the port 22 wording mentions the DigitalOcean console as the way back in if your address changes.
- 11a.1 now says only the lost-VM recipe of section 10 carries over (the keep-alive paragraph is Oracle-only), matching 3.3.

## Security review (security-reviewer): P0 0, P1 0, P2 2, both fixed

Root SSH login is now disabled with the second-terminal test and the `sshd -T` check; the cloud firewall wording restricts port 22 to the owner's own address and notes the Droplet is public on 22/80/443 until `ufw` and the firewall are on. Clean: no secret or real hostname committed, DuckDNS token kept out of the repo and shell history, port 3000 never published and the `ufw` bypass stated, certificate troubleshooting forbids `down -v` and never suggests disabling HTTPS, no checklist command prints secrets.

## Unverified (owner acceptance)

Every command in 11b; the sudo-user, root-login and cloud-firewall steps; the DigitalOcean console steps; DuckDNS and sslip.io behaviour and names; certificate issuance; the `grep` and `ss` checks; that a fresh Droplet can follow 11b end to end.

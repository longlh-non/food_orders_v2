# Deploy guide: food_orders on a free always-on VM

This is the owner's step-by-step guide to put the customer and restaurant apps on the public internet. **Nothing here has been run by an agent.** Agents cannot create cloud accounts, run `sudo`, or reach a server. Every step is "unverified" until you have done it on the real VM (see section 12).

Related: `docs/runbook-local.md` (running on your own laptop; section 8 there is the deploy status), `docs/ci-cd-decisions.md` (decisions), and the files in `deploy/` that this guide uses: `Caddyfile`, `food-orders-backend.service`, `build.sh`, `backup.sh`.

Placeholders you must replace: `customer.example.com`, `restaurant.example.com` (your domain), `SERVER_IP` (the VM's public address), `SSH_USER` (the login name on the VM; `ubuntu` on most Ubuntu images). Never paste real passwords, keys or hashes into this file or anywhere in the repo.

Conventions: commands starting with `sudo` change the server and are run by you on the VM. Lines under "On your laptop" run on your own machine.

---

## 1. Decision record: why a VM and not a PaaS free tier

The app needs three things at once: the server must be **always on** (the restaurant screen listens to a live stream, SSE), it needs a **persistent disk** (SQLite file and menu pictures), and it must keep **one long-lived connection per client**. Findings (third-party sources as of 2026-11-09, **second-hand: confirm on each provider's official page before relying on them**):

| Option | Why not |
|---|---|
| Render free web service | Sleeps after about 15 minutes idle; no persistent disk, so the SQLite file would be lost; the SSE connection drops. |
| Railway | A one-time trial, not a free tier. |
| Fly.io | No free tier for new organizations. |
| Koyeb free | Scales to zero and has no volume. |
| **Always-free VM (Oracle Cloud Always Free, Google Cloud e2-micro)** | Always on, real disk, you control the process. This is the chosen kind of hosting. |

Owner decisions already made (2026-11-13, recorded in `docs/ci-cd-decisions.md`):
- **HOST3 = A:** one shared username and password (Caddy basic auth) on both sites. This is not per-user login.
- **HOST5 = backups yes:** database and pictures, with a restore rehearsal (section 9).

**Still open, the owner decides:**
- **HOST1:** the provider (section 3: Oracle or Google).
- **HOST2:** the domain name (section 6).

Both Caddy and the backend run directly on the VM (no Docker; Docker is a non-goal). Deploys are by hand for now; the automatic deploy cards (`cd-server-deploy-script`, `cd-github-deploy-workflow`) are not built.

---

## 2. What ends up on the server

```
internet --443/80--> Caddy (HTTPS, shared password, static files)
                       |-- /var/www/food-orders/customer    (web build)
                       |-- /var/www/food-orders/restaurant  (web build)
                       '-- /api/*  -->  backend on 127.0.0.1:3000 (this machine only)
backend bundle:  /opt/food-orders/bundle/bin/server        (root-owned, read-only to the service)
database:        /var/lib/food-orders/orders.db            (service user only, mode 700 folder)
pictures:        /var/lib/food-orders/images/
backend secrets: /etc/food-orders/backend.env              (STAFF_ID, STAFF_PASSWORD; mode 600)
gate secrets:    /etc/caddy/food-orders-auth.env           (demo user + password hash; mode 600)
backups:         /var/lib/food-orders/backups/
```

Only ports **22 (SSH), 80 and 443** are ever opened. **Port 3000 is never opened**: the backend listens on `127.0.0.1` only (its default; the unit does not set `BIND_ADDRESS`, and you must never add `BIND_ADDRESS=0.0.0.0`). The proxy is what limits request size to 64 KB and adds the password, so nothing may reach the backend around it.

---

## 3. Provider steps (HOST1: owner decides)

**Pick one.** The choice also decides the CPU architecture, which matters because the backend is built **on the VM** (section 5.4): Oracle's free ARM machines (Ampere) are **arm64**; Google's e2-micro is **x86_64**. A program built on one does not run on the other. The web builds are plain files and do not care.

All facts below are **second-hand and dated 2026-11-09. Confirm limits, regions and prices on the official pages (Oracle Cloud "Always Free resources", Google Cloud "Free Tier") before you create the account.** Both need a payment card at signup.

### 3.1 Oracle Cloud Always Free

- Official page to check first: Oracle Cloud Infrastructure "Always Free Resources".
- Card needed for signup (identity check). Choose your **home region** carefully: it cannot be changed later, and Always Free resources live in the home region. For a user in Vietnam a nearer Asia region (for example Singapore) may exist, but **availability of the free shape in that region must be checked at signup**; popular regions sometimes have no free capacity ("out of capacity" when creating the instance; retry later or pick another availability domain).
- Shapes (second-hand): an Ampere A1 ARM instance (small free allowance of OCPUs and RAM) or a tiny x86 micro instance. Prefer the ARM one for RAM, accepting arm64.
- **Idle reclamation:** Oracle may reclaim Always Free instances it sees as idle for a long period (second-hand: low CPU, network and memory use over about a week). See section 10.
- Steps:
  1. Create the account and sign in to the console.
  2. Compute > Instances > Create instance. Image: **Ubuntu 24.04** (or the current LTS). Shape: the Always Free one (the console labels it).
  3. Networking: a public IPv4 address. Put the instance in a virtual cloud network (VCN) with a public subnet (the wizard can create one).
  4. SSH keys: paste the **public** key from step 4.1 below. Never upload the private key.
  5. Create. Note the public IP (`SERVER_IP`). In the console, make sure the IP is a **reserved** public IP if the console offers it for free, so a stop/start does not change it (confirm the pricing page).
  6. Cloud firewall (VCN > subnet > Security List, or a Network Security Group): ingress rules **TCP 22, 80, 443** from `0.0.0.0/0`. **Do not add a rule for 3000.**
  7. Second-hand gotcha: Oracle's Ubuntu images have had built-in `iptables` rules that reject everything except SSH, even after the cloud rules are open. Check with `sudo iptables -L INPUT -n --line-numbers` on the VM; if you see a `REJECT` rule above where your 80/443 rules would be, ask before editing it (do not flush the table). A common fix is inserting `ACCEPT` rules for 80 and 443 above it; mixing this with `ufw` needs care, so pick one tool. This is the one place this guide cannot tell you the exact line without seeing the output.

### 3.2 Google Cloud e2-micro

- Official page to check first: Google Cloud "Free Tier" (the Compute Engine "e2-micro" entry).
- Second-hand: one e2-micro per month free in certain **US regions only** (for example us-west1, us-central1, us-east1), 1 GB RAM (tight: see the swap note in section 5.4), a small free standard-persistent-disk allowance, and a monthly outbound-traffic allowance; a **static external IP can cost extra** (and an ephemeral one changes when the VM is stopped). From Vietnam, expect higher latency than a nearby region. Billing must be enabled (card) and a free trial may be offered separately.
- Steps:
  1. Create a project, enable billing and the Compute Engine API.
  2. Compute Engine > VM instances > Create. Machine type **e2-micro**, a free-tier region, boot disk **Ubuntu LTS** with the standard persistent disk (not the more expensive types), size within the free allowance.
  3. Firewall: tick "Allow HTTP traffic" and "Allow HTTPS traffic" (they create rules for ports 80 and 443). SSH (22) is allowed by the default network rule. **Create no rule for 3000.**
  4. Add your SSH **public** key in the VM's "SSH keys" metadata (step 4.1).
  5. Optional but recommended: reserve a static external IP (VPC network > IP addresses), after reading its price on the official pricing page. Without it, the address may change whenever the VM restarts and you must update DNS.
  6. Note the external IP (`SERVER_IP`).

---

## 4. First login and firewall

### 4.1 SSH key (on your laptop)

```bash
ssh-keygen -t ed25519 -C "food-orders-vm" -f ~/.ssh/food_orders_vm
cat ~/.ssh/food_orders_vm.pub     # this PUBLIC line is what you paste into the provider's console
```

Keep `~/.ssh/food_orders_vm` (the private key) on your laptop only. Never commit it or paste it anywhere.

```bash
ssh -i ~/.ssh/food_orders_vm SSH_USER@SERVER_IP
```

### 4.2 Update the system and turn on `ufw` (on the VM)

Follow the order exactly. The SSH rule goes **before** `ufw enable`, otherwise you lock yourself out.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ufw rsync sqlite3 curl git unzip
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp          # allow SSH, but rate-limit repeated new connections
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw show added            # check: only 22, 80, 443
sudo ufw enable
sudo ufw status verbose
```

Keep this SSH window open and, from a **second** terminal, confirm you can still log in before you close the first. Do not run `sudo ufw allow 3000`. (On Oracle, read the iptables gotcha in 3.1 first: it can interact with `ufw`.)

Optional, plain HTTP/3 uses UDP 443: skip it; HTTPS over TCP works everywhere.

Cloud images usually have password SSH login off already. Leave it off, and check what the SSH server really uses:

```bash
sudo sshd -T | grep -Ei 'passwordauthentication|permitrootlogin|kbdinteractiveauthentication'
```

Expect `passwordauthentication no`, `kbdinteractiveauthentication no` and `permitrootlogin no` (or `prohibit-password`). If not, fix it in `/etc/ssh/sshd_config.d/` and keep a second SSH window open while you test. Ubuntu installs security updates automatically by default (`unattended-upgrades`); check with `systemctl status unattended-upgrades`.

---

## 5. Server setup

### 5.1 Install Caddy

Install Caddy from its **official** instructions for Debian/Ubuntu (https://caddyserver.com/docs/install), which add Caddy's apt repository. Verify the repository's signing key fingerprint against the one on the official page before you trust it, and never pipe a downloaded script into a shell (`curl ... | sh`). Then:

```bash
caddy version
systemctl is-active caddy
```

**Version note:** `deploy/Caddyfile` was checked on **Caddy 2.6.2**, which uses the directive name `basicauth`. The apt repository may install a newer Caddy. On newer Caddy, `basicauth` still works as a deprecated alias; if `caddy validate` (5.7) complains, rename it to `basic_auth` in your server copy of the Caddyfile. Do not change anything else because of the version.

Caddy runs as a systemd service as its own user `caddy` and binds 80/443 itself.

### 5.2 Install the Dart SDK

Install the Dart SDK for **your VM's architecture** from the official instructions (https://dart.dev/get-dart, the Linux/apt method or the zip), again checking the signing key or checksum on the official page and not piping a script to a shell. The backend needs SDK `^3.13.0` or newer (`backend/pubspec.yaml`); the version you develop with is 3.14. Check:

```bash
dart --version
uname -m        # x86_64 or aarch64: the backend must be built here, not on your laptop
```

### 5.3 Service user and folders

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin food-orders
sudo mkdir -p /var/lib/food-orders/images
sudo chown -R food-orders:food-orders /var/lib/food-orders
sudo chmod 700 /var/lib/food-orders /var/lib/food-orders/images
sudo mkdir -p /etc/food-orders /opt/food-orders /var/www/food-orders/customer /var/www/food-orders/restaurant
sudo chown -R "$USER":"$USER" /var/www/food-orders
```

(The `/opt/food-orders` folder is made world-readable in 5.4 after its `chown`.)

The images folder must exist and belong to `food-orders` **before** the first start: the unit makes it read-only to the service, so the backend cannot create it itself. `/var/www/food-orders` belongs to your login so `rsync` can fill it without `sudo`; Caddy only needs to read it.

### 5.4 Build the backend on the VM

`dart compile exe` does **not** work for this backend: the `sqlite3` package uses a build hook, and `dart compile` refuses it ("does not support build hooks"). Use `dart build cli`, which produces a **bundle**: `bin/server` plus `lib/libsqlite3.so` and `lib/libdartaotserver.so`. The program needs those `.so` files beside it, so the whole bundle is installed, not just `server`.

Get the backend source onto the VM, from your laptop (excludes the database and caches):

```bash
# On your laptop, from the project root:
ssh -i ~/.ssh/food_orders_vm SSH_USER@SERVER_IP 'mkdir -p ~/food-orders-src'
rsync -a --exclude data/ --exclude .dart_tool/ --exclude build/ \
  -e "ssh -i ~/.ssh/food_orders_vm" backend/ SSH_USER@SERVER_IP:~/food-orders-src/backend/
rsync -e "ssh -i ~/.ssh/food_orders_vm" deploy/food-orders-backend.service deploy/backup.sh deploy/Caddyfile \
  SSH_USER@SERVER_IP:~/food-orders-src/
```

Build and install (on the VM). The first build downloads a precompiled SQLite, so it needs network access:

```bash
cd ~/food-orders-src/backend
dart pub get          # uses the committed pubspec.lock; do not run `dart pub upgrade`
dart build cli -t bin/server.dart -o "$HOME/food-orders-build"
ls "$HOME/food-orders-build/bundle/bin/server" "$HOME/food-orders-build/bundle/lib" && \
sudo mkdir -p /opt/food-orders/bundle && \
sudo rsync -a --delete "$HOME/food-orders-build/bundle/" /opt/food-orders/bundle/
sudo chown -R root:root /opt/food-orders
sudo chmod -R go+rX /opt/food-orders
```

The bundle is root-owned: the service user can run it but not change it, and `go+rX` lets it read and run the files. If `dart build cli -o` refuses because the output folder already exists, remove that one folder by its full name (`rm -r ~/food-orders-build`, typed out, with no variables) and run the build again.

**e2-micro (1 GB RAM):** the build may run out of memory. If it does, add a swap file first (one-time):

```bash
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

(Make it permanent by adding `/swapfile none swap sw 0 0` to `/etc/fstab` with `sudoedit /etc/fstab`; a typo there can stop the VM booting, so double-check.)

### 5.5 Backend secrets (`backend.env`)

Create the file empty with the right owner and mode **before** typing secrets into it:

```bash
sudo install -m 600 -o food-orders -g food-orders /dev/null /etc/food-orders/backend.env
sudoedit /etc/food-orders/backend.env
```

Contents (your own values; see `CLAUDE.md` "Staff ID and password": the ID is 1-64 plain printable characters, the password at least 12, no Vietnamese accents; get a random one with `openssl rand -hex 12`):

```
STAFF_ID=your-staff-id
STAFF_PASSWORD=your-long-random-password
```

Optional shop and bank transfer values (`SHOP_NAME`, `SHOP_ADDRESS`, `SHOP_TAX_CODE`, `SHOP_REPRESENTATIVE`, `SHOP_LOCATION`, and `BANK_NAME`, `BANK_BIN`, `BANK_ACCOUNT`, `BANK_ACCOUNT_NAME`) go in the same file; without the `BANK_*` set, bank transfer orders answer 503. See `backend/lib/shop_settings.dart` for the rules.

This staff password is **different** from the shared website password in 5.6. Never commit either, and keep them in a password manager. The file lives on the server only.

### 5.6 The shared website password (Caddy gate, HOST3)

All of both sites, including `/api/*` and the live stream, sits behind one shared username and password. Make the hash on the VM (the password is typed at a prompt, never on the command line):

```bash
caddy hash-password          # type the password twice; copy the line starting with $2a$
sudo install -m 600 -o root -g root /dev/null /etc/caddy/food-orders-auth.env
sudoedit /etc/caddy/food-orders-auth.env
```

Contents (single quotes keep the `$` signs):

```
FOOD_ORDERS_AUTH_USER=demo
FOOD_ORDERS_AUTH_HASH='$2a$14$...the line you copied...'
```

Give Caddy that file through a systemd drop-in:

```bash
sudo systemctl edit caddy
```

In the editor, add exactly:

```
[Service]
EnvironmentFile=/etc/caddy/food-orders-auth.env
```

Save, then **restart** (not reload) Caddy when you finish 5.7, because environment values are read at start. If both values are unset, every request gets 401 (it fails closed); if only the hash is unset, Caddy refuses to load the file. Use a long random password (20 or more characters, for example `openssl rand -base64 18`): the hash is costly to compute, so many wrong guesses cost the server CPU, and Caddy has no rate limit of its own. Set up `fail2ban` (or an equivalent rate limit) as in 5.9; it is a recommended step, not an option. Careful when you write the filter: normal use produces many harmless 401s (the first request of every visit, before the browser asks for the password; the manifest; an uptime pinger), and the restaurant staff share one network address, so count only 401s that carried an `Authorization` header (Caddy's JSON log shows the header as `REDACTED`), use a high `maxretry`, and whitelist your own and the pinger's addresses. Caddy writes no access log until you add a `log` directive to the Caddyfile. Share the password with viewers by a channel other than this repo.

### 5.7 The Caddyfile

```bash
sudo cp ~/food-orders-src/Caddyfile /etc/caddy/Caddyfile
sudoedit /etc/caddy/Caddyfile      # replace customer.example.com and restaurant.example.com with your hostnames
```

The file also holds the cross-site guard: inside each site's `/api/*` block, a request whose `Sec-Fetch-Site` header is `cross-site` gets **403** (see section 11), the gate password is not forwarded to the backend (`header_up -Authorization`; the `X-Staff-*` headers still pass), and pages cannot be framed (`X-Frame-Options`). Leave everything else, in particular the `/api/*` block, `request_body { max_size 64KB }`, `flush_interval -1` and automatic HTTPS (never add `auto_https off`). The `root` paths already match section 5.3. Check and start:

```bash
sudo systemctl restart caddy
systemctl is-active caddy
sudo journalctl -u caddy -n 30 --no-pager
```

You can also run `caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile`, but it reads the environment values from your own shell, not from the service, so it may report the missing hash even though the service has it. Trust the journal and the checks in section 8 instead.

Certificates are requested automatically on the first request once DNS points at the VM (section 6).

### 5.8 Install and start the backend service

```bash
sudo cp ~/food-orders-src/food-orders-backend.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now food-orders-backend
systemctl status food-orders-backend --no-pager
sudo journalctl -u food-orders-backend -n 30 --no-pager
curl -s http://127.0.0.1:3000/menu | head -c 300
ss -ltnp | grep 3000          # must show 127.0.0.1:3000, never 0.0.0.0 or [::]
```

Expect the log to say `staff routes: enabled` and the menu JSON to start printing. A brand-new database is created with the starting menu. Then run `systemd-analyze security food-orders-backend` and read what it flags. Further hardening ideas to try, all unverified: `RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX`, `SystemCallFilter=@system-service`, `ProtectProc=invisible`, and `MemoryDenyWriteExecute=true` (Dart's AOT runtime may need an exception for that one). If a hardening option breaks the built bundle, the journal says why; this has **not** been tried on a real server.

Copy photos in (they need to be owned by the service user; see `CLAUDE.md` "Adding a picture" for names and sizes):

```bash
# On your laptop:
rsync -av -e "ssh -i ~/.ssh/food_orders_vm" ./photos/ SSH_USER@SERVER_IP:~/photos/
# On the VM:
sudo cp ~/photos/xoi-thit.webp /var/lib/food-orders/images/
sudo chown food-orders:food-orders /var/lib/food-orders/images/xoi-thit.webp
sudo -u food-orders sqlite3 /var/lib/food-orders/orders.db "UPDATE menu_items SET image = 'xoi-thit.webp' WHERE id = 'xoi-thit'"
```

Install the backup script now, so the first-install flow is complete (the schedule and the restore are explained in section 9):

```bash
sudo install -m 755 -o root -g root ~/food-orders-src/backup.sh /opt/food-orders/backup.sh
cd / && sudo -u food-orders /opt/food-orders/backup.sh
sudo ls -l /var/lib/food-orders/backups
```

Other menu edits work the same way (`CLAUDE.md` "Editing the menu"): prefix the `sqlite3` command with `sudo -u food-orders` and the path `/var/lib/food-orders/orders.db`. Take a backup before bigger edits.

### 5.9 Slow down password guessing (recommended)

Caddy checks the shared password with bcrypt, which is deliberately slow, so a bot trying many passwords costs the VM CPU and Caddy does not limit it. Install `fail2ban` and add a jail that bans addresses with repeated 401 answers in Caddy's log (needs the log turned on in the Caddyfile; the exact jail depends on your log setup, so follow fail2ban's documentation and test the ban), or use an equivalent rate limit in front of the VM. This is **unverified** here. Together with a long random gate password it is the real protection against guessing.

---

## 6. Domain and DNS (HOST2: owner decides)

You need a domain you control (bought from any registrar; the cost and rules are the registrar's, not covered here). At your DNS provider create two **A records** pointing at the VM:

| Name | Type | Value |
|---|---|---|
| `customer` (customer.example.com) | A | `SERVER_IP` |
| `restaurant` (restaurant.example.com) | A | `SERVER_IP` |

Add AAAA records only if the VM has a working public IPv6 address and the firewall allows it; otherwise skip them. Check from your laptop:

```bash
dig +short customer.example.com
dig +short restaurant.example.com
```

Both must print `SERVER_IP` before Caddy can get certificates (DNS changes may take minutes to hours). Caddy then fetches and renews certificates itself; ports 80 and 443 must stay reachable. Do not request certificates over and over while DNS is wrong: the certificate authority rate-limits failed attempts. If you ever change the VM's IP, update both records.

---

## 7. Release procedure

A release is the two web builds plus (only when the backend changed) a new backend bundle. Build the web apps and the backend from the **same revision**, because they share one API contract (`CLAUDE.md` "Backend").

### 7.1 Web apps (every release)

```bash
# On your laptop, project root:
export PATH="$HOME/development/flutter/bin:$PATH"
make check                      # optional but recommended
deploy/build.sh                 # writes build/customer and build/restaurant
test -f build/customer/index.html && test -f build/restaurant/index.html && \
rsync -a --delete --chmod=D755,F644 -e "ssh -i ~/.ssh/food_orders_vm" build/customer/   SSH_USER@SERVER_IP:/var/www/food-orders/customer/ && \
rsync -a --delete --chmod=D755,F644 -e "ssh -i ~/.ssh/food_orders_vm" build/restaurant/ SSH_USER@SERVER_IP:/var/www/food-orders/restaurant/
# (chained with && so a missing index.html stops the copy: --delete would otherwise wipe the live site)
```

If either `ls` fails, stop: syncing an empty build with `--delete` would wipe the live site. Mind the trailing `/` on both sides of each line: it means "the contents of this folder". `--delete` removes files on the server that are not in the build, so the target paths must be exactly the two web folders and nothing else.

Static files are read from disk on each request, so a **Caddy reload is not needed** for a web-only release. Reload only after changing the Caddyfile: `sudo systemctl reload caddy` (use `restart` if you changed the gate environment file).

The first visit after a release may still show the old version for a returning visitor (see the stale `index.html` risk in section 11); tell staff to hard-reload (Ctrl+Shift+R, or close and reopen the tab).

### 7.2 Backend update (only when `backend/` changed)

A schema step runs automatically when the new backend starts, and **cannot be undone**, so take a backup first (`CLAUDE.md` "Storage").

```bash
# 1. On the VM: backup first
cd / && sudo -u food-orders /opt/food-orders/backup.sh

# 2. On your laptop: send the new source (same rsync as 5.4)
# 3. On the VM: build next to the running one (the service keeps running)
cd ~/food-orders-src/backend
dart pub get
dart build cli -t bin/server.dart -o "$HOME/food-orders-build"
# 4. Check the NEW bundle is complete BEFORE touching the running one. If the
#    build refused because the folder exists, remove that one folder
#    (rm -r ~/food-orders-build, typed out) and build again.
ls "$HOME/food-orders-build/bundle/bin/server" "$HOME/food-orders-build/bundle/lib"
# 5. Only now keep the previous (good) bundle for a rollback, then swap
sudo rsync -a --delete /opt/food-orders/bundle/ /opt/food-orders/bundle.prev/
sudo systemctl stop food-orders-backend
sudo rsync -a --delete "$HOME/food-orders-build/bundle/" /opt/food-orders/bundle/
sudo chown -R root:root /opt/food-orders
sudo chmod -R go+rX /opt/food-orders
sudo systemctl start food-orders-backend
sudo journalctl -u food-orders-backend -n 30 --no-pager
curl -s http://127.0.0.1:3000/menu | head -c 200
```

(`backup.sh` is installed in 5.8. If a backend update fails on the swap and you already ran step 5 once, do not run step 5 a second time: it would overwrite `bundle.prev` with the bad bundle.)

**Rollback:** stop the service, `sudo rsync -a --delete /opt/food-orders/bundle.prev/ /opt/food-orders/bundle/`, start it. **This restores the previous program only, not the database.** If the new version already ran a schema step, the older program may not understand the database; restore the backup taken in step 1 (section 9.5).

---

## 8. Checks after setup (owner acceptance)

All of these are **unverified until you do them**:

1. From your laptop: `curl -sI https://customer.example.com/` returns **401** without a login, and **200** with it (`curl -sI -u demo https://customer.example.com/`, which prompts for the password instead of putting it in the command). Same for the restaurant host.
2. `curl -sI http://customer.example.com/` redirects to `https://` (Caddy's default).
3. On the VM: `ss -ltnp | grep 3000` shows `127.0.0.1:3000` only. **Port 3000 is closed from outside.** From a different network (for example a phone on mobile data, or any other machine): `curl -m 5 http://SERVER_IP:3000/menu` must fail or time out. If it answers, stop and fix the firewall before anything else.
   An external uptime pinger must **not** get the shared password: a `401` answer already proves Caddy is up, so count 401 as up.
4. On a phone **on mobile data (not your home wifi)**: open `https://customer.example.com`, enter the shared password, place an order. It shows up live on `https://restaurant.example.com` (open on another device or tab). Browser behaviour with basic auth is unverified: the live stream should reuse the page's credentials, and the service worker and manifest requests may behave differently (section 11).
5. Orders survive `sudo systemctl restart food-orders-backend` and a full `sudo reboot` of the VM (the backend and Caddy are enabled, so they come back by themselves).
6. A staff login works in the restaurant app (the staff ID and password from 5.5, separate from the shared website password).
7. A photo copied to the images folder shows on the menu over HTTPS.
8. A backup is created and a restore rehearsed (section 9).

---

## 9. Backups and restore (HOST5)

`deploy/backup.sh` writes a matching pair per run into `/var/lib/food-orders/backups/`: `orders-DATE.db` (made with `sqlite3 .backup`, safe while the server runs) and `images-DATE.tar.gz`, keeping the last 14 pairs. The files are mode 600 and hold customer names: do not email them or commit them.

### 9.1 Install and run once

The script is installed and run once in 5.8 (first install). Run it again any time with:

```bash
cd / && sudo -u food-orders /opt/food-orders/backup.sh
sudo ls -l /var/lib/food-orders/backups
```

### 9.2 Schedule it (daily)

Use root's crontab so the job runs as the service user without a login shell:

```bash
sudo crontab -e
```

Add this line (daily at 03:17 server time):

```
17 3 * * * cd / && runuser -u food-orders -- /opt/food-orders/backup.sh 2>&1 | logger -t food-orders-backup
```

Check the next day with `sudo journalctl -t food-orders-backup -n 20 --no-pager` and `sudo ls -l /var/lib/food-orders/backups`. **Unverified until you see the files appear.**

### 9.3 Copy backups off the VM

Backups on the same disk do not survive losing the VM. Pull them to your laptop now and then (the folder is owner-only, so the remote `rsync` runs with `sudo`; the default login on the Ubuntu cloud images has that right):

```bash
# On your laptop:
mkdir -p ~/food-orders-backups
rsync -av --rsync-path="sudo rsync" -e "ssh -i ~/.ssh/food_orders_vm" SSH_USER@SERVER_IP:/var/lib/food-orders/backups/ ~/food-orders-backups/
```

Keep them somewhere private; they contain customer names. A compromised backend runs as the service user and could change or delete its own backups on the same disk, so an offsite copy (this pull) is the one that counts.

### 9.4 Restore rehearsal (does not touch live data)

Do this once soon after setup, and again after big changes. It only **reads** a backup:

```bash
# On the VM. Replace the date part with a real file name from the folder.
cd / && sudo -u food-orders sqlite3 -readonly /var/lib/food-orders/backups/orders-2026-11-22-031700.db "PRAGMA integrity_check; PRAGMA user_version; SELECT count(*) FROM orders;"
sudo tar -tzf /var/lib/food-orders/backups/images-2026-11-22-031700.tar.gz | head
```

Expect `ok`, the schema version, your order count, and the picture names. For a fuller rehearsal, pull a backup to your laptop (9.3) and start the backend against it with `ORDERS_DB=/path/to/copy.db dart run bin/server.dart` from `backend/`.

### 9.5 Real restore (only when you need it)

```bash
sudo systemctl stop food-orders-backend
sudo cp -p /var/lib/food-orders/orders.db /var/lib/food-orders/orders.before-restore.db
sudo install -m 600 -o food-orders -g food-orders /var/lib/food-orders/backups/orders-2026-11-22-031700.db /var/lib/food-orders/orders.db
sudo rm -f /var/lib/food-orders/orders.db-wal /var/lib/food-orders/orders.db-shm /var/lib/food-orders/orders.db-journal
cd / && sudo -u food-orders tar -xzf /var/lib/food-orders/backups/images-2026-11-22-031700.tar.gz -C /var/lib/food-orders --no-same-owner
sudo chown food-orders:food-orders /var/lib/food-orders/orders.db
sudo chmod 700 /var/lib/food-orders /var/lib/food-orders/images
sudo systemctl start food-orders-backend
```

The `cp -p` line errors harmlessly if there is no database yet. Use the matching pair (same timestamp). The `rm -f` line names three leftover side files of the old database, which must not sit next to the restored one. If the backup is from an older schema, the backend upgrades it on start.

---

## 10. Keep-alive (Oracle) and a lost VM

**Oracle idle reclamation (second-hand, confirm on Oracle's current Always Free terms):** instances that look idle for a long time may be stopped or reclaimed. Mitigation: the backend and Caddy are always running, so real use counts; check the console now and then, and read the page for the current thresholds. Upgrading the account to pay-as-you-go while staying inside the free resources is reported to avoid reclamation, but confirm that with Oracle and mind the billing risk. Do not run fake busy-work loops without reading the terms. A tiny external uptime pinger does not count as CPU activity but does tell you when the VM is down. Google's e2-micro has no such rule (second-hand).

**If the VM is lost** (deleted, reclaimed, broken): rebuild from this guide.
1. Create a new VM (section 3) and follow sections 4 and 5. Keep the password for the shared gate and the staff ID and password in your password manager: `backend.env` and `food-orders-auth.env` are not in any backup and must be recreated.
2. Update the two A records to the new `SERVER_IP` (section 6).
3. Copy the latest backups from your laptop back to the VM, then do the real restore (9.5; the first run of the backend creates the empty folders and database, so stop it before restoring):

   ```bash
   # On your laptop:
   rsync -av -e "ssh -i ~/.ssh/food_orders_vm" ~/food-orders-backups/ SSH_USER@SERVER_IP:~/restore/
   # On the VM:
   sudo systemctl stop food-orders-backend
   sudo install -d -o food-orders -g food-orders -m 700 /var/lib/food-orders/backups
   sudo install -m 600 -o food-orders -g food-orders ~/restore/orders-DATE.db ~/restore/images-DATE.tar.gz /var/lib/food-orders/backups/
   ```

   Then run the commands of 9.5 with those two file names. `cp -p orders.db` there errors harmlessly if no database exists yet.
4. Run a web release (7.1). Re-check section 8.

Backups you never copied off the VM are lost with it; this is why 9.3 matters.

---

## 11. Known risks and weak points (stated plainly)

- **No real authentication.** One shared website password (HOST3) is all that stands between the internet and the apps, and it is shared by everyone who knows it. The customer routes themselves have no login: anyone who passes the gate can read all orders (`GET /orders` and the stream list every order and customer name) and can switch unpaid transfer orders to cash. This matches the accepted risks in `CLAUDE.md`. Real customer accounts are needed before real customers. Prices are also trusted from the client until MENU-DB3.
- **Free tiers can change or be withdrawn.** Prices, limits and regions here are second-hand and dated 2026-11-09. Re-check the official pages periodically.
- **Single VM, no redundancy.** One machine, one disk. If it dies you are down until you rebuild (section 10). Backups are daily at best; orders since the last backup are lost.
- **Plain updates by hand.** Security updates for Ubuntu are automatic by default; Caddy, the Dart SDK and the backend's packages are not. Update them on purpose.

Open follow-ups from the reviews of the Caddy config (P2, not blockers for a demo; to do later):
- **No HSTS yet.** Caddy's `http` to `https` redirect happens before the password check, so the password is never sent over plain `http`, and browsers cache the credentials per origin (scheme included). The real risk is an attacker on the same network stripping the TLS upgrade (SSL-strip) or showing a fake login page on the first visit. Tell viewers to type or bookmark `https://` only, and once certificates work add `header Strict-Transport-Security "max-age=31536000"` to both site blocks.
- **No rate limit, bcrypt cost 14.** Each wrong password costs the server about a second of CPU, so guessing can also slow the VM down. A long random gate password plus `fail2ban` or an equivalent rate limit (5.9) is a recommended step.
- **`@nocache` does not cover `/` or deep links.** The no-cache header applies to `/index.html` and `/flutter_service_worker.js` only, so a returning visitor may see an old `index.html` after a deploy. A hard reload fixes it.
- **Manifest and service worker behind basic auth.** The browser may fetch `manifest.json` without credentials and get 401 (the `crossorigin` attribute in `web/index.html`). Harmless for the app itself, may only affect "install as app". Unverified.
- **Cross-site requests with saved credentials (fixed in the Caddyfile).** After a viewer logs in, their browser keeps the gate credentials, and the backend does not check `Content-Type`. A hostile web page could therefore send a "simple" cross-site `POST` (type `text/plain`, no-cors) to `https://<host>/api/orders` with those credentials attached, and so get past the gate. `deploy/Caddyfile` now answers any `/api/*` request with `Sec-Fetch-Site: cross-site` with **403** before it reaches the backend, and does not forward the `Authorization` header. Tested locally on Caddy 2.6.2 with a stand-in backend (cross-site 403, same-origin and no-header requests pass); not tested with a real browser. Limits: it relies on browsers sending `Sec-Fetch-Site` (current Chrome, Firefox and Safari 16.4 or newer do; an older browser, for example an iPhone that can no longer update past Safari 16.3, sends none and is NOT protected, so do not share the URL with viewers on such devices), and it does not stop a hostile page on a sibling site such as `restaurant.` calling `customer.` as `same-site`; the apps only call their own origin, so refusing `same-site` as well would be a later hardening step. A backend `Content-Type` check remains an optional second layer.
- **A stale password makes the stream reconnect noisily** (every 2 s, harmless).
- **Backup files are mode 600 but unencrypted** and sit on the same disk until you copy them off.
- **Gate scope:** the cross-site guard covers `/api/*` only; the static pages hold no data. Responses also carry `X-Frame-Options: DENY` and `frame-ancestors 'none'` (no framing); whether the Flutter service worker or any browser behaves oddly with these is unverified.
- **Not verified on a real server:** every command here, the systemd hardening against the built bundle, ARM versus x86 builds, Oracle's iptables behaviour, and browser behaviour behind the gate.
- Old problem now fixed, for the record: an earlier `deploy/Caddyfile` rewrote every `/api/*` request to `/index.html`; the `handle` blocks in the current file prevent that.

---

## 12. Acceptance status

| Item | Status |
|---|---|
| Commands accurate and safe, no secrets in this file | reviewed by the reviewers; **commands not run** |
| Owner can follow this end to end on a fresh VM | **unverified**, until you complete it |
| Phone on mobile data reaches the site, asks for the password, order appears live | **unverified** |
| Orders survive a service restart and a reboot | **unverified** |
| Port 3000 closed from outside, 80 redirects to 443 | **unverified** |
| Backup created and restore rehearsed | **unverified** |

# Runbook: running food_orders on your own machine

Every task you do by hand, in one place: start, restart, back up, upgrade, configure, check. Commands are copy-paste. Run them from the project folder (`~/flutter_projects/food_orders`) unless a step says otherwise.

- `CLAUDE.md` stays the full reference (API, order rules, menu examples). This page links to it instead of repeating long parts.
- The hosted server (VM) will get its own guide, `docs/deploy.md`, once the deploy cards run.

Prerequisite in every new terminal (already in `~/.bashrc`):

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

---

## 1. Start everything

Four processes, each in its own terminal, in this order.

**1. Backend** (port 3000; it stores orders and the menu):

```bash
cd backend
dart pub get                       # first time, or after backend/pubspec.yaml changes
read -r STAFF_ID && read -rs STAFF_PASSWORD && export STAFF_ID STAFF_PASSWORD && dart run bin/server.dart
```

- It waits for two lines: type the staff ID and press Enter, then the staff password and press Enter. The ID is shown as you type; the password isn't (see section 4).
- To start without staff editing, just run `dart run bin/server.dart`.
- It prints where the database and pictures are, and whether staff routes are `enabled` or `disabled`.

**2. Customer app** (port 8080):

```bash
flutter run -t lib/customer/main.dart -d web-server --web-hostname=0.0.0.0 --web-port=8080
```

**3. Restaurant app** (port 8081):

```bash
flutter run -t lib/restaurant/main.dart -d web-server --web-hostname=0.0.0.0 --web-port=8081
```

**4. Reverse proxy.** Caddy runs as a system service, so there's nothing to start each time. Check it's up with `systemctl is-active caddy`. Only after editing `dev/Caddyfile`, reload it (section 2).

Then open http://customer.local and http://restaurant.local.

**Split-screen demo** (optional; the customer app on the left and the restaurant app on the right, sharing one state):

```bash
flutter run -t lib/dev/demo.dart -d chrome --web-port=8082
```

Why this order: the apps load the menu and orders from the backend when they open.
- **Backend not up yet:** the customer menu shows "Couldn't load the menu" with **Retry**. The live order stream reconnects by itself every few seconds.
- **Once the backend is up:** tap Retry or reload the page.

---

## 2. Restart or reload after a change

| I changed… | So I do… |
|---|---|
| Flutter code (`lib/`) | In that app's `flutter run` terminal press **`R`** (hot restart), then hard-refresh the page (**Ctrl+Shift+R**; on iPhone, reload). If the page doesn't change, press **`q`** and start the app again. |
| Backend code (`backend/`) | Stop the backend (**Ctrl+C**) and start it again (section 1). There is no hot reload for the backend. **Always restart after backend code changes:** a backend left running with old code once refused every new order (400). |
| A new schema step in `backend/lib/database.dart` | Back up first (section 3), then restart the backend. The upgrade runs on start. |
| `pubspec.yaml` (either one) | `make bootstrap` (runs `flutter pub get` and `dart pub get` in `backend/`), then restart what changed. |
| `dev/Caddyfile` (for example the 64 KB body limit) | `sudo cp dev/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy` |
| `web/manifest.json` (splash and browser-bar colours) | Nothing shows locally. `flutter run` doesn't serve it ("manifest not generated in run mode"); it only applies to a real build (`flutter build web`). |
| Your wifi network | `sudo systemctl restart 'food-orders-mdns@*'`, so phones find `customer.local` at the new address. |

About `r` and `R` in the `flutter run` terminal: Flutter 3.47 lists **`r` = hot reload**, **`R` = hot restart** and **`q` = quit**, also with `-d web-server`.
- The same terminal warns: "The web-server device requires the Dart Debug Chrome extension for debugging".
- **Unverified:** whether `r`/`R` reach an ordinary browser tab without that extension.
- The safe routine is **`R` plus a hard refresh**; if nothing changes, **`q` and start again**.
- Pulling someone else's changes: do whichever rows above apply (Flutter only, backend only, proxy only, or `make bootstrap`).

---

## 3. Database

**Where it lives:**
- The database is `backend/data/orders.db`. Set `ORDERS_DB=/path/to/file.db` before starting the backend to use another file.
- Menu pictures are in `backend/data/images/`. `IMAGES_DIR=/path` overrides it.
- Both are git-ignored (they hold customer names and your photos); never commit them.

**Schema version:** the database upgrades itself step by step on start. It's at **version 6** now:
- 1: orders;
- 2: menu;
- 3: categories and toppings;
- 4: Ăn vặt;
- 5: pictures;
- 6: sold-out.

Check it with `sqlite3 backend/data/orders.db "PRAGMA user_version"`. A failed step rolls back completely and leaves the old version.

**Backup.** Always back up before starting a backend that has a new schema step, and before big hand edits.

```bash
# backend stopped:
cp backend/data/orders.db "backend/data/orders.$(date +%F-%H%M).db"
# or while it runs (needs the sqlite3 CLI):
sqlite3 backend/data/orders.db ".backup backend/data/orders.$(date +%F-%H%M).db"
```

- Back up the pictures with the database: `cp -r backend/data/images "backend/data/images.$(date +%F-%H%M)"`.
- Copies next to the original don't survive a disk failure; copy one elsewhere now and then.

**Restore** (unverified on your real database until you try it once):
1. Stop the backend (Ctrl+C).
2. Keep the current file just in case: `cp backend/data/orders.db backend/data/orders.before-restore.db`
3. Copy the backup you want back: `cp backend/data/orders.2026-11-17-0414.db backend/data/orders.db` (use your file's name).
4. If you also backed up pictures, copy that folder back over `backend/data/images/`.
5. Start the backend. If the backup is from an older schema version, it upgrades again on start.

**Editing the menu and pictures:**
- Use the `sqlite3` CLI (install once: `sudo apt install sqlite3`). The examples (change a price, add an item, Ăn vặt, toppings, pictures, sold out) are in `CLAUDE.md` → "Editing the menu".
- Staff can also change a price or sold-out over HTTP with the staff ID and password (section 4).
- To add a picture:
  1. copy the file into `backend/data/images/`. Name rules: lowercase letters, digits and `-`, starting with a letter or digit, up to 64 characters before the extension, then `.jpg`, `.jpeg`, `.png` or `.webp`. The file is at most 1 MiB (the full rule is in `CLAUDE.md` → "Editing the menu");
  2. set it with `sqlite3`;
  3. check it at `http://customer.local/api/images/<name>`.

**When the order store is full:**
- The backend keeps at most **10,000 orders**. After that, new orders get "Order storage is full" (503); old orders are never deleted automatically.
- To make room: stop the backend, back up, then delete old finished orders. In this example, **change the date**: it removes delivered and cancelled orders placed before it.

  ```bash
  sqlite3 backend/data/orders.db "DELETE FROM orders WHERE status IN ('delivered', 'cancelled') AND placed_at < '2026-01-01'"
  ```

- The restaurant screen shows only the newest 500 orders.

**Never delete `orders.db` to "re-seed".** That wipes every order and resets the menu to the starting list.

---

## 4. Staff ID and password

Staff-only routes need one shared staff ID and password, set when the backend starts. Today they are the month export (the restaurant app's "Export month" button, `GET /api/orders/export`) and changing a price or sold-out (`PATCH /api/menu/<id>`).

**What changed for you:** the old `STAFF_TOKEN` is no longer used. Start the backend with `STAFF_ID` and `STAFF_PASSWORD`, otherwise the export and menu edits stay off (403).

- **Choose them once and keep them safe** (password manager).
  - The ID is 1–64 characters, e.g. `staff`.
  - The password is at least 12 characters. A random one: `openssl rand -hex 12`.
  - Plain letters, digits and symbols only, with no Vietnamese accents: browsers refuse other characters in request headers.
  - Spaces at the start or end are ignored, so don't rely on them.
- **Start with them:**
  ```bash
  cd backend
  read -r STAFF_ID && read -rs STAFF_PASSWORD && export STAFF_ID STAFF_PASSWORD && dart run bin/server.dart
  ```
  Type the ID and press Enter, then the password and press Enter. The ID is shown as you type; the password isn't, and neither value lands in your shell history.
  - Typing `export STAFF_PASSWORD=...` on the command line *would* save it in history, so don't.
  - The values exist only in that terminal; a second terminal doesn't have them.
- **What the answers mean:**
  - **401:** the ID or password is missing or wrong. The server never says which half was wrong.
  - **403:** staff routes are off: the backend was started without valid values.
  - **429:** locked; see the next point.
- **The one-minute lock:**
  - After **5 wrong tries within 60 seconds**, every staff request, even a correct one, is refused for 60 seconds.
  - The lock is for everyone, not per person: behind the proxy every request looks the same.
  - It stops someone on the wifi from guessing the password. The catch is that they can lock staff out for a minute at a time.
- **Changing them:**
  1. Stop the backend (Ctrl+C).
  2. Start it again with new values, using the `read` line above.
  3. Check them (below), then tell staff the new pair.

  There's nowhere else they're stored, so there's nothing to clean up in the database. The old pair stops working at once. An open restaurant tab says "Wrong staff ID or password" until the new pair is typed.
- **Never** write them into a file inside the project, and never commit them.
- **They cross your wifi in plain text.** `http://restaurant.local` has no HTTPS, so anyone on the same network who captures traffic could read them, and with them download customer names. Use them only on a wifi you trust until HTTPS is set up (for hosting, see the deploy cards).
- **Example edit** (this marks Trà đá sold out):

  ```bash
  curl -X PATCH -H "X-Staff-Id: $STAFF_ID" -H "X-Staff-Password: $STAFF_PASSWORD" \
    -H 'Content-Type: application/json' \
    -d '{"available": false}' http://customer.local/api/menu/tra-da
  ```

  This only works in a terminal where you've already set both (the same `read … && export STAFF_ID STAFF_PASSWORD` step). On a shared machine, put the headers in a file and use `curl -H @file`, so other users can't see them with `ps`.

### How to check your staff ID and password

None of these steps prints the password, not even its length.

**1. In the terminal that will start the backend** (before `dart run`):

```bash
[ -n "$STAFF_ID" ] && echo "STAFF_ID is set" || echo "STAFF_ID is NOT set"
[ -n "$STAFF_PASSWORD" ] && echo "STAFF_PASSWORD is set" || echo "STAFF_PASSWORD is NOT set"
[ "${#STAFF_ID}" -ge 1 ] && [ "${#STAFF_ID}" -le 64 ] && echo "ID length OK" || echo "ID must be 1-64 characters"
[ "${#STAFF_PASSWORD}" -ge 12 ] && echo "password long enough" || echo "password too short (needs 12+)"
printf %s "$STAFF_ID" | LC_ALL=C grep -q '[^ -~]' && echo "ID has accents or special characters: not allowed" || echo "ID characters OK"
printf %s "$STAFF_PASSWORD" | LC_ALL=C grep -q '[^ -~]' && echo "password has accents or special characters: not allowed" || echo "password characters OK"
```

(The lengths count spaces at the ends too, but the backend ignores those, so a value of only spaces counts as unset.)

**2. After starting the backend, read its startup line:**

- Good: `staff routes: enabled (STAFF_ID and STAFF_PASSWORD set)`.
- Bad: `staff routes: disabled (STAFF_ID / STAFF_PASSWORD unset or invalid: ID 1-64 characters, password at least 12, printable ASCII)`. Stop the backend and go back to step 1.
- If you also see `note: STAFF_TOKEN is no longer used; set STAFF_ID and STAFF_PASSWORD`:
  1. stop the backend and run `unset STAFF_TOKEN`;
  2. remove it from any shell profile where you set it;
  3. start again.

"Enabled" only means both values are usable, not that staff will type the right ones. Step 3 proves that.

**3. Prove the pair works** with one request from the same terminal (in another terminal, set them again first with the `read … && export STAFF_ID STAFF_PASSWORD` part of the start line, without `dart run`). Put a real month instead of `2026-11`:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "X-Staff-Id: $STAFF_ID" -H "X-Staff-Password: $STAFF_PASSWORD" \
  "http://customer.local/api/orders/export?month=2026-11"
```

`-o /dev/null` throws the downloaded file away and `-w` prints only the status code. `restaurant.local` works too. Without the proxy, use `http://localhost:3000/orders/export?month=2026-11` (no `/api`). While curl runs, other users on the machine can see the headers with `ps`; that's fine on your own laptop.

| Code | Meaning |
|---|---|
| **200** | The pair is right. |
| **401** | Wrong ID or password. |
| **403** | Staff routes are off: see step 2. |
| **429** | Locked after too many wrong tries. Wait up to 60 seconds (`curl -i` shows the exact number in `Retry-After`); a correct pair is refused too until then. |
| **400** | The pair was accepted, but the month isn't `YYYY-MM`. |
| **000** or **502** | Nothing answered: the backend (or the proxy) isn't running. Start it (section 1). |

**Test the right pair once.** Don't test wrong passwords over and over: 5 wrong tries lock every staff member out for a minute.

**4. Does the backend that's already running have them?**
- Look for the `staff routes:` line in that backend's terminal, or run step 3 against it: 200 means yes.
- `ps` doesn't show environment variables. Don't look in `/proc/<pid>/environ`: it prints the password in clear text. Never paste its output anywhere.
- If unsure, stop the backend and start it again from a terminal where steps 1–3 pass.

**5. In the restaurant app:** open "Export month" and type the ID and password.
- **"Wrong staff ID or password":** 401, a wrong pair. Both fields are cleared.
- **"Too many wrong tries. Try again in N seconds."** (or "…Try again later."): 429, locked.
- **"Export is turned off on the server":** 403, the backend was started without valid values.
- **"Use plain letters, digits and symbols, no accents":** the typed value has characters a browser can't send.

The app remembers the pair only until the page is reloaded. The browser's password manager doesn't save it, on purpose: the tablet may be shared.

The variables themselves are listed in section 9.

---

## 5. Proxy, local names and phones

**Caddy:**
- It runs as a system service on port 80. It sends `customer.local` → `localhost:8080`, `restaurant.local` → `localhost:8081`, and `/api/*` → `localhost:3000` (with `/api` removed).
- Don't also run `caddy run` by hand; port 80 can only have one listener.
- Status: `systemctl is-active caddy`. Logs: `sudo journalctl -u caddy -f`.

**nginx instead** (foreground, stop Caddy first):

```bash
sudo systemctl stop caddy
sudo nginx -c $PWD/dev/nginx.conf -p $PWD
# stop it:
sudo nginx -c $PWD/dev/nginx.conf -p $PWD -s stop
```

**Request size:** both proxies refuse request bodies over **64 KB** on `/api/*`. The limit lives in the proxy config, so changing it means editing `dev/Caddyfile` (or `dev/nginx.conf`) and reloading.

**Backend address:**
- It listens on **`127.0.0.1:3000` only** (this machine), so other devices can't go around the proxy.
- `BIND_ADDRESS=0.0.0.0` changes that; only use it behind a firewall.
- Check with `ss -ltn | grep 3000`.

**Local names on the laptop** (one time): `sudo tee -a /etc/hosts <<< "127.0.0.1  customer.local  restaurant.local"`

**Phones on the same wifi (iOS):**
- One-time setup is in `CLAUDE.md` → "Mobile access".
- Port 80 must be open: `sudo ufw allow 80/tcp`.
- Check from the laptop: `avahi-resolve -n customer.local` should print your LAN address.
- After changing wifi, restart the mDNS services (section 2).

---

## 6. Checks

Run these from the project folder. `make check` runs them all, in the same order as CI.

| Command | What it does |
|---|---|
| `make check` | Everything below. Run it before committing. |
| `make format-check` | Reports Dart files that aren't formatted (changes nothing). |
| `make format` | The only target that rewrites files: formats all Dart code. |
| `make analyze` | Flutter analyzer, strict. |
| `make test` | Flutter app tests. |
| `make backend-analyze` | Backend analyzer, strict. |
| `make backend-test` | Backend tests. The first run downloads a prebuilt SQLite, so it needs network. |
| `make boundaries` | Checks that the customer and restaurant apps don't import each other. |
| `make bootstrap` | `flutter pub get` plus `dart pub get` in `backend/`. |
| `make hooks-install` / `make hooks-uninstall` | Turn on or off the optional git hook that checks formatting before each commit. |

---

## 7. CI today

- GitHub Actions runs `make check` on every push and pull request (`.github/workflows/ci.yml`).
- The GitHub remote is `origin` → `https://github.com/longlh-non/food_orders.git` (from `git remote -v`).
- **At the time of writing (2026-11-19):** two commits are pushed, the latest being `de44cc3` "App demo 1st version". `git status -sb` showed `main...origin/main`, so nothing is waiting to be pushed.
- Work done after that commit is still uncommitted on this laptop, and CI checks it only once you commit and push it.
- `git status` shows what's uncommitted. Agents never commit or push unless you ask.

---

## 8. Deploy (CD) status

**Not built yet.** The decisions so far are in `docs/ci-cd-decisions.md`. Hosting is still open (HOST1 provider, HOST2 domain). The pending cards in `docs/tasks/`:

| Card | What it adds |
|---|---|
| `ci-dependabot-and-triggers` | CI runs once per change; weekly dependency-update pull requests. |
| `ci-build-artifacts` | CI builds both web apps and the backend after the checks pass. |
| `deploy-production-config` | Production Caddy config, services, backups for the server. |
| `deploy-demo-access-gate` | A shared password on the public demo. |
| `deploy-runbook` | `docs/deploy.md`, the server guide (links here). |
| `cd-server-deploy-script` | A deploy script on the server: back up, switch release, health check, roll back. |
| `cd-github-deploy-workflow` | Deploy from GitHub when you push a version tag, after your approval. |

These cards update sections 7 and 8 here when they land.

---

## 9. Configuration reference

**Environment variables** (backend; an empty value counts as unset):

| Variable | Default | Effect |
|---|---|---|
| `ORDERS_DB` | `backend/data/orders.db` | The database file to use. |
| `IMAGES_DIR` | `backend/data/images` | The menu pictures folder (created on start). |
| `STAFF_ID` | unset (staff routes off) | The shared staff ID: 1–64 printable ASCII characters (section 4). |
| `STAFF_PASSWORD` | unset (staff routes off) | The shared staff password: at least 12 printable ASCII characters (section 4). Both must be set for staff routes to work. |
| `STAFF_TOKEN` | — | No longer used; ignored. If it's set, the backend prints a note at start. |
| `BIND_ADDRESS` | `127.0.0.1` | Where the backend listens. Keep the default unless you're behind a firewall. |

**Files and folders:**

| Path | What |
|---|---|
| `backend/data/orders.db` | Orders and the menu (git-ignored). |
| `backend/data/orders.YYYY-MM-DD-HHMM.db` | Your dated backups. |
| `backend/data/images/` | Menu pictures (git-ignored). |
| `dev/Caddyfile` → `/etc/caddy/Caddyfile` | Proxy config: edit the first, copy it to the second, reload. |
| `dev/nginx.conf` | The nginx alternative. |
| `dev/mdns-publish.sh`, `dev/food-orders-mdns@.service` | The phone names (mDNS). |
| `docs/ci-cd-decisions.md` | Your CI/CD decisions. |

**Ports and addresses:**

| Port | What | Open it at |
|---|---|---|
| 80 | Caddy (or nginx) | http://customer.local, http://restaurant.local |
| 3000 | Backend (this machine only) | via the proxy: `/api/...` |
| 8080 | Customer app (dev server) | via the proxy |
| 8081 | Restaurant app (dev server) | via the proxy |
| 8082 | Split-screen demo | http://localhost:8082 |

---

## 10. Known gaps (not verified by an agent)

- **Hot reload:** whether `r`/`R` work on `-d web-server` without the Dart Debug Chrome extension (section 2).
- **Restore:** restoring a backup on your real database (section 3).
- **Proxy, mDNS and services:** the Caddy and nginx reloads, mDNS and the systemd services. Agents can't run `sudo`.
- **Phones:** anything on the iPhone.
- **Order store:** the "storage full" clean-up on real data.

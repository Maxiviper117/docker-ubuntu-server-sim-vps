# Project Review — UX Improvements for `docker-ubuntu-server-sim-vps`

**Scope:** UX-focused review of the "Simulated Ubuntu VPS in Docker with SSH Access" project.
**Date:** 2026-08-01 (updated to reflect the author's implemented improvements)
**Files reviewed:** `README.md`, `Dockerfile.24`, `docker-compose.24.yml`, `Makefile`,
`instructions.windows.md`, `instructions.linux-mac.md`, `helpers/*.{sh,ps1}` (setup, up, status,
logs, shell, down, reset), `helpers/reset-ssh-and-up.{ps1,sh}`, `.env(.example)`,
`.infrastructure/scripts/*`, `.vscode/tasks.json`, `test/check_ssh_localhost_root.sh`,
`CONTRIBUTING.md`, `.gitignore`, `.dockerignore`, `reviews/docker-vps-simulator-review.md`.

---

## Project summary

This is a **"simulated Ubuntu VPS in Docker with SSH access"** — users build a Ubuntu 24.04
image (with Docker-in-Docker + SSH server baked in), run it via Compose, inject their SSH
public key via `.env`, and connect over SSH on port 2222. It is a genuinely useful tool for
testing deployment/automation scripts safely. The core mechanics work, but the *onboarding*
and *daily-loop* experience has meaningful friction.

---

## 📌 Status update (2026-08-01) — most items implemented

A follow-up re-review was done after the author implemented key improvements:

| # | Item | Status |
| --- | --- | --- |
| 1 | Default `Dockerfile` / `docker-compose.yml` names | **Open** — still `.24` suffix, every command needs `-f` |
| 2 | One-command `make setup` flow | **✅ Implemented** (`helpers/setup.{sh,ps1}` + `Makefile`) |
| 3 | Real healthcheck + wait-for-healthy | **✅ Implemented** (Compose healthcheck + setup waits for `healthy`) |
| 4 | Key-onboarding UX (auto-detect/create) | **✅ Implemented** (create/reuse flow, no manual paste) |
| 5 | Consolidate Dockerfile apt layers | **Open** |
| 6 | Standardize build command in docs | **Open** (minor; `make setup`/`up` now the documented path) |
| 7 | De-duplicate the two OS guides | **Partially** — now share the same `make`/helper vocabulary, still two large files |
| 8 | Configurable ports via `.env` | **Open** |
| 9 | Security documentation | **✅ Implemented** — README "Security limits" section added |
| 10 | Remove dead/disabled bits | **Open** — `test/check_ssh_localhost_root.sh` still fully commented out |

**New improvements added by the author:** lifecycle commands (`up/status/logs/shell/down/reset`),
a `Makefile`, confirmation-gated reset, supervised Docker/SSH processes (no more bare `tail -f`),
readiness checks replacing fixed sleeps, and good cross-platform one-command setup.

---

## 🔴 High-impact UX improvements

### 1. Eliminate the forced `-f` flags (biggest daily annoyance)
Everything is named `Dockerfile.24` and `docker-compose.24.yml`, so every single command
requires `-f Dockerfile.24` / `-f docker-compose.24.yml`. This is error-prone and annoying.

**Recommendation:** ship a canonical `Dockerfile` and `docker-compose.yml` as the default
names (drop the `.24` suffix, since there's only one variant in the repo anyway). Then users
just run `docker compose up -d` and `docker build -t ubuntu-vps-sim .`. This also fixes the
current confusion where the README's "Getting Started" never tells you the exact commands.

### 2. One-command `make` / helper setup (collapse the 7 manual steps) — ✅ Implemented
> **Status: Implemented (2026-08-01).** See `helpers/setup.{sh,ps1}` and the `Makefile`
> (`make setup`).

The original flow forced users to manually: generate a key → `cp .env.example .env` → open
`.env` and paste a key → `docker build` → `docker compose up` → hand-edit `~/.ssh/config` →
then `ssh localhost-root`. That is a lot of manual, copy-paste, error-prone steps.

**Recommendation:** add a single `scripts/setup.(sh|ps1)` that:
- Generates a key if none exists (or reads an existing one),
- Writes it into the correct `.env` field automatically,
- Appends the `localhost-root` block to `~/.ssh/config` if not already present,
- Builds, starts, and prints the final `ssh localhost-root` command.

This aligns perfectly with the `helpers/reset-ssh-and-up.*` scripts already present. Extending
those to handle key + SSH config turns a ~15-minute setup into a ~30-second one.

### 3. Real **healthcheck** so "is it ready to SSH?" is answerable — ✅ Implemented
> **Status: Implemented (2026-08-01).** A healthcheck is now enabled in the compose file
> (checks `docker info` + SSH port), and the setup helper waits for `healthy` before passing.

The healthcheck was previously commented out in the compose file. As-is before the fix,
`docker compose up` returned success the moment the container *started*, not when SSH was actually
reachable — and in this setup `dockerd` has to boot independently inside the container first,
which takes time.

**Recommendation:** enable a healthcheck based on SSH (e.g. `sshd -T` or an actual connect
attempt), and expose it in the UX: `docker compose ps` shows `health: started` vs `healthy`,
and the setup script can `--wait` until healthy before telling the user to connect. This removes
the classic "I ran it but `ssh` says connection refused" moment.

### 4. Fix the **key-onboarding UX** (the #1 stumbling block) — ✅ Implemented
> **Status: Implemented (2026-08-01).** The setup helper now handles key creation and reuse
> (create-or-reuse prompt) and injects the key into `.env` automatically.

Users previously had to figure out *where* their public key lives and paste it into `.env`. The old
instructions assumed 1Password-generated keys or a specific filenaming convention, and the two OS
guides diverged on key filenames (`SSH-Key-Windows-Desktop` vs `SSH-Key-Linux-Mac`).

**Recommendation:**
- **Auto-detect** the key: add a helper that finds `~/.ssh/*.pub` (or generates one) and
  injects it into `.env` — no manual paste.
- Keep a *solid fallback*: if `SSH_PUB_KEY` is empty, generate a fresh local keypair and create
  an `authorized_keys` at runtime so even a brand-new user with zero setup still gets in (with a
  clearly printed path). Right now the container hard-fails with
  `ERROR: SSH_PUB_KEY ... exit 1` — arguably the single most frustrating failure mode for
  first-time users.


---

## 🟡 Medium-impact improvements

### 5. Consolidate the Dockerfile's three `apt-get` blocks
Lines 21, 75, and 80 run `apt-get update && apt-get install` separately, with overlapping
installs (`tini`, `dos2unix`, and the base layer). This roughly triples layers and slows every
rebuild. Merge into a single layer — builds get faster and the image gets smaller, which matters
because users rebuild locally.

### 6. Standardize the build command shown in docs
`Dockerfile.24` header says to build with `docker buildx build -t ...`, but `instructions.*.md`
(Step 3) say `docker build -f Dockerfile.24 -t ...`. Pick one, document it in one place
(README), and reference it from both OS guides so the two docs never drift apart again.

### 7. De-duplicate the two OS instruction guides
`instructions.windows.md` and `instructions.linux-mac.md` are ~95% identical, and maintaining
both by hand guarantees inconsistencies (they've **already** drifted: the build commands and key
filenames differ). Keep one canonical guide and make the second a thin, OS-specific delta (just
the few commands that actually differ: PowerShell vs bash, key paths).

### 8. Make the port bindings configurable via `.env`
Ports `2222/8080/8443/2375` are hardcoded. If a user already runs something on 2222 (very common
for SSH tools), they must edit the compose file and then *remember* to use a different port in
their SSH config — a brittle chain.

**Recommendation:** parameterize with defaults, e.g. `${SSH_PORT:-2222}`,
`${HTTP_PORT:-8080}`, and have the setup helper reference the same value when writing the SSH
config block. Also expose these in `.env.example` with comments.

### 9. Security hardening worth documenting — 🟡 documentation done, override open
> **Status:** README "Security limits" section added (2026-08-01); a non-privileged override mode
> remains **open**.

- The compose runs `privileged: true` *and* exposes `127.0.0.1:2375` — an **unauthenticated
  Docker TCP API**. This is now documented as a security limit in the README; the risky part remains
  the lack of a non-privileged compose override for users who do not need the nested Docker.
- Add a clear `docker compose down -v` teardown step so users can fully reset when done (the new
  `make reset` helper now covers this).

### 10. Remove the dead/disabled bits that add confusion
- `test/check_ssh_localhost_root.sh` is **entirely commented out** (dead code), and the compose
  file has a commented-out healthcheck. Cleaning these up (either implementing or removing them)
  makes the repo read as intentional.

---

## 🟢 Quick wins (docs & defaults)
- Add a top-of-README **TL;DR** with the 3 commands to get from clone to `ssh localhost-root`.
- Add a **"Common issues"** section (host-key changed → `ssh-keygen -R '[localhost]:2222'`
  already documented; port-in-use; healthcheck not healthy) so users self-resolve.
- `.env.example` is good (`SSH_PUB_KEY=""`), but consider a commented example key so the format
  is unambiguous.
- Consider `make up` / `make down` / `make ssh` aliases in the README for discoverability — they
  map 1:1 to the mental model of "up / down / connect".

---

## Suggested priority order to implement

Remaining open work, in priority order:

1. **Fix the Windows host-key bug** (see "New issues" → A) — breaks first-run `make setup` on Windows.
2. **Default `docker-compose.yml`/`Dockerfile` names** — removes `-f` everywhere for users who don't use `make`.
3. **Consolidate Dockerfile apt layers** — faster local rebuilds.
4. **Configurable ports via `.env`** (e.g. `${SSH_PORT:-2222}`) and keep setup helpers in sync.
5. **Enable or remove `test/check_ssh_localhost_root.sh`** and add `.env`/`*.pub` to `.dockerignore`.

Already implemented as of 2026-08-01: one-command setup, lifecycle commands + Makefile, healthcheck
+ wait-for-healthy, key-onboarding UX, supervised Docker/SSH, and security documentation.

---

## 🐛 New issues found in the updated code (2026-08-01)

The re-review found a few regressions / gaps introduced by the changes:

### A. Windows first-run SSH test will fail (cross-platform gap)
`helpers/setup.sh` writes `StrictHostKeyChecking accept-new` into the `localhost-root` SSH config
block, so the final batch-mode SSH test auto-accepts the host key.

`helpers/setup.ps1` does **not** write `StrictHostKeyChecking accept-new` into the config, yet it
still runs the SSH test with `-o BatchMode=yes`. On a fresh machine where `localhost:2222` is not
already in `known_hosts`, BatchMode cannot prompt to accept the host key, so "Host key verification
failed" aborts the final SSH test. The helper then throws "SSH login failed" even though the
container is healthy.

**Fix:** add `StrictHostKeyChecking accept-new` to the PowerShell config block (matching the Bash
version), or pass `-o StrictHostKeyChecking=accept-new` explicitly on the test command.

### B. `StrictHostKeyChecking accept-new` in a shared config block is risky
The Bash helper appends `StrictHostKeyChecking accept-new` (and `IdentitiesOnly yes`) globally
within the `Host localhost-root` block, which is fine. But it is worth noting the helper can add
`IdentitiesOnly yes` to an existing user block if the user already had that host configured — see
item C. Prefer scoping any global options only under that specific host (which is what the helper
does).

### C. Setup silently rewrites an existing `.env`
Both setup helpers overwrite/update `SSH_PUB_KEY` in `.env` automatically. That is convenient, but
if a user had intentionally set a different key (or other config later added to `.env`), it is
replaced without warning on every `make setup`. Consider printing a clear "[setup] Updated
SSH_PUB_KEY in .env" confirmation line (the Bash version prints the key steps; the PS1/`Set-Content`
path updates without a clear "updated" message). (Minor.)

### D. Healthcheck depends on `timeout` + `bash` inside the image
The Compose healthcheck (`CMD-SHELL` with `docker info` and `/dev/tcp/127.0.0.1/22`) relies on
`timeout` (coreutils) and `bash` being present in the base Ubuntu image. Both are present in
`ubuntu:24.04`, so it works today, but it is an implicit dependency worth a comment so a future
slimming of the base image does not silently break the healthcheck. (Minor.)

### E. Makefile platform detection has an edge case
`ifeq ($(OS),Windows_NT)` correctly routes to PowerShell under native Windows Make. But `make` run
from **Git Bash / MSYS on Windows** does not set `OS=Windows_NT`, so it falls through to the Bash
branch — which is actually acceptable there because Git Bash provides `bash`. Worth a one-line
comment in the Makefile explaining this so it is not "fixed" into a regression later. (Minor.)

### F. Remaining open items worth prioritizing
- **Default file names (#1)** — the biggest remaining daily-friction item; `make up` hides it, but
  direct `docker compose`/`docker build` users still fight `-f`.
- **`test/check_ssh_localhost_root.sh` (#10)** — still 100% commented-out dead code; either enable
  it as a smoke test or delete it.
- **`.dockerignore`** still ships `.env.example`/build context broadly and does not explicitly
  exclude `.env`/`*.pub` — confirm no secrets enter the build context (add `.env` and `*.pub`).

---

## Bottom line
The foundation is solid — the improvements are really about removing manual steps and letting the
tool tell the user *when* it is ready and *how* to connect, instead of leaving that to multi-guide
manual configuration.


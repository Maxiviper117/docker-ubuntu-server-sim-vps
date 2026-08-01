# Docker VPS Simulator Review

**Date:** 2026-08-01  
**Scope:** Local Docker setup for a simulated Ubuntu 24.04 VPS  
**Review type:** Reliability, repeatability, security, testing, and operator experience

## Project purpose

This project builds an Ubuntu 24.04 container with SSH and Docker access.

The container supports local tests for deployment scripts, automation, server configuration, and troubleshooting.

The setup uses Docker-in-Docker, SSH key access, privileged mode, and a persistent Docker volume.

## Overall result

The project has a clear purpose and a valid basic flow:

1. Build the Ubuntu image.
2. Install SSH and Docker.
3. Start `dockerd` and `sshd`.
4. Add the host public key.
5. Connect through SSH on port `2222`.

The main risks affect service supervision, repeatable builds, parallel test use, cleanup, and security boundaries.

## Highest-priority improvements

### 1. Manage Docker and SSH as real services — Implemented

**Status:** Implemented on 2026-08-01.

The entrypoint now monitors both services and exits when either service stops.

The Compose health check now checks Docker readiness and SSH port readiness.

[00-startup.sh](../.infrastructure/scripts/00-startup.sh) starts `dockerd` and `sshd` in the background.

[entrypoint-wrapper.sh](../.infrastructure/scripts/entrypoint-wrapper.sh) then runs `tail -f /dev/null`.

If Docker or SSH stops, the container can still appear healthy.

Use one of these approaches:

- Use `s6-overlay`.
- Use `supervisord`.
- Add a process loop that exits when `dockerd` or `sshd` stops.
- Add a real Docker health check.

This change gives users a truthful container status.

### 2. Replace fixed startup delays — Implemented

**Status:** Implemented on 2026-08-01.

The startup script now waits for Docker readiness and an available SSH port.

Each readiness check has a 30-second limit and a clear failure message.

The startup script waits two seconds after each service starts.

A slow system can need more time. A failed service can still pass the delay.

Use readiness checks with a timeout for Docker and SSH.

Example for Docker:

```bash
wait_for_docker() {
    for _ in $(seq 1 30); do
        docker info >/dev/null 2>&1 && return 0
        sleep 1
    done

    echo "Docker did not become ready." >&2
    return 1
}
```

### 3. Add a one-command setup flow — Implemented

**Status:** Implemented on 2026-08-01.

The new `helpers/setup.sh` and `helpers/setup.ps1` helpers create or reuse an SSH key, update `.env`, build the image, start the container, wait for health, and test SSH.

The current guides require manual key creation, `.env` editing, image build, Compose startup, SSH configuration, and connection.

Add a setup helper for each platform.

The helper should:

- Check that Docker works.
- Check that the public key exists.
- Create `.env` when needed.
- Build the image.
- Start the container.
- Wait for SSH.
- Run an SSH login test.
- Print the final SSH command.

This change supports fast test cycles.

### 4. Add lifecycle commands — Implemented

**Status:** Implemented on 2026-08-01.

The project now provides `up`, `status`, `logs`, `shell`, `down`, and `reset` helpers for Windows and Linux/macOS.

Add clear commands for each common state:

```text
up
status
logs
shell
down
reset
```

Document the difference between these commands:

```bash
docker compose down
docker compose down -v
```

The second command deletes the `vps_docker` volume and all nested Docker data.

### 5. Support multiple VPS instances — Implemented

**Status:** Implemented on 2026-08-01.

The Compose file now supports project-specific names, host ports, and SSH aliases.

The setup helpers now inspect the Compose service instead of a fixed container name.

Before this change, the setup prevented parallel instances through fixed names and ports:

- Fixed container name.
- Host port `2222`
- Host port `2375`
- Host port `8080`
- Host port `8443`

Remove `container_name`, or make it configurable.

Make the host ports configurable through `.env`:

```dotenv
VPS_SSH_PORT=2222
VPS_DOCKER_API_PORT=2375
VPS_HTTP_PORT=8080
VPS_HTTPS_PORT=8443
```

This change allows several Ubuntu simulations to run at the same time.

### 6. Make disposable behavior clear — Implemented

**Status:** Implemented on 2026-08-01.

The Compose file now uses `restart: "no"`.

The simulator now stops after a failure, so tests show the real container state.

The README and platform guides now describe persistent and clean VPS modes.

The persistent mode keeps the `vps_docker` volume.

The clean mode uses `make reset` or `docker compose down -v`.

Users can enable `restart: unless-stopped` in a local Compose file when needed.

### 7. Reduce unused exposed ports

The image and Compose file expose ports `80` and `443`.

The image does not install a web server.

Remove those ports from the default setup, or document their intended use.

Keep port `2375` only when nested Docker tests need it.

### 8. Add a clear security warning — Implemented

**Status:** Implemented on 2026-08-01.

The README, setup guides, and Compose file now warn about privileged mode and the unauthenticated Docker API.

The setup uses `privileged: true` and starts Docker without TLS on port `2375`.

The host mapping limits access to local host programs.

The container still does not provide a strong security boundary for untrusted code.

Add this warning to the README:

> Do not run untrusted workloads in this simulator. The container uses privileged mode and runs a Docker daemon.

### 9. Stop overwriting all SSH keys — Implemented

**Status:** Implemented on 2026-08-01.

The SSH setup script now preserves existing keys and adds `SSH_PUB_KEY` only when the key does not exist.

[01-ssh-setup.sh](../.infrastructure/scripts/01-ssh-setup.sh) previously overwrote `/root/.ssh/authorized_keys`.

The previous behavior removed keys that a test added during the session.

The new behavior keeps existing keys and prevents duplicate entries.

The container reset flow still creates a new authorized key file when Docker removes the container.

The setup guides now use the append behavior.

### 10. Make image builds repeatable

**Status:** Implemented on 2026-08-01.

[Dockerfile.24](../Dockerfile.24) installs current packages from live repositories.

Two builds can produce different images.

Improve repeatability with these changes:

- Pin the Ubuntu image digest.
- Pin package versions where practical.
- Record an image version.
- Add a build label with the source commit.
- Add optional apt snapshot support.

The Dockerfile now pins the Ubuntu base image by digest.

The Dockerfile now uses one package installation layer.

The Dockerfile now uses BuildKit cache mounts for APT files.

These changes reduce repeated download time and image layers.

Package version pinning and APT snapshot support remain optional future improvements.

## Important implementation issues

### Entrypoint wrapper

**Status:** Implemented on 2026-08-01.

[entrypoint-wrapper.sh](../.infrastructure/scripts/entrypoint-wrapper.sh) now uses a shell glob to find scripts.

The wrapper now supervises the Docker and SSH processes.

The wrapper exits when either process stops.

### Helper scripts

The setup helpers now remove an old key only for the local simulator endpoint.

This action allows a recreated simulator to pass SSH validation without changing other host keys.

The helpers print a message before they remove the old local key.

This action applies only to `[localhost]:<VPS_SSH_PORT>`.

The PowerShell helper now uses strict error handling.

It uses:

```powershell
$ErrorActionPreference = "Stop"
```

The Bash helper uses:

```bash
set -euo pipefail
```

### Docker build context

[.dockerignore](../.dockerignore) does not exclude `.env` or public key files.

Add:

```text
.env
*.pub
```

This keeps local configuration out of the Docker build context.

## Testing improvements

[test/check_ssh_localhost_root.sh](../test/check_ssh_localhost_root.sh) contains only commented code.

Turn it into an active smoke test.

Add tests for:

- Container startup.
- SSH login.
- Docker daemon access.
- Public key installation.
- Container restart.
- Clean volume reset.
- Port configuration.
- Missing `SSH_PUB_KEY`.
- Invalid public key.
- Port collision.

Add CI checks for:

- Bash syntax.
- PowerShell syntax.
- Docker Compose configuration.
- Dockerfile lint.
- ShellCheck.
- A Docker smoke test.

## Suggested project structure

```text
helpers/
  up.sh
  up.ps1
  status.sh
  status.ps1
  logs.sh
  logs.ps1
  shell.sh
  shell.ps1
  down.sh
  down.ps1
  reset.sh
  reset.ps1

test/
  smoke-ssh.sh
  smoke-docker.sh
  smoke-reset.sh
```

## Recommended implementation order

1. ~~Add service readiness checks and a real health check.~~ **Implemented**
2. ~~Replace fixed startup delays.~~ **Implemented**
3. ~~Add one-command setup.~~ **Implemented**
4. ~~Add lifecycle commands.~~ **Implemented**
5. Add active SSH and Docker smoke tests.
6. ~~Add configurable ports and remove the fixed container name.~~ **Implemented**
7. ~~Document persistent and clean VPS modes.~~ **Implemented**
8. ~~Add the security warning for privileged mode and port `2375`.~~ **Implemented**
9. ~~Improve build repeatability and reduce apt layers.~~ **Implemented**
10. ~~Improve SSH key management.~~ **Implemented**
11. ~~Refresh stale local simulator host keys.~~ **Implemented**

## Verification notes

The Bash scripts passed syntax checks.

The PowerShell helper passed syntax checks.

Docker Compose configuration passed validation.

The Docker Compose configuration passed validation.

The Docker image built successfully with `docker compose build --no-cache`.

The Windows setup passed with `make setup`.

The setup reported `Container is healthy` and `SSH login successful`.

The setup removed the old `[localhost]:2222` key and added the new simulator key.

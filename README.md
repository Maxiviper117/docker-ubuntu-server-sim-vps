
# 🐧🪟 Simulated Ubuntu VPS in Docker with SSH Access 🚀

![Docker](https://img.shields.io/badge/docker-ready-blue?logo=docker)
![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)
![OS: Linux](https://img.shields.io/badge/os-linux-blue?logo=linux)
![OS: Windows](https://img.shields.io/badge/os-windows-blue?logo=windows)


This repository provides everything you need to run a simulated Ubuntu VPS locally using Docker, with full SSH access. This project supports:

- 🧪 Testing deployment scripts and automation in a safe, local environment
- 🖥️ Practicing server management and SSH workflows
- ⚙️ Experimenting with configuration changes before applying them to production
- ⚡ Quickly spinning up a disposable Ubuntu server for development or troubleshooting

> [!WARNING]
> This simulator is not a security boundary. It uses privileged mode and exposes an unauthenticated Docker API on port `2375` through localhost.
> Do not run untrusted workloads in this simulator. Use a virtual machine or another isolated environment for untrusted code.


## 🚦 Getting Started


Follow the setup guide for your operating system:

- 🪟 [Instructions for Windows](./instructions.windows.md)
- 🐧 [Instructions for Linux/macOS](./instructions.linux-mac.md)


Each guide will walk you through generating SSH keys, building the Docker image, running the container, and connecting via SSH.

## ⚡ Fast Setup

Use the setup helper to create or reuse an SSH key, update `.env`, build the image, start the container, wait for health, and test SSH.

The helper first asks whether you want to create a new key or reuse an existing key.

If GNU Make exists, run:

```text
make setup
```

The `Makefile` detects Windows and runs PowerShell helpers.

The `Makefile` runs Bash helpers on Linux and macOS.

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File helpers/setup.ps1
```

### Linux/macOS

```bash
bash helpers/setup.sh
```

The helper uses `~/.ssh/ubuntu24-vps-sim` when no key path exists.

Set `VPS_SSH_KEY_PATH` to use another key path.

The helper adds the `localhost-root` host to your SSH config.

The container keeps existing root SSH keys and adds the configured key when needed.

## Requirements

Install Docker Desktop with the Linux engine on Windows.

Install Docker Engine or Docker Desktop, Docker Compose v2, Bash, and OpenSSH on Linux and macOS.

Install GNU Make to use the platform detection in the `Makefile`.

## Common commands

Use `make` for the required lifecycle action:

```text
make up
make status
make logs
make shell
make down
make reset
```

Use the platform helper directly when GNU Make does not exist.

| Action | Windows PowerShell | Linux/macOS |
| --- | --- | --- |
| Start or rebuild | `powershell -ExecutionPolicy Bypass -File helpers/up.ps1` | `bash helpers/up.sh` |
| Show status | `powershell -ExecutionPolicy Bypass -File helpers/status.ps1` | `bash helpers/status.sh` |
| Show logs | `powershell -ExecutionPolicy Bypass -File helpers/logs.ps1` | `bash helpers/logs.sh` |
| Open a shell | `powershell -ExecutionPolicy Bypass -File helpers/shell.ps1` | `bash helpers/shell.sh` |
| Stop and keep data | `powershell -ExecutionPolicy Bypass -File helpers/down.ps1` | `bash helpers/down.sh` |
| Reset and delete data | `powershell -ExecutionPolicy Bypass -File helpers/reset.ps1` | `bash helpers/reset.sh` |

The reset helper asks for confirmation before it deletes the Docker volume.

## VPS data modes

The default mode keeps Docker data in the `vps_docker` volume.

Use `make down` to stop the simulator and keep its data.

Use `make up` to start the simulator again with the same Docker data.

Use `make reset` to stop the simulator and delete its Docker data.

The reset helper asks for confirmation before it deletes the volume.

The Compose file does not restart the simulator after a failure.

This setting helps tests show the real container state.

If you need automatic restart, set `restart: unless-stopped` in your local Compose file.

## Run multiple simulators

Give each simulator a different Compose project name, SSH alias, and host port.

### Windows PowerShell

```powershell
$env:COMPOSE_PROJECT_NAME = "ubuntu24-vps-sim-b"
$env:VPS_SSH_ALIAS = "localhost-root-b"
$env:VPS_SSH_PORT = "2223"
make setup
```

### Linux/macOS

```bash
COMPOSE_PROJECT_NAME=ubuntu24-vps-sim-b \
VPS_SSH_ALIAS=localhost-root-b \
VPS_SSH_PORT=2223 \
make setup
```

Use a different Docker API port when the second simulator needs host access to its Docker daemon.

Show the service status:

```bash
docker compose -f docker-compose.24.yml ps
```

Read the service logs:

```bash
docker compose -f docker-compose.24.yml logs -f vps
```

Open a shell in the simulator:

```bash
docker exec -it ubuntu24-vps-sim bash
```

Stop the simulator and keep its Docker data:

```bash
docker compose -f docker-compose.24.yml down
```

Stop the simulator and delete its Docker data:

```bash
docker compose -f docker-compose.24.yml down -v
```

## Security limits

The simulator runs Docker in privileged mode.

The Docker daemon listens without TLS on port `2375` inside the simulator.

The Compose file maps port `2375` to localhost by default.

Remove the port mapping when nested Docker tests do not need host access.


## 📄 License

Read the [MIT License](./LICENSE) for license terms.

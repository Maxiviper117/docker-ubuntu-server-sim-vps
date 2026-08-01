# Ubuntu VPS Simulator Setup for Windows

## Purpose

Use this project to run a local Ubuntu 24.04 VPS simulator in Docker.

The simulator provides SSH access and a Docker daemon for local tests.

## Prerequisites

Install these tools before you start:

- Docker Desktop with the Linux engine.
- PowerShell.
- The OpenSSH client.

Confirm that Docker works:

```powershell
docker version
docker compose version
```

The Docker commands must return version information.

## Fast setup

If GNU Make exists, run this command from the project directory:

```powershell
make setup
```

The `Makefile` detects Windows and runs the PowerShell helper.

If GNU Make does not exist, run the PowerShell helper directly:

```powershell
powershell -ExecutionPolicy Bypass -File helpers/setup.ps1
```

The helper first asks whether you want to create a new key or reuse an existing key.

The helper performs these actions:

1. Create or reuse an Ed25519 SSH key.
2. Update `.env` and the SSH configuration file.
3. Build the Docker image.
4. Start the container.
5. Wait for the Docker and SSH health checks.
6. Test the SSH connection.

The helper suggests this key path by default:

```text
C:\Users\<user>\.ssh\ubuntu24-vps-sim
```

Set `VPS_SSH_KEY_PATH` to use another key path:

```powershell
$env:VPS_SSH_KEY_PATH = "$HOME\.ssh\my-test-key"
powershell -ExecutionPolicy Bypass -File helpers/setup.ps1
```

The helper creates a key without a passphrase when it creates a new key.

The container keeps existing root SSH keys and adds the configured key when needed.

## Connect to the simulator

After setup, connect with:

```powershell
ssh localhost-root
```

The SSH service listens on host port `2222`.

## Manual setup

Use these steps if you do not want to use the setup helper.

### 1. Create an SSH key

Create an Ed25519 key:

```powershell
ssh-keygen -t ed25519 -C "ubuntu24-vps-sim" -f "$HOME\.ssh\ubuntu24-vps-sim"
```

### 2. Create the environment file

Copy the example file:

```powershell
Copy-Item .env.example .env
```

Read the public key:

```powershell
Get-Content "$HOME\.ssh\ubuntu24-vps-sim.pub"
```

Set the `SSH_PUB_KEY` value in `.env` to the complete public key line.

### 3. Build and start the simulator

```powershell
docker compose -f docker-compose.24.yml up -d --build
```

### 4. Check the container status

```powershell
docker compose -f docker-compose.24.yml ps
```

The `vps` service should show `healthy`.

If the service does not show `healthy`, read the logs:

```powershell
docker compose -f docker-compose.24.yml logs --tail=80 vps
```

### 5. Add the SSH configuration

Add this block to `$HOME\.ssh\config`:

```text
Host localhost-root
    HostName localhost
    User root
    Port 2222
    IdentityFile C:\Users\<user>\.ssh\ubuntu24-vps-sim
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
```

### 6. Test SSH access

```powershell
ssh localhost-root "echo SSH login successful"
```

## Useful commands

Use these lifecycle helpers from the project directory:

```powershell
make up
make status
make logs
make shell
make down
make reset
```

If GNU Make does not exist, run these commands:

```powershell
powershell -ExecutionPolicy Bypass -File helpers\up.ps1
powershell -ExecutionPolicy Bypass -File helpers\status.ps1
powershell -ExecutionPolicy Bypass -File helpers\logs.ps1
powershell -ExecutionPolicy Bypass -File helpers\shell.ps1
powershell -ExecutionPolicy Bypass -File helpers\down.ps1
powershell -ExecutionPolicy Bypass -File helpers\reset.ps1
```

The reset helper asks for `RESET` before it deletes the Docker volume.

The persistent mode keeps Docker data in the `vps_docker` volume.

Use `down` to stop the simulator and keep its data.

Use `up` to start the simulator again with the same data.

The clean mode deletes the volume and its Docker data.

Use `reset` for the clean mode.

The simulator stops after a failure. Docker does not restart it automatically.

Show service status:

```powershell
docker compose -f docker-compose.24.yml ps
```

Read service logs:

```powershell
docker compose -f docker-compose.24.yml logs -f vps
```

Open a shell without SSH:

```powershell
docker exec -it ubuntu24-vps-sim bash
```

Stop the simulator and keep its Docker data:

```powershell
docker compose -f docker-compose.24.yml down
```

Stop the simulator and delete its Docker data:

```powershell
docker compose -f docker-compose.24.yml down -v
```

## Troubleshooting

### Docker Desktop does not run

Start Docker Desktop and select the Linux engine.

Run `docker version` again.

### Port `2222` is in use

Stop the process that uses port `2222`.

Then run the setup helper again.

### SSH reports a changed host key

Remove the old key entry:

```powershell
ssh-keygen -R "[localhost]:2222"
```

Run the setup helper again.

### The container does not become healthy

Read the service logs:

```powershell
docker compose -f docker-compose.24.yml logs --tail=80 vps
```

Check that `.env` contains a complete public key line.

## Run multiple simulators

Give each simulator a different project name, SSH alias, and SSH port:

```powershell
$env:COMPOSE_PROJECT_NAME = "ubuntu24-vps-sim-b"
$env:VPS_SSH_ALIAS = "localhost-root-b"
$env:VPS_SSH_PORT = "2223"
make setup
```

Set a different `VPS_DOCKER_API_PORT` when the second simulator needs Docker API access from the host.

## Security limits

> [!WARNING]
> This simulator is not a security boundary. It uses privileged mode and exposes an unauthenticated Docker API on port `2375` through localhost.
> Do not run untrusted workloads in this simulator. Use a virtual machine or another isolated environment for untrusted code.

Remove the port mapping when nested Docker tests do not need host access.

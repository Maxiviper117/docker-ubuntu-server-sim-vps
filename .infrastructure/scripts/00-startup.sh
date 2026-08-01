#!/bin/bash
# 00-startup.sh
#
# This script performs essential startup tasks for a container or VM environment:
# - Removes a stale Docker PID file if present and the process is not running.
# - Starts the Docker daemon if it is not already running, listening on both TCP and Unix socket.
# - Starts the SSH daemon in the background if it is not already running.
# - Waits until Docker and SSH accept connections.
# The script waits for readiness, then returns to the entrypoint wrapper.

set -e

# [00-startup] Check for SSH_PUB_KEY environment variable
if [ -z "$SSH_PUB_KEY" ]; then
    echo "[00-startup] ERROR: SSH_PUB_KEY environment variable is not set or is empty."
    echo "[00-startup] You must provide SSH_PUB_KEY (your public SSH key) via the .env file or docker compose environment."
    echo "[00-startup] Exiting container startup."
    exit 1
fi

# [00-startup] Clean up stale Docker PID file if needed
if [ -f /var/run/docker.pid ]; then
    PID=$(cat /var/run/docker.pid)
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "[00-startup] Removing stale /var/run/docker.pid"
        rm -f /var/run/docker.pid
    fi
fi

# [00-startup] Start Docker daemon if not running
if ! pgrep dockerd > /dev/null; then
    echo "[00-startup] Starting Docker daemon..."
    dockerd --host=0.0.0.0:2375 --host=unix:///var/run/docker.sock &
else
    echo "[00-startup] Docker daemon already running."
fi

# [00-startup] Wait for Docker daemon readiness
echo "[00-startup] Waiting for Docker daemon..."
for attempt in $(seq 1 30); do
    if docker info > /dev/null 2>&1; then
        echo "[00-startup] Docker daemon is ready."
        break
    fi

    if [ "$attempt" -eq 30 ]; then
        echo "[00-startup] ERROR: Docker daemon did not become ready within 30 seconds." >&2
        exit 1
    fi

    sleep 1
done

# [00-startup] Start SSH daemon in foreground (if not already running)
if ! pgrep sshd > /dev/null; then
    echo "[00-startup] Starting SSH daemon..."
    /usr/sbin/sshd -t
    /usr/sbin/sshd -D &
else
    echo "[00-startup] SSH daemon already running."
fi

# [00-startup] Wait for SSH port readiness
echo "[00-startup] Waiting for SSH daemon..."
for attempt in $(seq 1 30); do
    if (echo > /dev/tcp/127.0.0.1/22) 2> /dev/null; then
        echo "[00-startup] SSH daemon is ready."
        break
    fi

    if [ "$attempt" -eq 30 ]; then
        echo "[00-startup] ERROR: SSH daemon did not accept connections within 30 seconds." >&2
        exit 1
    fi

    sleep 1
done

# [00-startup] Done. The entrypoint wrapper supervises both services.

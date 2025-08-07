#!/bin/bash
# 00-startup.sh
#
# This script performs essential startup tasks for a container or VM environment:
# - Removes a stale Docker PID file if present and the process is not running.
# - Starts the Docker daemon if it is not already running, listening on both TCP and Unix socket.
# - Starts the SSH daemon in the background if it is not already running.
# The script does not block; it is intended to be run as an early entrypoint before the main process.

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
    sleep 2
else
    echo "[00-startup] Docker daemon already running."
fi

# [00-startup] Start SSH daemon in foreground (if not already running)
if ! pgrep sshd > /dev/null; then
    echo "[00-startup] Starting SSH daemon..."
    /usr/sbin/sshd -D &
    sleep 2
else
    echo "[00-startup] SSH daemon already running."
fi

# [00-startup] Done. This script does not block, main process will be handled by entrypoint-wrapper.

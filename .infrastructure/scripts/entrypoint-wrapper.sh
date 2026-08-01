#!/bin/sh
# entrypoint-wrapper.sh
#
# Run startup scripts in sorted order, then supervise Docker and SSH.

set -u

ENTRYPOINT_DIR="/usr/local/bin/entrypoints"

cleanup() {
    status=$?
    trap - EXIT INT TERM

    echo "[entrypoint-wrapper] Stopping services..."
    for service in sshd dockerd; do
        pid=$(pgrep -xo "$service" 2>/dev/null || true)
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
        fi
    done

    exit "$status"
}

trap cleanup EXIT
trap 'exit 143' INT TERM

echo "[entrypoint-wrapper] Starting entrypoint scripts..."
for script in "$ENTRYPOINT_DIR"/*; do
    [ -f "$script" ] || continue

    script_name=$(basename "$script")
    if [ "$script_name" = "entrypoint-wrapper.sh" ] || [ ! -x "$script" ]; then
        echo "[entrypoint-wrapper] Skipping $script..."
        continue
    fi

    echo "[entrypoint-wrapper] Running $script..."
    if "$script"; then
        echo "[entrypoint-wrapper] Finished $script."
    else
        status=$?
        echo "[entrypoint-wrapper] ERROR: $script exited with status $status" >&2
        exit "$status"
    fi
done

wait_for_service() {
    service=$1
    attempt=1

    while [ "$attempt" -le 30 ]; do
        if pgrep -x "$service" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done

    echo "[entrypoint-wrapper] ERROR: $service did not start within 30 seconds." >&2
    return 1
}

wait_for_service dockerd || exit 1
wait_for_service sshd || exit 1
echo "[entrypoint-wrapper] Docker and SSH are running."

while :; do
    if ! pgrep -x dockerd >/dev/null 2>&1; then
        echo "[entrypoint-wrapper] ERROR: dockerd stopped." >&2
        exit 1
    fi

    if ! pgrep -x sshd >/dev/null 2>&1; then
        echo "[entrypoint-wrapper] ERROR: sshd stopped." >&2
        exit 1
    fi

    sleep 2
done

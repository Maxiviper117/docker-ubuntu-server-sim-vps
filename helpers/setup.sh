#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.24.yml"
ENV_FILE="$PROJECT_DIR/.env"
KEY_PATH="${VPS_SSH_KEY_PATH:-$HOME/.ssh/ubuntu24-vps-sim}"
KEY_PATH_FROM_ENV=0
if [ -n "${VPS_SSH_KEY_PATH:-}" ]; then
    KEY_PATH_FROM_ENV=1
fi
KEY_DIR="$(dirname -- "$KEY_PATH")"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: Required command not found: $1" >&2
        exit 1
    }
}

require_command docker
require_command ssh
require_command ssh-keygen

read_env_value() {
    if [ ! -f "$ENV_FILE" ]; then
        return 0
    fi

    awk -F= -v name="$1" '$1 == name {
        value = substr($0, index($0, "=") + 1)
        sub(/^"/, "", value)
        sub(/"$/, "", value)
        print value
        exit
    }' "$ENV_FILE"
}

if ! docker compose version >/dev/null 2>&1; then
    echo "ERROR: Docker Compose is not available." >&2
    exit 1
fi

KEY_ACTION="${VPS_SSH_KEY_ACTION:-}"
if [ -z "$KEY_ACTION" ]; then
    printf '[setup] Create a new SSH key or reuse an existing key? [create/reuse]: '
    read -r KEY_ACTION
fi

case "$(printf '%s' "$KEY_ACTION" | tr '[:upper:]' '[:lower:]')" in
    create)
        if [ "$KEY_PATH_FROM_ENV" -eq 0 ]; then
            printf '[setup] Enter the new key path [%s]: ' "$KEY_PATH"
            read -r requested_key_path
            if [ -n "$requested_key_path" ]; then
                KEY_PATH="$requested_key_path"
            fi
        fi

        if [ -e "$KEY_PATH" ] || [ -e "$KEY_PATH.pub" ]; then
            echo "ERROR: The key path already exists. Choose a new path or select reuse." >&2
            exit 1
        fi

        KEY_DIR="$(dirname -- "$KEY_PATH")"
        mkdir -p "$KEY_DIR"
        chmod 700 "$KEY_DIR"
        echo "[setup] Creating SSH key: $KEY_PATH"
        ssh-keygen -t ed25519 -N "" -C "ubuntu24-vps-sim" -f "$KEY_PATH"
        ;;
    reuse)
        if [ "$KEY_PATH_FROM_ENV" -eq 0 ]; then
            printf '[setup] Enter the existing key path [%s]: ' "$KEY_PATH"
            read -r requested_key_path
            if [ -n "$requested_key_path" ]; then
                KEY_PATH="$requested_key_path"
            fi
        fi

        if [ ! -f "$KEY_PATH" ]; then
            echo "ERROR: Private key not found: $KEY_PATH" >&2
            exit 1
        fi
        ;;
    *)
        echo "ERROR: Select create or reuse." >&2
        exit 1
        ;;
esac

KEY_DIR="$(dirname -- "$KEY_PATH")"
chmod 700 "$KEY_DIR"

if [ ! -f "$KEY_PATH.pub" ]; then
    echo "[setup] Creating public key: $KEY_PATH.pub"
    ssh-keygen -y -f "$KEY_PATH" > "$KEY_PATH.pub"
fi

chmod 600 "$KEY_PATH"
chmod 644 "$KEY_PATH.pub"
PUBLIC_KEY="$(tr -d '\r\n' < "$KEY_PATH.pub")"
if [ -z "$PUBLIC_KEY" ]; then
    echo "ERROR: Public key is empty: $KEY_PATH.pub" >&2
    exit 1
fi

if [ -f "$ENV_FILE" ]; then
    ENV_FILE_TEMP="$(mktemp)"
    awk -v key="$PUBLIC_KEY" '
        BEGIN { updated = 0 }
        /^SSH_PUB_KEY=/ {
            print "SSH_PUB_KEY=\"" key "\""
            updated = 1
            next
        }
        { print }
        END {
            if (!updated) print "SSH_PUB_KEY=\"" key "\""
        }
    ' "$ENV_FILE" > "$ENV_FILE_TEMP"
    mv "$ENV_FILE_TEMP" "$ENV_FILE"
else
    printf 'SSH_PUB_KEY="%s"\n' "$PUBLIC_KEY" > "$ENV_FILE"
fi

VPS_SSH_PORT="${VPS_SSH_PORT:-$(read_env_value VPS_SSH_PORT)}"
VPS_SSH_PORT="${VPS_SSH_PORT:-2222}"
VPS_SSH_ALIAS="${VPS_SSH_ALIAS:-$(read_env_value VPS_SSH_ALIAS)}"
VPS_SSH_ALIAS="${VPS_SSH_ALIAS:-localhost-root}"

SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$(dirname -- "$SSH_CONFIG")"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if ! grep -Fqx "Host $VPS_SSH_ALIAS" "$SSH_CONFIG"; then
    if [ -s "$SSH_CONFIG" ]; then
        printf '\n\n' >> "$SSH_CONFIG"
    else
        printf '\n' >> "$SSH_CONFIG"
    fi
    cat >> "$SSH_CONFIG" <<EOF
Host $VPS_SSH_ALIAS
    HostName localhost
    User root
    Port $VPS_SSH_PORT
    IdentityFile "$KEY_PATH"
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
EOF
    echo "[setup] Added $VPS_SSH_ALIAS to $SSH_CONFIG"
else
    SSH_CONFIG_TEMP="$(mktemp)"
    awk '
        BEGIN { in_host = 0; found_identity = 0 }
        /^Host / {
            if (in_host && !found_identity) print "    IdentitiesOnly yes"
            in_host = ($0 == host_line)
            found_identity = 0
        }
        in_host && /^[[:space:]]*IdentitiesOnly[[:space:]]+/ {
            if (!found_identity) print "    IdentitiesOnly yes"
            found_identity = 1
            next
        }
        { print }
        END {
            if (in_host && !found_identity) print "    IdentitiesOnly yes"
        }
    ' host_line="Host $VPS_SSH_ALIAS" "$SSH_CONFIG" > "$SSH_CONFIG_TEMP"
    mv "$SSH_CONFIG_TEMP" "$SSH_CONFIG"
fi

echo "[setup] Building and starting the Ubuntu VPS simulator..."
docker compose -f "$COMPOSE_FILE" up -d --build
CONTAINER_ID="$(docker compose -f "$COMPOSE_FILE" ps -q vps)"
if [ -z "$CONTAINER_ID" ]; then
    echo "ERROR: The Compose service did not create a container." >&2
    exit 1
fi

echo "[setup] Waiting for the container to become healthy..."
for attempt in $(seq 1 60); do
    health="$(docker inspect --format '{{.State.Health.Status}}' "$CONTAINER_ID" 2>/dev/null || true)"

    case "$health" in
        healthy)
            echo "[setup] Container is healthy."
            break
            ;;
        unhealthy)
            echo "ERROR: Container health check failed." >&2
            docker compose -f "$COMPOSE_FILE" logs --tail=80 vps >&2
            exit 1
            ;;
    esac

    if [ "$attempt" -eq 60 ]; then
        echo "ERROR: Container did not become healthy within 60 seconds." >&2
        docker compose -f "$COMPOSE_FILE" logs --tail=80 vps >&2
        exit 1
    fi

    sleep 1
done

echo "[setup] Testing SSH access..."
KNOWN_HOSTS="$HOME/.ssh/known_hosts"
KNOWN_HOST_NAME="[localhost]:$VPS_SSH_PORT"
if [ -f "$KNOWN_HOSTS" ] && ssh-keygen -F "$KNOWN_HOST_NAME" -f "$KNOWN_HOSTS" >/dev/null 2>&1; then
    echo "[setup] Removing the old local simulator host key..."
    ssh-keygen -R "$KNOWN_HOST_NAME" -f "$KNOWN_HOSTS" >/dev/null
fi
ssh -o BatchMode=yes -o ConnectTimeout=10 -o IdentitiesOnly=yes -i "$KEY_PATH" "$VPS_SSH_ALIAS" 'echo "SSH login successful."'

echo
echo "Setup complete. Connect with: ssh $VPS_SSH_ALIAS"

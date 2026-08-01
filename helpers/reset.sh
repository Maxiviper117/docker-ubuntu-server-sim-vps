#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.24.yml"

if [ "${VPS_FORCE_RESET:-0}" != "1" ]; then
    printf 'Reset the VPS and delete its Docker volume? Type RESET to continue: '
    read -r confirmation
    if [ "$confirmation" != "RESET" ]; then
        echo "Reset cancelled."
        exit 0
    fi
fi

docker compose -f "$COMPOSE_FILE" down -v --remove-orphans
ssh-keygen -R "[localhost]:2222" >/dev/null 2>&1 || true
echo "VPS reset complete."

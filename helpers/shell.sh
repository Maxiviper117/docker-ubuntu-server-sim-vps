#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.24.yml"

if [ "$#" -eq 0 ]; then
    docker compose -f "$COMPOSE_FILE" exec vps bash
else
    docker compose -f "$COMPOSE_FILE" exec vps bash "$@"
fi

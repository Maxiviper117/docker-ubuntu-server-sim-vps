#!/bin/bash
# Remove old SSH host key for localhost:2222
ssh-keygen -R "[localhost]:2222"

# Start the Docker container using docker-compose
# Make sure your .env file is configured with your public key

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
docker compose -f "$SCRIPT_DIR/../docker-compose.24.yml" up -d

#!/bin/sh
set -e

echo "[01-ssh-setup] Starting SSH key setup..."
# Get the SSH public key from the environment variable SSH_PUB_KEY
# exit if SSH_PUB_KEY is empty or not set
if [ -z "$SSH_PUB_KEY" ]; then
    echo "[01-ssh-setup] Error: SSH_PUB_KEY env var is empty or not set" >&2
    exit 1
fi

# write SSH_PUB_KEY into authorized_keys

echo "[01-ssh-setup] Ensuring /root/.ssh directory exists with correct permissions..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh

if [ ! -f /root/.ssh/authorized_keys ]; then
    echo "[01-ssh-setup] Creating /root/.ssh/authorized_keys file..."
    touch /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
else
    echo "[01-ssh-setup] /root/.ssh/authorized_keys already exists. Overwriting."
fi

echo "[01-ssh-setup] Writing SSH public key to /root/.ssh/authorized_keys..."
echo "$SSH_PUB_KEY" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
echo "[01-ssh-setup] SSH key setup complete."

# hand off to the original start script (if this script is run directly)
#!/bin/sh
set -e

# exit if SSH_PUB_KEY is empty or not set
if [ -z "$SSH_PUB_KEY" ]; then
    echo "Error: SSH_PUB_KEY env var is empty or not set" >&2
    exit 1
fi

# write SSH_PUB_KEY into authorized_keys
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$SSH_PUB_KEY" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# hand off to the original start script
exec /start.sh
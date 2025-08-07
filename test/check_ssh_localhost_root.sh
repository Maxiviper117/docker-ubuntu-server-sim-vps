#!/bin/bash

# # Test SSH login to "ssh localhost-root"
# SSH_USER="root"
# SSH_HOST="localhost-root"

# echo "Testing SSH login to $SSH_USER@$SSH_HOST..."

# ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SSH_HOST" 'echo "SSH login successful."' 2>&1

# if [ $? -eq 0 ]; then
#     echo "SSH login to $SSH_USER@$SSH_HOST succeeded."
#     exit 0
# else
#     echo "SSH login to $SSH_USER@$SSH_HOST failed."
#     exit 1
# fi
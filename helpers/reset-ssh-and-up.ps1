# Remove old SSH host key for localhost:2222
ssh-keygen -R "[localhost]:2222"

# Start the Docker container using docker-compose
# Make sure your .env file is configured with your public key

$composeFile = Join-Path $PSScriptRoot "..\docker-compose.24.yml"
docker compose -f $composeFile up -d

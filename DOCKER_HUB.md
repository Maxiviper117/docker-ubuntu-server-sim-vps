# Ubuntu VPS Simulator

A Docker container that simulates a full Ubuntu VPS environment with SSH access and Docker-in-Docker capabilities. Perfect for development, testing, and learning environments.

## Features

- 🐳 Docker-in-Docker support
- 🔒 Secure SSH access
- 🔄 Privileged container mode
- 📦 Based on Ubuntu 22.04
- 🛠️ Pre-installed tools (Docker, SSH server, curl, etc.)
- 🚀 Exposed ports for various services

## Quick Start

```bash
# Pull the image
docker pull maxiviper117/ubuntu-vps-simulate:latest

# Create a .env file with your SSH public key
echo 'SSH_PUB_KEY="your-ssh-public-key-here"' > .env

# Run with Docker Compose
docker-compose up -d
```

## Environment Variables

- `SSH_PUB_KEY` (required): Your SSH public key for authentication

## Ports

- 22: SSH server (mapped to 2222 by default)
- 2375: Docker daemon
- 80: HTTP (mapped to 8080)
- 443: HTTPS (mapped to 8443)

## Usage Examples

### 1. Start the Container

```yaml
# docker-compose.yml
services:
  vps:
    image: maxiviper117/ubuntu-vps-simulate:latest
    env_file:
      - .env    
    ports:
      - "2222:22"
      - "2375:2375"
      - "8080:80"
      - "8443:443"
    privileged: true
    restart: unless-stopped
    volumes:
      - vps_docker:/var/lib/docker

volumes:
  vps_docker:
    driver: local
```

### 2. Connect via SSH

```bash
# Add to ~/.ssh/config:
Host localhost-vps
    HostName localhost
    User root
    Port 2222
    IdentityFile ~/.ssh/your_key

# Connect
ssh localhost-vps
```

## Security Notes

- Always use SSH key authentication (password authentication is disabled)
- The container runs in privileged mode for Docker-in-Docker support
- Customize exposed ports based on your security requirements

## Support

For issues and feature requests, visit our [GitHub repository](https://github.com/yourusername/docker-ubuntu-server-sim-vps).

## License

MIT License

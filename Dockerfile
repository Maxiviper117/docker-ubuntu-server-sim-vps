# Base image
FROM ubuntu:22.04

# Avoid interactive prompts during package installs
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    openssh-server \
    curl \
    ca-certificates \
    gnupg \
    lsb-release && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Docker
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add root to the docker group to run Docker commands
RUN usermod -aG docker root

# Set up SSH
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

# Copy SSH public key for root
# RUN mkdir -p /root/.ssh && \
#     chmod 700 /root/.ssh
# COPY SSH_Key_Windows_Desktop.pub /root/.ssh/authorized_keys
# RUN chmod 600 /root/.ssh/authorized_keys

# Expose ports (SSH, Docker daemon, HTTP, HTTPS)
EXPOSE 22
EXPOSE 2375
EXPOSE 80
EXPOSE 443

# Create a startup script to launch both dockerd and sshd
RUN echo '#!/bin/bash\n\
    dockerd --host=0.0.0.0:2375 --host=unix:///var/run/docker.sock &\n\
    /usr/sbin/sshd -D' > /start.sh && \
    chmod +x /start.sh

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Use it to inject SSH_PUB_KEY then run /start.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/start.sh"]

# Build:
# docker build -t maxiviper117/ubuntu-vps-simulate .

# Tag the image with the current date and time in powershell:
# $date = Get-Date -Format "yyyyMMdd-HHmmss" ; docker tag maxiviper117/ubuntu-vps-simulate maxiviper117/ubuntu-vps-simulate:$date

# Push to Docker Hub:


# Run:
# docker run -d -p 2222:22 -p 2375:2375 -p 8080:80 -p 8443:443 --privileged --name ubuntu-vps-simulate maxiviper117/ubuntu-vps-simulate

# Note: Before connecting, you'll need to:
# 1. Generate an SSH key pair
# 2. Copy your public key to the container
# 3. Connect using: ssh -i /path/to/private_key root@localhost -p 2222

# Using 1password to copy the public key to $publicKey terminal session variable for 1password ssh key stored in 'Docker Simulated VPS' item
# $publicKey = op item get "Docker Simulated VPS" --fields "public key" 

# $publicKey | docker exec -i ubuntu-vps-simulate sh -c 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'

# Add to ~/.ssh/config file:
# Host localhost-root
    # HostName localhost
    # User root
    # Port 2222
    # IdentityAgent "\\.\pipe\openssh-ssh-agent"
    # IdentitiesOnly yes

# Login using:
# ssh localhost-root

# If you want to use ssh root@localhost -p 2222 directly, you must use define IdentityAgent in the same command:
# ssh -o IdentityAgent=\\.\pipe\openssh-ssh-agent root@localhost -p 2222
# else ssh does not know where to find the private key - in this case we useing 1password ssh agent for the key

# If prompted for a password, use 'dockerroot' (or change the password in the Dockerfile)
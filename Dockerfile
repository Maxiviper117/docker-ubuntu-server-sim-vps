# ────────────────────────────────────────────────────────────────────
# 1. Base image and apt speedup
# ────────────────────────────────────────────────────────────────────
FROM ubuntu:22.04

# Speed up apt
RUN cat > /etc/apt/apt.conf.d/99custom <<'EOF'
Acquire::http::Pipeline-Depth "0";
Acquire::http::No-Cache "true";
Acquire::BrokenProxy    "true";
EOF

# ────────────────────────────────────────────────────────────────────
# 2. Environment variables
# ────────────────────────────────────────────────────────────────────
# Avoid interactive prompts during package installs
ENV DEBIAN_FRONTEND=noninteractive

# ────────────────────────────────────────────────────────────────────
# 3. Base packages
# ────────────────────────────────────────────────────────────────────
# openssh-server: for SSH access
# curl: for downloading files and Docker GPG key
# ca-certificates: for HTTPS support
# gnupg: for handling GPG keys (Docker repo)
# lsb-release: for detecting Ubuntu version (Docker repo)
# nano: a text editor
RUN apt-get update && \
    apt-get install -y \
    openssh-server \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    nano && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ────────────────────────────────────────────────────────────────────
# 4. Docker installation
# ────────────────────────────────────────────────────────────────────
# Set up Docker's official GPG key and repository, then install Docker Engine and CLI
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

# ────────────────────────────────────────────────────────────────────
# 5. User and SSH setup
# ────────────────────────────────────────────────────────────────────
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

# ────────────────────────────────────────────────────────────────────
# 6. Exposed ports
# ────────────────────────────────────────────────────────────────────
# Expose ports (SSH, Docker daemon, HTTP, HTTPS)
EXPOSE 22
EXPOSE 2375
EXPOSE 80
EXPOSE 443


# ────────────────────────────────────────────────────────────────────
# 8. Tini installation
# ────────────────────────────────────────────────────────────────────
# tini: minimal init system to handle signals and zombie processes
RUN apt-get update && apt-get install -y tini && apt-get clean && rm -rf /var/lib/apt/lists/*

# ────────────────────────────────────────────────────────────────────
# 9. Entrypoint and CMD
# ────────────────────────────────────────────────────────────────────



# Install dos2unix for line ending conversion
RUN apt-get update && apt-get install -y dos2unix && apt-get clean && rm -rf /var/lib/apt/lists/*
# Copy all entrypoint scripts, including the wrapper
COPY .infrastructure/scripts/ /usr/local/bin/entrypoints/
# Convert all scripts to LF line endings and set executable
RUN find /usr/local/bin/entrypoints/ -type f -exec dos2unix {} \; && chmod +x /usr/local/bin/entrypoints/*

# Use tini as the entrypoint for signal forwarding and graceful shutdown
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoints/entrypoint-wrapper.sh"]
CMD []

# ────────────────────────────────────────────────────────────────────
# 10. Build and tag instructions
# ────────────────────────────────────────────────────────────────────
# Build:
# docker build -t ubuntu22-vps-sim .

# Tag the image with the current date and time in powershell:
# $date = Get-Date -Format "yyyyMMdd-HHmmss" ; docker tag ubuntu22-vps-sim ubuntu22-vps-sim:$date




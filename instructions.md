# 🚀 SSH & Docker Setup Guide for `ubuntu-vps-simulate`

This guide helps you run a simulated Ubuntu VPS using Docker and connect to it over SSH with ease.

---

## 🔐 Step 1: Generate an SSH Key Pair

Before building or running the container, you need to generate an SSH key pair. The public key will be added to the container for secure access.

### Option 1: Using 1Password

Generate an Ed25519 SSH key from within the 1Password app.
Then **download the private key** and save it to:

```bash
C:\Users\david\.ssh\SSH-Key-Windows-Desktop
```

### Option 2: Using `ssh-keygen`

```bash
ssh-keygen -t ed25519 -C "your_email@example.com" -f "C:\Users\david\.ssh\SSH-Key-Windows-Desktop"
```

This creates both public and private keys at the specified path.

---

## 📋 Step 2: Add Your Public Key to the `.env` File

Copy the contents of your public key (e.g., `C:\Users\david\.ssh\SSH-Key-Windows-Desktop.pub`) and paste it into the appropriate variable in your `.env` file. This ensures the Docker image build will add your key to the container's `authorized_keys`.

---

## 🛠️ Step 3: Build the Docker Image

Build the Docker image locally before running the container. You can name the image whatever you like. For example, to build and tag the image:

```bash
# Build the image with a custom name and tag
 docker build -t my-ubuntu-vps-sim .
```

You can also tag the image with the current date and time (PowerShell example):

```powershell
$date = Get-Date -Format "yyyyMMdd-HHmmss" ; docker tag my-ubuntu-vps-sim my-ubuntu-vps-sim:$date
```

If you want to push your custom image to a registry, you can use the provided `push-image.sh` script (Linux/macOS/WSL):

```bash
./push-image.sh [version]
```

> The script will use the latest git tag as the version if you do not provide one.

---

## 🐳 Step 4: Run the Docker Container

You can start the container using either Docker Compose or a direct `docker run` command. Make sure your `.env` file is configured with your public key before this step.

### Option 1: Docker Compose

Use the included `docker-compose.yml` file:

```bash
docker compose up -d
```

### Option 2: Docker Run

Alternatively, run the container directly:

```bash
docker run -d \
  -p 2222:22 \
  -p 2375:2375 \
  -p 8080:80 \
  -p 8443:443 \
  --privileged \
  --name ubuntu-vps-simulate \
  my-ubuntu-vps-sim
```

---

## ⚙️ Step 5: Configure SSH for Easy Access

Edit (or create) your SSH config file at `~/.ssh/config` and add:

```bash
Host localhost-root
    HostName localhost
    User root
    Port 2222
    IdentityFile "C:\Users\david\.ssh\SSH-Key-Windows-Desktop"
```

> ✅ **1Password Note**: If you're using a 1Password-managed key, you may need to approve the connection when prompted via the 1Password app.

Now you can connect with a simple command:

```bash
ssh localhost-root
```

---

## 📤 Step 6: (Optional) Copy Your Public Key to the Container After Running

> **Note:** The SSH public key is already added to the container during the Docker image build, using the key defined in your `.env` file. You only need to manually copy your public key if you want to override or add additional keys after the container is running.

Authorize SSH access by copying your public key into the container (if needed):

```bash
docker cp "C:\Users\david\.ssh\SSH-Key-Windows-Desktop.pub" ubuntu-vps-simulate:/root/.ssh/authorized_keys
```

Ensure the container’s `/root/.ssh/authorized_keys` file exists and has correct permissions.

---

## 🔌 Step 7: Connect via SSH

Connect using the configured host alias:

```bash
ssh localhost-root
```

You should now have full SSH access to your simulated Ubuntu VPS.

---

## 🧯 Troubleshooting: SSH Host Identification Has Changed

If you see:

```
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```

It likely means the container was recreated and has a new host key.

Fix it with:

```bash
ssh-keygen -R "[localhost]:2222"
```
> This command removes the old host key from your known hosts file.

Then try again:

```bash
ssh localhost-root
```

---

## ✅ Done!

You’ve successfully:

* Generated and configured SSH keys
* Added your public key to the container build
* Started the container
* Connected securely using an alias


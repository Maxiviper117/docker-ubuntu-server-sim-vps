# 🚀 SSH & Docker Setup Guide for `ubuntu-vps-simulate` (Windows)

This guide helps you run a simulated Ubuntu VPS using Docker and connect to it over SSH on Windows.

---

## 🔐 Step 1: Generate an SSH Key Pair


Generate an Ed25519 SSH key using 1Password or `ssh-keygen`.

> [!Note]
> The key file can be named anything you like. Just be consistent and update the rest of the instructions to match your chosen name.

### Option 1: Using 1Password

Generate an Ed25519 SSH key in 1Password, then **download the private key** and save it to:

```
C:\Users\<user>\.ssh\SSH-Key-Windows-Desktop
```

### Option 2: Using `ssh-keygen`

```powershell
ssh-keygen -t ed25519 -C "your_email@example.com" -f "C:\Users\<user>\.ssh\SSH-Key-Windows-Desktop"
```

---

## 📋 Step 2: Add Your Public Key to the `.env` File

Copy the contents of your public key (e.g., `C:\Users\<user>\.ssh\SSH-Key-Windows-Desktop.pub`) and paste it into the SSH_PUB_KEY="" variable in your `.env` file.

---

## 🛠️ Step 3: Build the Docker Image

Build the Docker image locally before running the container:

```powershell
# Build the image with a custom name and tag
docker build -f Dockerfile.24 -t ubuntu24-vps-sim .
```

---

## 🐳 Step 4: Run the Docker Container

Start the container using Docker Compose. Make sure your `.env` file is configured with your public key.

```powershell
docker compose -f docker-compose.24.yml up -d
```

---

## ⚙️ Step 5: Configure SSH for Easy Access

Edit (or create) your SSH config file at `~/.ssh/config` and add:

```
Host localhost-root
    HostName localhost
    User root
    Port 2222
    IdentityFile "C:\Users\{username}\.ssh\SSH-Key-Windows-Desktop"
```

> [!NOTE]
> If using a 1Password-managed key, approve the connection when prompted via the 1Password app.
> 
> Connect with:
> 
> ```powershell
> ssh localhost-root
> ```

---

## 📤 Step 6: (Optional) Copy Your Public Key to the Container After Running

If you want to override or add additional keys after the container is running:

```powershell
docker cp "C:\Users\{username}\.ssh\SSH-Key-Windows-Desktop.pub" ubuntu-vps-simulate:/root/.ssh/authorized_keys
```

Ensure the container’s `/root/.ssh/authorized_keys` file exists and has correct permissions.

---

## 🔌 Step 7: Connect via SSH

Connect using the configured host alias:

```powershell
ssh localhost-root
```

---

## 🧯 Troubleshooting: SSH Host Identification Has Changed

If you see:

```
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```

Fix it with:

```powershell
ssh-keygen -R "[localhost]:2222"
```

Then try again:

```powershell
ssh localhost-root
```

---

## ✅ Done!

You’ve successfully:

* Generated and configured SSH keys
* Added your public key to the container build
* Started the container
* Connected securely using an alias

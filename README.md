## 🛠️ Connecting Directly via SSH (Manual Setup)

If you need to connect *directly* to the container using a standard SSH client (outside of Docker contexts), you can configure your local SSH client.

1.  **Export Private Key:** In your 1Password app, find your SSH key, right-click the **private key** file, select `Export`, and save it to your local machine (e.g., in your `$HOME/.ssh/` or `~/.ssh/` directory).
2.  **Configure SSH Client:** Edit your `~/.ssh/config` file (create it if it doesn't exist). Add an entry specifying the connection details and pointing `IdentityFile` to the path of the private key you just exported.

    *Example `~/.ssh/config` entry:*
    ```bash
    # Connect to the container running on localhost:2222 as root
    Host localhost-root-container
        HostName localhost
        User root
        Port 2222
        # Update this path to where you saved your private key
        IdentityFile ~/.ssh/your_exported_private_key_filename
    ```
3.  **Connect:** You can now connect using `ssh localhost-root-container`. If your key is passphrase-protected, 1Password (or your system) might prompt you for it the first time. Using `ssh-agent` (see below) can avoid repeated prompts.

> [!NOTE]
> Explicitly defining the `IdentityFile` in your `~/.ssh/config` helps prevent "too many authentication failures" errors by telling the SSH client exactly which key to use, rather than trying all available keys.

---

### Avoiding SSH Key Passphrase Prompts with `ssh-agent` (Windows)

If your SSH private key (used either for direct connections or within a Docker context) is protected by a passphrase, you'll be prompted for it repeatedly. To avoid this, use the `ssh-agent` service to securely manage your key's passphrase in the background for your session.

**Setup Steps (Windows Built-in OpenSSH):**

1.  **Ensure `ssh-agent` Service is Running:**
    *   Open **PowerShell as Administrator**.
    *   Check the service status: `Get-Service ssh-agent`
    *   If it's `Stopped`, enable automatic startup and start it:
        ```powershell
        Set-Service -Name ssh-agent -StartupType Automatic
        Start-Service ssh-agent
        ```

2.  **Add Your SSH Private Key to the Agent:**
    *   Open a regular **PowerShell** or **Command Prompt**.
    *   Use the `ssh-add` command, providing the path to your **private** key file:
        ```powershell
        # Replace with the actual path to your private key file
        ssh-add ~\.ssh\your_private_key_filename
        ```
    *   Enter your key's passphrase when prompted.

Once added, the agent handles the key, and SSH connections (including those made by Docker contexts) using this key should no longer prompt for the passphrase during your current login session.

> [!NOTE]
> *   **WSL / Git Bash:** The process is similar: start the agent (often with `eval $(ssh-agent -s)`) and then use `ssh-add`. Using the native Windows `ssh-agent.exe` often provides better integration across different Windows terminals.
> *   **Tailscale Users:** If using Tailscale SSH, it might manage authentication differently, potentially bypassing the need for `ssh-agent` depending on your Tailscale setup.

# Running the Container

Follow these steps to build the Docker image and run the container using Docker Compose.

## 1. Prepare Environment File

*   Create a file named `.env` in the same directory as your `docker-compose.yml`.
*   Add the `SSH_PUB_KEY` variable to this `.env` file, setting its value to the **public key** you want to grant SSH access to within the container. This key will be added to the `~/.ssh/authorized_keys` file inside the container.

    *Example `.env` content:*
    ```dotenv
    # ~/.ssh/id_rsa.pub or similar public key content
    SSH_PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQ..."
    ```

## 2. Build the Docker Image (Optional if using Compose)

While `docker-compose up --build` handles this, you can build the image manually if needed:

```bash
docker build -t maxiviper117/ubuntu-vps-simulate .
```

## 3. Run the Container with Docker Compose

This command will build the image (if not already built or if changes are detected) and start the container in detached mode (`-d`).

```bash
docker-compose up -d --build
```

The container should now be running, accessible via SSH on port 2222 (or as configured in `docker-compose.yml`) using the key specified in the `.env` file.


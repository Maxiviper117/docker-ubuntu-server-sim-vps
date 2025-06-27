You have two simple ways to run a local bash script on a remote VPS over SSH:

---

### 1. Pipe the script via SSH

This method sends your script over the SSH connection and runs it without leaving any file behind on the server:

```bash
ssh user@your.vps.ip 'bash -s' < ./your-script.sh
```

* `user@your.vps.ip` → your SSH login
* `'bash -s'` → tells the remote shell to read a script from stdin
* `< ./your-script.sh` → feeds your local script into that SSH session

---

### 2. Copy then execute

If you’d rather have the file on the server (for logging, reruns, or inspection), first copy it, then ssh in and run it:

```bash
scp ./your-script.sh user@your.vps.ip:/tmp/
ssh user@your.vps.ip 'bash /tmp/your-script.sh'
```

* `scp` copies the file to `/tmp` on the VPS
* The `ssh` command then invokes `bash` on that file

---

#### Tips

* If you use a non-standard SSH key, add `-i /path/to/key` after `ssh` or `scp`.
* Combine into one line if you like:

  ```bash
  scp ./your-script.sh user@your.vps.ip:/tmp/ && \
    ssh user@your.vps.ip 'bash /tmp/your-script.sh'
  ```
* Clean up afterward if you don’t need the script on the server:

  ```bash
  ssh user@your.vps.ip 'rm /tmp/your-script.sh'
  ```

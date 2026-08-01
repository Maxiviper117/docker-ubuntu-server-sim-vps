$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$composeFile = Join-Path $projectDir "docker-compose.24.yml"
$envFile = Join-Path $projectDir ".env"
$keyPath = if ($env:VPS_SSH_KEY_PATH) { $env:VPS_SSH_KEY_PATH } else { Join-Path $HOME ".ssh\ubuntu24-vps-sim" }
$keyPathFromEnvironment = -not [string]::IsNullOrWhiteSpace($env:VPS_SSH_KEY_PATH)
$keyDirectory = Split-Path -Parent $keyPath

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Get-EnvFileValue([string]$Name) {
    if (-not (Test-Path -LiteralPath $envFile)) {
        return $null
    }

    $line = Get-Content -LiteralPath $envFile | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -First 1
    if (-not $line) {
        return $null
    }

    return ($line -replace "^$([regex]::Escape($Name))=", "").Trim().Trim('"')
}

function Resolve-OpenSshCommand([string]$Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Path
    }

    $windowsRoots = @(
        "C:\Windows\Sysnative",
        "C:\Windows\System32",
        $env:WINDIR,
        $env:SystemRoot,
        [Environment]::GetFolderPath("Windows"),
        "C:\Windows\System32"
    ) | Where-Object { $_ } | Select-Object -Unique

    foreach ($windowsRoot in $windowsRoots) {
        $windowsOpenSshPath = if ($windowsRoot -match "(Sysnative|System32)$") {
            Join-Path $windowsRoot "OpenSSH\${Name}.exe"
        } else {
            Join-Path $windowsRoot "System32\OpenSSH\${Name}.exe"
        }
        if (Test-Path -LiteralPath $windowsOpenSshPath) {
            Write-Host "[setup] Using Windows OpenSSH: $windowsOpenSshPath"
            return $windowsOpenSshPath
        }
    }

    throw "Required command not found: $Name"
}

function Protect-SshFile([string]$Path) {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    & icacls $Path /inheritance:r /grant:r "${currentUser}:(F)" /grant:r "*S-1-5-18:(F)" /grant:r "*S-1-5-32-544:(F)" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not set SSH permissions: $Path"
    }
}

Require-Command "docker"
$sshCommand = Resolve-OpenSshCommand "ssh"
$sshKeygenCommand = Resolve-OpenSshCommand "ssh-keygen"

& docker compose version | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose is not available."
}

$keyAction = if ($env:VPS_SSH_KEY_ACTION) { $env:VPS_SSH_KEY_ACTION } else { Read-Host "[setup] Create a new SSH key or reuse an existing key? [create/reuse]" }

switch ($keyAction.ToLowerInvariant()) {
    "create" {
        if (-not $keyPathFromEnvironment) {
            $requestedKeyPath = Read-Host "[setup] Enter the new key path [$keyPath]"
            if ($requestedKeyPath) {
                $keyPath = $requestedKeyPath
            }
        }

        if ((Test-Path -LiteralPath $keyPath) -or (Test-Path -LiteralPath "$keyPath.pub")) {
            throw "The key path already exists. Choose a new path or select reuse."
        }

        $keyDirectory = Split-Path -Parent $keyPath
        New-Item -ItemType Directory -Force -Path $keyDirectory | Out-Null
        Write-Host "[setup] Creating SSH key: $keyPath"
        & $sshKeygenCommand -t ed25519 -N "" -C "ubuntu24-vps-sim" -f $keyPath
        if ($LASTEXITCODE -ne 0) {
            throw "SSH key creation failed."
        }
    }
    "reuse" {
        if (-not $keyPathFromEnvironment) {
            $requestedKeyPath = Read-Host "[setup] Enter the existing key path [$keyPath]"
            if ($requestedKeyPath) {
                $keyPath = $requestedKeyPath
            }
        }

        if (-not (Test-Path -LiteralPath $keyPath)) {
            throw "Private key not found: $keyPath"
        }
    }
    default {
        throw "Select create or reuse."
    }
}

$keyDirectory = Split-Path -Parent $keyPath
New-Item -ItemType Directory -Force -Path $keyDirectory | Out-Null

$publicKeyPath = "$keyPath.pub"
if (-not (Test-Path -LiteralPath $publicKeyPath)) {
    Write-Host "[setup] Creating public key: $publicKeyPath"
    & $sshKeygenCommand -y -f $keyPath | Set-Content -NoNewline -Path $publicKeyPath
    if ($LASTEXITCODE -ne 0) {
        throw "Public key creation failed."
    }
}

Protect-SshFile $keyPath

$publicKey = (Get-Content -Raw -LiteralPath $publicKeyPath).Trim()
if ([string]::IsNullOrWhiteSpace($publicKey)) {
    throw "Public key is empty: $publicKeyPath"
}

if (Test-Path -LiteralPath $envFile) {
    $envLines = @(Get-Content -LiteralPath $envFile)
    $keyLine = 'SSH_PUB_KEY="' + $publicKey + '"'
    $updated = $false
    $newLines = foreach ($line in $envLines) {
        if ($line -match '^SSH_PUB_KEY=') {
            $updated = $true
            $keyLine
        } else {
            $line
        }
    }

    if (-not $updated) {
        $newLines += $keyLine
    }

    Set-Content -LiteralPath $envFile -Value $newLines
} else {
    Set-Content -LiteralPath $envFile -Value ('SSH_PUB_KEY="' + $publicKey + '"')
}

$sshPort = if ($env:VPS_SSH_PORT) { $env:VPS_SSH_PORT } else { Get-EnvFileValue "VPS_SSH_PORT" }
if (-not $sshPort) { $sshPort = "2222" }
$sshAlias = if ($env:VPS_SSH_ALIAS) { $env:VPS_SSH_ALIAS } else { Get-EnvFileValue "VPS_SSH_ALIAS" }
if (-not $sshAlias) { $sshAlias = "localhost-root" }

$sshDirectory = Join-Path $HOME ".ssh"
$sshConfig = Join-Path $sshDirectory "config"
New-Item -ItemType Directory -Force -Path $sshDirectory | Out-Null
if (-not (Test-Path -LiteralPath $sshConfig)) {
    New-Item -ItemType File -Path $sshConfig | Out-Null
}

Protect-SshFile $sshConfig

$sshConfigText = Get-Content -Raw -LiteralPath $sshConfig
if ($sshConfigText -notmatch "(?m)^Host $([regex]::Escape($sshAlias))\s*$") {
    $configBlock = @"
Host $sshAlias
    HostName localhost
    User root
    Port $sshPort
    IdentityFile "$keyPath"
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
"@
    $separator = if ([string]::IsNullOrEmpty($sshConfigText)) { [Environment]::NewLine } else { [Environment]::NewLine + [Environment]::NewLine }
    Set-Content -LiteralPath $sshConfig -Value ($sshConfigText.TrimEnd() + $separator + $configBlock.TrimStart())
    Write-Host "[setup] Added $sshAlias to $sshConfig"
} else {
    $hostBlockPattern = "(?ms)^Host $([regex]::Escape($sshAlias))\s*$.*?(?=^Host\s|\z)"
    $hostMatch = [System.Text.RegularExpressions.Regex]::Match($sshConfigText, $hostBlockPattern)
    if ($hostMatch.Success -and $hostMatch.Value -notmatch '(?mi)^\s*IdentitiesOnly\s+') {
        $hostBlock = $hostMatch.Value.TrimEnd() + [Environment]::NewLine + "    IdentitiesOnly yes" + [Environment]::NewLine
        $sshConfigText = $sshConfigText.Substring(0, $hostMatch.Index) + $hostBlock + $sshConfigText.Substring($hostMatch.Index + $hostMatch.Length)
        Set-Content -LiteralPath $sshConfig -Value $sshConfigText
        Write-Host "[setup] Updated $sshAlias to use one SSH identity."
    }
}

Write-Host "[setup] Building and starting the Ubuntu VPS simulator..."
& docker compose -f $composeFile up -d --build
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose startup failed."
}

$containerId = (& docker compose -f $composeFile ps -q vps | Out-String).Trim()
if (-not $containerId) {
    throw "The Compose service did not create a container."
}

Write-Host "[setup] Waiting for the container to become healthy..."
$healthy = $false
for ($attempt = 1; $attempt -le 60; $attempt++) {
    $health = (& docker inspect --format '{{.State.Health.Status}}' $containerId 2>$null | Out-String).Trim()

    if ($health -eq "healthy") {
        $healthy = $true
        Write-Host "[setup] Container is healthy."
        break
    }

    if ($health -eq "unhealthy") {
        & docker compose -f $composeFile logs --tail=80 vps
        throw "Container health check failed."
    }

    Start-Sleep -Seconds 1
}

if (-not $healthy) {
    & docker compose -f $composeFile logs --tail=80 vps
    throw "Container did not become healthy within 60 seconds."
}

Write-Host "[setup] Testing SSH access..."
$knownHosts = Join-Path $sshDirectory "known_hosts"
$knownHostName = "[localhost]:$sshPort"
if (Test-Path -LiteralPath $knownHosts) {
    $knownHostMatch = & $sshKeygenCommand -F $knownHostName -f $knownHosts 2>$null | Out-String
    if ($knownHostMatch.Trim()) {
        Write-Host "[setup] Removing the old local simulator host key..."
        & $sshKeygenCommand -R $knownHostName -f $knownHosts | Out-Null
    }
}
& $sshCommand -o BatchMode=yes -o ConnectTimeout=10 -o IdentitiesOnly=yes -i $keyPath $sshAlias 'echo "SSH login successful."'
if ($LASTEXITCODE -ne 0) {
    throw "SSH login failed."
}

Write-Host ""
Write-Host "Setup complete. Connect with: ssh $sshAlias"

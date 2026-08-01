$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$composeFile = Join-Path $projectDir "docker-compose.24.yml"

if ($env:VPS_FORCE_RESET -ne "1") {
    $confirmation = Read-Host "Reset the VPS and delete its Docker volume? Type RESET to continue"
    if ($confirmation -cne "RESET") {
        Write-Host "Reset cancelled."
        exit 0
    }
}

& docker compose -f $composeFile down -v --remove-orphans
& ssh-keygen -R "[localhost]:2222" 2>$null
if ($LASTEXITCODE -ne 0) {
    $LASTEXITCODE = 0
}
Write-Host "VPS reset complete."

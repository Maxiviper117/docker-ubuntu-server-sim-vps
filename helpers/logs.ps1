$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$composeFile = Join-Path $projectDir "docker-compose.24.yml"

& docker compose -f $composeFile logs --tail=100 -f vps

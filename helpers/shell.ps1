$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$composeFile = Join-Path $projectDir "docker-compose.24.yml"

if ($args.Count -eq 0) {
    & docker compose -f $composeFile exec vps bash
} else {
    & docker compose -f $composeFile exec vps bash @args
}

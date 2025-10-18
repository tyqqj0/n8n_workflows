$ErrorActionPreference = 'Stop'

# Change to script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "[n8n] Checking Docker environment..." -ForegroundColor Cyan

function Test-DockerAvailable {
    try {
        docker --version | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-DockerRunning {
    try {
        docker info | Out-Null
        return $true
    } catch {
        return $false
    }
}

if (-not (Test-DockerAvailable)) {
    Write-Error "Docker not found. Please install Docker Desktop and ensure it's in PATH."
    exit 1
}

if (-not (Test-DockerRunning)) {
    Write-Error "Docker daemon is not running. Start Docker Desktop and retry."
    exit 1
}

# Check docker compose v2
$useComposeV2 = $true
try {
    docker compose version | Out-Null
} catch {
    $useComposeV2 = $false
}

# Ensure data volume exists
Write-Host "[n8n] Preparing persistent volume n8n_data..." -ForegroundColor Cyan
try {
    docker volume inspect n8n_data | Out-Null
} catch {
    docker volume create n8n_data | Out-Null
    Write-Host "[n8n] Created volume n8n_data" -ForegroundColor Green
}

# Autogenerate .env if missing (won't overwrite existing)
if (-not (Test-Path ".env")) {
    Write-Host "[n8n] .env not found; generating..." -ForegroundColor Yellow

    function New-RandomString {
        param([int]$Length = 24)
        $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
        -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Max $chars.Length)] })
    }

    $basicAuthUser = 'admin'
    $basicAuthPassword = New-RandomString -Length 24
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $encKey = ($bytes | ForEach-Object { $_.ToString('X2') }) -join ''

    $envContent = @"
GENERIC_TIMEZONE=Asia/Shanghai
TZ=Asia/Shanghai
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_RUNNERS_ENABLED=true
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=$basicAuthUser
N8N_BASIC_AUTH_PASSWORD=$basicAuthPassword
N8N_ENCRYPTION_KEY=$encKey
N8N_HOST=localhost
N8N_PORT=5678
WEBHOOK_URL=http://localhost:5678/
"@

    Set-Content -Path ".env" -Value $envContent -Encoding UTF8
    Write-Host "[n8n] .env generated" -ForegroundColor Green
    Write-Host "[n8n] Login user: $basicAuthUser" -ForegroundColor Green
    Write-Host "[n8n] Login password: $basicAuthPassword" -ForegroundColor Green
}

# Ensure compose.yml exists
if (-not (Test-Path "compose.yml")) {
    Write-Error "compose.yml not found. Ensure it is in the same directory as this script."
}

Write-Host "[n8n] Pulling image and starting..." -ForegroundColor Cyan
if ($useComposeV2) {
    docker compose pull
    if ($LASTEXITCODE -ne 0) { Write-Error "docker compose pull failed."; exit $LASTEXITCODE }
    docker compose up -d
    if ($LASTEXITCODE -ne 0) { Write-Error "docker compose up failed."; exit $LASTEXITCODE }
} else {
    docker-compose pull
    if ($LASTEXITCODE -ne 0) { Write-Error "docker-compose pull failed."; exit $LASTEXITCODE }
    docker-compose up -d
    if ($LASTEXITCODE -ne 0) { Write-Error "docker-compose up failed."; exit $LASTEXITCODE }
}

Write-Host "[n8n] Started: http://localhost:5678" -ForegroundColor Green
Write-Host "[n8n] If .env was created, save the credentials printed above." -ForegroundColor Yellow



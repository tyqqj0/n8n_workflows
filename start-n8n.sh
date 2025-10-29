#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

echo -e "[n8n] Checking Docker environment..."

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[n8n][ERROR] Command not found: $1" >&2
    exit 1
  fi
}

trap 'echo "[n8n][ERROR] Failed at line $LINENO" >&2' ERR

# Docker availability
require_cmd docker
if ! docker info >/dev/null 2>&1; then
  echo "[n8n][ERROR] Docker daemon is not running. Start Docker Desktop/Engine and retry." >&2
  exit 1
fi

# Compose command detection
COMPOSE=(docker compose)
if ! docker compose version >/dev/null 2>&1; then
  if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE=(docker-compose)
  else
    echo "[n8n][ERROR] Neither 'docker compose' nor 'docker-compose' is available." >&2
    exit 1
  fi
fi

# Ensure data volume exists
echo "[n8n] Preparing persistent volume n8n_data..."
if ! docker volume inspect n8n_data >/dev/null 2>&1; then
  docker volume create n8n_data >/dev/null
  echo "[n8n] Created volume n8n_data"
fi

generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    while true; do
      pw=$(openssl rand -base64 48 | tr -d '\n' | tr -cd 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789' | head -c 24 || true)
      [ "${#pw}" -eq 24 ] && echo "$pw" && return 0
    done
  else
    tr -cd 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789' </dev/urandom | head -c 24
  fi
}

generate_hex_key() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32 | tr '[:lower:]' '[:upper:]'
  elif command -v hexdump >/dev/null 2>&1; then
    hexdump -v -e '1/1 "%02X"' -n 32 /dev/urandom
  else
    # Fallback: use /dev/urandom with od
    od -An -tx1 -N32 /dev/urandom | tr -d ' \n' | tr '[:lower:]' '[:upper:]'
  fi
}

# Autogenerate .env if missing
env_created=false
if [ ! -f .env ]; then
  echo "[n8n] .env not found; generating..."
  BASIC_USER="admin"
  BASIC_PASSWORD="$(generate_password)"
  ENC_KEY="$(generate_hex_key)"
  cat > .env <<EOF
GENERIC_TIMEZONE=Asia/Shanghai
TZ=Asia/Shanghai
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_RUNNERS_ENABLED=true
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=${BASIC_USER}
N8N_BASIC_AUTH_PASSWORD=${BASIC_PASSWORD}
N8N_ENCRYPTION_KEY=${ENC_KEY}
N8N_HOST=localhost
N8N_PORT=5678
WEBHOOK_URL=http://localhost:5678/
EOF
  env_created=true
  echo "[n8n] .env generated"
  echo "[n8n] Login user: ${BASIC_USER}"
  echo "[n8n] Login password: ${BASIC_PASSWORD}"
fi

# Ensure compose.yml exists
if [ ! -f compose.yml ]; then
  echo "[n8n][ERROR] compose.yml not found. Ensure it is in the same directory as this script." >&2
  exit 1
fi

echo "[n8n] Pulling image and starting..."
"${COMPOSE[@]}" pull
"${COMPOSE[@]}" up -d

echo "[n8n] Started: http://localhost:5678"
if [ "$env_created" = true ]; then
  echo "[n8n] If .env was created, save the credentials printed above."
fi



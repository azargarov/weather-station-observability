#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ENV_FILE="$ROOT/.env"
PVE_SECRET_FILE="$ROOT/secrets/pve_token_value"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing .env. Run: make init"
  exit 1
fi

if [[ ! -f "$PVE_SECRET_FILE" ]]; then
  echo "Missing secrets/pve_token_value. Run: make init"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

export PVE_TOKEN_VALUE
PVE_TOKEN_VALUE="$(tr -d '\n' < "$PVE_SECRET_FILE")"

mkdir -p "$ROOT/generated/prometheus/targets"
mkdir -p "$ROOT/generated/prometheus/rules"

render() {
  local src="$1"
  local dst="$2"

  envsubst < "$ROOT/$src" > "$ROOT/$dst"
}

render "templates/prometheus/targets/proxmox.yml.tpl" \
       "generated/prometheus/targets/proxmox.yml"

render "templates/prometheus/targets/esp32.yml.tpl" \
       "generated/prometheus/targets/esp32.yml"

render "templates/prometheus/targets/pve.yml.tpl" \
       "generated/prometheus/targets/pve.yml"

render "templates/prometheus/pve.yml.tpl" \
       "generated/prometheus/pve.yml"

cp "$ROOT/prometheus/prometheus.yml" "$ROOT/generated/prometheus/prometheus.yml"
cp "$ROOT/prometheus/rules/"*.yml "$ROOT/generated/prometheus/rules/"

echo "Generated configs in ./generated"
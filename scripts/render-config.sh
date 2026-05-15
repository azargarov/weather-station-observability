#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ENV_FILE="$ROOT/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing .env. Run: make init"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

mkdir -p "$ROOT/generated/prometheus/targets"
mkdir -p "$ROOT/generated/prometheus/rules"

render() {
  local src="$1"
  local dst="$2"

  envsubst < "$ROOT/$src" > "$ROOT/$dst"
}

render "templates/prometheus/targets/esp32.yml.tpl" \
       "generated/prometheus/targets/esp32.yml"

cp "$ROOT/prometheus/prometheus.yml" "$ROOT/generated/prometheus/prometheus.yml"
cp "$ROOT/prometheus/rules/"*.yml "$ROOT/generated/prometheus/rules/"

echo "Generated configs in ./generated"
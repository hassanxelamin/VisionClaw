#!/usr/bin/env bash
set -euo pipefail

# Exposes the local SSM tunnel to LAN so the iPhone can reach OpenClaw via
# http://<MacLocalHostName>.local:<LAN_PORT>.

UPSTREAM_PORT="${UPSTREAM_PORT:-28789}"
LAN_PORT="${LAN_PORT:-18789}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[error] missing required command: $1" >&2
    exit 1
  }
}

need socat

HOSTNAME_LOCAL="$(scutil --get LocalHostName 2>/dev/null || true)"
if [[ -z "${HOSTNAME_LOCAL}" ]]; then
  HOSTNAME_LOCAL="YOUR-MAC"
fi

echo "[info] testing local upstream: http://127.0.0.1:${UPSTREAM_PORT}/health"
if command -v curl >/dev/null 2>&1; then
  if ! curl -fsS -m 3 "http://127.0.0.1:${UPSTREAM_PORT}/health" >/dev/null; then
    echo "[warn] upstream not healthy yet; keep this running and retry after tunnel is up"
  fi
fi

echo "[info] lan proxy: 0.0.0.0:${LAN_PORT} -> 127.0.0.1:${UPSTREAM_PORT}"
echo "[info] iPhone app host should be: http://${HOSTNAME_LOCAL}.local"
echo "[info] press Ctrl+C to stop LAN proxy"

exec socat "TCP-LISTEN:${LAN_PORT},reuseaddr,fork,bind=0.0.0.0" "TCP:127.0.0.1:${UPSTREAM_PORT}"

#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
INSTALL_DIR=/opt/owasp-guardrail-gateway
SERVICE_FILE=/etc/systemd/system/owasp-guardrail-gateway.service

install -d -m 0755 "${INSTALL_DIR}/config"
python3 -m venv "${INSTALL_DIR}/venv"
"${INSTALL_DIR}/venv/bin/pip" install --upgrade pip
"${INSTALL_DIR}/venv/bin/pip" install nemoguardrails fastapi uvicorn httpx
install -m 0644 "${SOURCE_DIR}/gateway.py" "${INSTALL_DIR}/gateway.py"
install -m 0644 "${SOURCE_DIR}/config/config.yml" "${INSTALL_DIR}/config/config.yml"
install -m 0644 "${SOURCE_DIR}/owasp-guardrail-gateway.service" "${SERVICE_FILE}"

systemctl daemon-reload
systemctl enable --now owasp-guardrail-gateway.service

for _ in {1..30}; do
  if curl -fsS http://127.0.0.1:11500/healthz | grep -q '"presidio_enabled":false'; then
    echo "NeMo gateway is ready on port 11500; Presidio is disabled."
    exit 0
  fi
  sleep 2
done

systemctl status owasp-guardrail-gateway.service --no-pager >&2 || true
exit 1

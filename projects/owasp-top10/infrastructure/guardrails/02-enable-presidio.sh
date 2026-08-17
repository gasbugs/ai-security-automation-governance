#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

INSTALL_DIR=/opt/owasp-guardrail-gateway
SERVICE_FILE=/etc/systemd/system/owasp-guardrail-gateway.service

if ! curl -fsS http://127.0.0.1:11500/healthz | grep -q '"presidio_enabled":false'; then
  echo "Stage 1 is not ready: verify the NeMo-only gateway first." >&2
  exit 1
fi

"${INSTALL_DIR}/venv/bin/pip" install presidio-analyzer presidio-anonymizer
"${INSTALL_DIR}/venv/bin/python" -m spacy download en_core_web_lg
sed -i.bak 's/Environment=PRESIDIO_ENABLED=false/Environment=PRESIDIO_ENABLED=true/' "${SERVICE_FILE}"
systemctl daemon-reload
systemctl restart owasp-guardrail-gateway.service

for _ in {1..30}; do
  if curl -fsS http://127.0.0.1:11500/healthz | grep -q '"presidio_enabled":true'; then
    echo "Presidio is enabled in front of and behind NeMo."
    exit 0
  fi
  sleep 2
done

systemctl status owasp-guardrail-gateway.service --no-pager >&2 || true
exit 1

#!/usr/bin/env bash
set -euo pipefail

# ====== Config: edit these before first run ======
APP_NAME="llm-router"
APP_USER="${APP_USER:-$USER}"
APP_GROUP="${APP_GROUP:-$USER}"
APP_DIR="${APP_DIR:-/opt/llm_router}"
BIND_HOST="${BIND_HOST:-127.0.0.1}"
BIND_PORT="${BIND_PORT:-8000}"
WORKERS="${WORKERS:-2}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
DOMAIN="${DOMAIN:-your.domain.com}"

SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
NGINX_CONF_FILE="/etc/nginx/conf.d/${APP_NAME}.conf"

echo "[1/8] Install base packages..."
sudo dnf install -y "${PYTHON_BIN}" python3-pip nginx rsync
# CentOS/RHEL package names differ by repo/version. Try common venv providers.
sudo dnf install -y python3-venv || \
sudo dnf install -y python3-virtualenv || \
sudo dnf install -y python36-virtualenv || true

echo "[2/8] Create app directory..."
sudo mkdir -p "${APP_DIR}"
sudo chown -R "${APP_USER}:${APP_GROUP}" "${APP_DIR}"

echo "[3/8] Sync project files to app directory..."
rsync -av --delete --exclude ".git" --exclude ".venv" ./ "${APP_DIR}/"

echo "[4/8] Create virtualenv and install dependencies..."
if "${PYTHON_BIN}" -m venv "${APP_DIR}/.venv"; then
  echo "Created venv via ${PYTHON_BIN} -m venv"
elif command -v virtualenv >/dev/null 2>&1; then
  virtualenv -p "$(command -v "${PYTHON_BIN}")" "${APP_DIR}/.venv"
  echo "Created venv via virtualenv"
elif "${PYTHON_BIN}" -m virtualenv "${APP_DIR}/.venv"; then
  echo "Created venv via ${PYTHON_BIN} -m virtualenv"
else
  echo "ERROR: cannot create virtual environment."
  echo "Install one of: python3-venv / python3-virtualenv / python36-virtualenv"
  exit 1
fi
"${APP_DIR}/.venv/bin/pip" install --upgrade pip
"${APP_DIR}/.venv/bin/pip" install -r "${APP_DIR}/requirements.txt"

echo "[5/8] Write systemd service..."
sudo tee "${SERVICE_FILE}" >/dev/null <<EOF
[Unit]
Description=FastAPI ${APP_NAME} service
After=network.target

[Service]
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${APP_DIR}
Environment="PATH=${APP_DIR}/.venv/bin"
ExecStart=${APP_DIR}/.venv/bin/gunicorn main:app -k uvicorn.workers.UvicornWorker -w ${WORKERS} -b ${BIND_HOST}:${BIND_PORT} --access-logfile - --error-logfile -
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "[6/8] Write nginx config..."
sudo tee "${NGINX_CONF_FILE}" >/dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://${BIND_HOST}:${BIND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 60s;
    }
}
EOF

echo "[7/8] Start service and nginx..."
sudo systemctl daemon-reload
sudo systemctl enable --now "${APP_NAME}"
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl restart nginx

echo "[8/8] Firewall and SELinux setup..."
sudo firewall-cmd --permanent --add-service=http || true
sudo firewall-cmd --permanent --add-service=https || true
sudo firewall-cmd --reload || true
sudo setsebool -P httpd_can_network_connect 1 || true

echo
echo "Done."
echo "Service status: sudo systemctl status ${APP_NAME}"
echo "Service logs:   journalctl -u ${APP_NAME} -f"
echo "Health check:   curl http://${BIND_HOST}:${BIND_PORT}/"

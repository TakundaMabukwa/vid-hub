#!/usr/bin/env bash
set -euo pipefail

APP_NAME="video-video-worker"
APP_DIR="/opt/vid-hub"
REPO_URL="https://github.com/TakundaMabukwa/vid-hub.git"
BRANCH="main"
API_PORT_DEFAULT="3200"

export DEBIAN_FRONTEND=noninteractive

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root or with sudo."
  exit 1
fi

echo "[1/9] Installing base packages..."
apt-get update -y
apt-get install -y curl git build-essential nginx ffmpeg ca-certificates

echo "[2/9] Installing Node.js 20..."
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

echo "[3/9] Installing PM2..."
npm install -g pm2

mkdir -p /opt
if [[ ! -d "${APP_DIR}/.git" ]]; then
  echo "[4/9] Cloning vid-hub..."
  git clone --branch "${BRANCH}" "${REPO_URL}" "${APP_DIR}"
else
  echo "[4/9] Updating existing vid-hub checkout..."
  git -C "${APP_DIR}" fetch origin
  git -C "${APP_DIR}" checkout "${BRANCH}"
  git -C "${APP_DIR}" pull --ff-only origin "${BRANCH}"
fi

cd "${APP_DIR}"

if [[ ! -f .env ]]; then
  echo "[5/9] Creating .env from template..."
  cp .env.example .env
fi

python3 - <<'PY'
from pathlib import Path
p = Path('.env')
text = p.read_text()
replacements = {
    'API_PORT=3200': 'API_PORT=3200',
    'SERVER_IP=VIDEO_SERVER_IP': 'SERVER_IP=__VIDEO_SERVER_IP__',
    'INTERNAL_WORKER_TOKEN=replace_me': 'INTERNAL_WORKER_TOKEN=__SET_ME__',
    'CORS_ORIGIN=*': 'CORS_ORIGIN=*',
}
for old, new in replacements.items():
    text = text.replace(old, new)
p.write_text(text)
PY

echo "[6/9] Installing app dependencies..."
npm install

echo "[7/9] Building app..."
npm run build

mkdir -p logs media hls recordings

echo "[8/9] Starting PM2 process..."
pm2 delete "${APP_NAME}" >/dev/null 2>&1 || true
pm2 start ecosystem.config.js --update-env
pm2 save
pm2 startup systemd -u root --hp /root >/tmp/pm2-startup.txt || true
bash /tmp/pm2-startup.txt 2>/dev/null || true

echo "[9/9] Nginx note"
echo "Point your public reverse proxy to http://127.0.0.1:${API_PORT_DEFAULT}"
echo "Remember to edit ${APP_DIR}/.env and set:"
echo "  SERVER_IP=<public-ip>"
echo "  INTERNAL_WORKER_TOKEN=<shared-secret>"
echo ""
echo "Done. Check:"
echo "  pm2 status"
echo "  pm2 logs ${APP_NAME} --lines 100"
echo "  curl http://127.0.0.1:${API_PORT_DEFAULT}/health"

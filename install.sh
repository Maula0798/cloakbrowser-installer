#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# CloakBrowser Manager Installer
# Ubuntu 24.04 / Docker / Online :8080 / Manual PIA upload
# ============================================================

REPO_URL="https://github.com/CloakHQ/CloakBrowser-Manager.git"
APP_DIR="/opt/CloakBrowser-Manager"
PIA_DIR="$APP_DIR/extensions/pia"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
fail() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

[[ $EUID -eq 0 ]] || fail "Jalankan sebagai root."

echo
echo "============================================================"
echo "        CLOAKBROWSER MANAGER INSTALLER"
echo "============================================================"
echo

# ------------------------------------------------------------
# 1. Base packages
# ------------------------------------------------------------
info "Update Ubuntu dan install kebutuhan dasar..."
apt update
apt install -y ca-certificates curl gnupg git
ok "Paket dasar siap."

# ------------------------------------------------------------
# 2. Docker
# ------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
    info "Docker belum ada. Memasang Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io \
      docker-buildx-plugin docker-compose-plugin
else
    ok "Docker sudah terpasang: $(docker --version)"
fi

systemctl enable --now docker

docker --version
docker compose version

# ------------------------------------------------------------
# 3. Clone/update CloakBrowser Manager
# ------------------------------------------------------------
if [[ -d "$APP_DIR/.git" ]]; then
    info "CloakBrowser Manager sudah ada. Update repository..."
    cd "$APP_DIR"
    git pull --ff-only
else
    info "Clone CloakBrowser Manager..."
    mkdir -p /opt
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
fi

mkdir -p "$PIA_DIR"
ok "Folder PIA siap: $PIA_DIR"

# ------------------------------------------------------------
# 4. Build/start BEFORE PIA
# ------------------------------------------------------------
info "Build dan jalankan CloakBrowser Manager..."
docker compose up -d --build
sleep 3

if ! docker compose ps --status running | grep -q manager; then
    docker compose ps
    docker compose logs --tail=100
    fail "Container Manager tidak berjalan."
fi

ok "CloakBrowser Manager berjalan."

# ------------------------------------------------------------
# 5. ONLINE :8080
# ------------------------------------------------------------
if grep -q '127\.0\.0\.1:8080:8080' "$COMPOSE_FILE"; then
    info "Mengubah port 8080 agar dapat diakses dari luar..."
    cp "$COMPOSE_FILE" "$COMPOSE_FILE.bak"
    sed -i 's/127\.0\.0\.1:8080:8080/0.0.0.0:8080:8080/g' "$COMPOSE_FILE"
    docker compose up -d
fi

# ------------------------------------------------------------
# 6. PAUSE FOR MANUAL PIA UPLOAD
# ------------------------------------------------------------
echo
echo "============================================================"
echo "                 UPLOAD PIA VPN"
echo "============================================================"
echo
echo "CloakBrowser sudah terpasang."
echo
echo "Silakan upload FOLDER PIA milik Anda ke:"
echo
echo "  $PIA_DIR"
echo
echo "Contoh:"
echo "  $PIA_DIR/manifest.json"
echo "  $PIA_DIR/..."
echo
echo "Gunakan WinSCP/SFTP untuk upload folder/file PIA."
echo
echo "JANGAN memasukkan password/token PIA ke repository GitHub."
echo

while true; do
    read -r -p "Ketik YES setelah upload PIA selesai: " ANSWER
    if [[ "$ANSWER" == "YES" ]]; then
        break
    fi
    echo "Belum lanjut. Ketik YES jika upload sudah selesai."
done

# ------------------------------------------------------------
# 7. Validate PIA
# ------------------------------------------------------------
if [[ ! -f "$PIA_DIR/manifest.json" ]]; then
    echo
    echo "manifest.json belum ditemukan di:"
    echo "  $PIA_DIR"
    echo
    read -r -p "Upload PIA sekarang lalu tekan ENTER untuk cek lagi..." _
fi

[[ -f "$PIA_DIR/manifest.json" ]] || fail \
  "manifest.json tidak ditemukan. Upload PIA ke $PIA_DIR lalu jalankan installer lagi."

ok "manifest.json ditemukan."

# ------------------------------------------------------------
# 8. Show extension info
# ------------------------------------------------------------
echo
info "Informasi manifest:"
grep -E '"manifest_version"|"name"|"version"' \
  "$PIA_DIR/manifest.json" | head -10 || true

# ------------------------------------------------------------
# 9. Inspect current Docker mount
# ------------------------------------------------------------
echo
info "Mount Docker saat ini:"
docker inspect cloakbrowser-manager-manager-1 \
  --format '{{json .Mounts}}' 2>/dev/null || true

# ------------------------------------------------------------
# 10. Final status
# ------------------------------------------------------------
echo
docker compose ps

echo
echo "============================================================"
echo "                    INSTALASI SELESAI"
echo "============================================================"
echo
echo "Manager:"
echo "  http://IP_SERVER:8080"
echo
echo "PIA:"
echo "  $PIA_DIR"
echo
echo "CATATAN:"
echo "Folder PIA sudah divalidasi. Pemuatan extension ke profile"
echo "harus menggunakan launch_args yang didukung Manager, misalnya:"
echo
echo "  --load-extension=/data/ext/pia"
echo
echo "Jangan memasukkan extension PIA ke GitHub jika tidak punya"
echo "hak redistribusi. Upload PIA secara manual seperti di atas."
echo
echo "Cek status:"
echo "  cd $APP_DIR && docker compose ps"
echo

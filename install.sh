#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# CLOAKBROWSER MANAGER INSTALLER
# Ubuntu 24.04
# Docker + CloakBrowser + Online :8080
# Pause untuk upload PIA
# ============================================================

REPO_URL="https://github.com/CloakHQ/CloakBrowser-Manager.git"
APP_DIR="/opt/CloakBrowser-Manager"
PIA_DIR="$APP_DIR/extensions/pia"
DATA_DIR="/root/.cloakbrowser-manager"
PIA_DATA_DIR="$DATA_DIR/ext/pia"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

trap 'echo ""; echo "[ERROR] Installer berhenti pada baris $LINENO"; exit 1' ERR

log() {
    echo ""
    echo "============================================================"
    echo " $1"
    echo "============================================================"
    echo ""
}

ok() {
    echo "[OK] $1"
}

info() {
    echo "[INFO] $1"
}

fail() {
    echo "[ERROR] $1"
    exit 1
}

# ============================================================
# START
# ============================================================

clear

echo "============================================================"
echo "        CLOAKBROWSER MANAGER INSTALLER"
echo "============================================================"
echo ""
echo "Ubuntu 24.04"
echo "Docker"
echo "CloakBrowser Manager"
echo "PIA VPN Extension"
echo ""
echo "Installer akan menampilkan proses secara realtime."
echo ""

if [[ "$EUID" -ne 0 ]]; then
    fail "Jalankan sebagai root."
fi

sleep 2

# ============================================================
# 1. UBUNTU
# ============================================================

log "1/10 - UPDATE UBUNTU"

echo "[1/4] apt update..."
apt update

echo ""
echo "[2/4] apt upgrade..."
DEBIAN_FRONTEND=noninteractive apt upgrade -y

echo ""
echo "[3/4] Install ca-certificates..."
apt install -y ca-certificates

echo ""
echo "[4/4] Install curl, gnupg, git..."
apt install -y curl gnupg git

ok "Ubuntu siap."

# ============================================================
# 2. DOCKER
# ============================================================

log "2/10 - CEK DOCKER"

if command -v docker >/dev/null 2>&1; then

    ok "Docker sudah terpasang."
    docker --version

else

    info "Docker belum terpasang."
    info "Memasang Docker..."

    install -m 0755 -d /etc/apt/keyrings

    echo "[1/5] Download Docker GPG key..."

    curl -fsSL \
        https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    echo "[2/5] Tambahkan repository Docker..."

    echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list

    echo "[3/5] apt update..."
    apt update

    echo "[4/5] Install Docker..."
    apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    echo "[5/5] Aktifkan Docker..."
    systemctl enable --now docker

    ok "Docker berhasil dipasang."

fi

echo ""
docker --version
docker compose version

# ============================================================
# 3. DOCKER SERVICE
# ============================================================

log "3/10 - AKTIFKAN DOCKER"

systemctl enable --now docker

if systemctl is-active --quiet docker; then
    ok "Docker service ACTIVE."
else
    fail "Docker service tidak aktif."
fi

# ============================================================
# 4. CLOAKBROWSER SOURCE
# ============================================================

log "4/10 - CLOAKBROWSER MANAGER"

if [[ -d "$APP_DIR/.git" ]]; then

    info "Repository CloakBrowser sudah ada."

    cd "$APP_DIR"

    echo "[1/2] Git status..."
    git status --short

    echo ""
    echo "[2/2] Update repository..."

    git pull --ff-only

else

    info "Download CloakBrowser Manager..."

    mkdir -p /opt

    git clone "$REPO_URL" "$APP_DIR"

    cd "$APP_DIR"

fi

ok "Source CloakBrowser siap."

# ============================================================
# 5. FOLDER PIA
# ============================================================

log "5/10 - SIAPKAN FOLDER PIA"

mkdir -p "$PIA_DIR"
mkdir -p "$PIA_DATA_DIR"

echo "Folder upload:"
echo ""
echo "$PIA_DIR"
echo ""

ok "Folder PIA siap."

# ============================================================
# 6. BUILD
# ============================================================

log "6/10 - BUILD CLOAKBROWSER"

cd "$APP_DIR"

echo "[INFO] Docker Compose build dimulai."
echo "[INFO] Proses akan terlihat di bawah."
echo ""

docker compose build

ok "Build selesai."

# ============================================================
# 7. START
# ============================================================

log "7/10 - START CLOAKBROWSER"

docker compose up -d

sleep 5

docker compose ps

if docker compose ps --status running | grep -q manager; then

    ok "Container Manager RUNNING."

else

    echo ""
    echo "Container tidak berjalan."
    echo ""
    docker compose ps
    echo ""
    docker compose logs --tail=100

    fail "CloakBrowser Manager gagal start."

fi

# ============================================================
# 8. ONLINE PORT 8080
# ============================================================

log "8/10 - BUKA PORT 8080"

if grep -q '127\.0\.0\.1:8080:8080' "$COMPOSE_FILE"; then

    info "Port masih localhost."

    cp "$COMPOSE_FILE" "$COMPOSE_FILE.bak"

    sed -i \
        's/127\.0\.0\.1:8080:8080/0.0.0.0:8080:8080/g' \
        "$COMPOSE_FILE"

    echo "[INFO] Recreate container..."

    docker compose up -d

else

    ok "Port 8080 sudah terbuka."

fi

sleep 3

docker compose ps

echo ""

if curl -fsS http://127.0.0.1:8080 >/dev/null 2>&1; then
    ok "HTTP 8080 ONLINE."
else
    info "HTTP belum memberikan response."
fi

# ============================================================
# 9. PAUSE PIA
# ============================================================

log "9/10 - UPLOAD PIA VPN"

echo "CloakBrowser sudah online."
echo ""
echo "Sekarang installer BERHENTI sementara."
echo ""
echo "Silakan upload folder PIA Anda ke:"
echo ""
echo "  $PIA_DIR"
echo ""
echo "Gunakan WinSCP / SFTP."
echo ""
echo "Pastikan hasil akhirnya:"
echo ""
echo "  $PIA_DIR/manifest.json"
echo ""
echo "============================================================"
echo ""
echo "Setelah selesai upload, kembali ke SSH."
echo ""

while true; do

    read -r -p "Ketik YES untuk melanjutkan: " ANSWER

    if [[ "$ANSWER" == "YES" ]]; then
        break
    fi

    echo ""
    echo "[INFO] Jawaban harus YES."
    echo ""

done

# ============================================================
# 10. VALIDASI DAN SELESAI
# ============================================================

log "10/10 - CEK PIA"

if [[ ! -f "$PIA_DIR/manifest.json" ]]; then

    echo ""
    echo "[ERROR] manifest.json tidak ditemukan."
    echo ""
    echo "Folder yang dicek:"
    echo "$PIA_DIR"
    echo ""

    ls -la "$PIA_DIR"

    fail "Upload PIA belum benar."

fi

ok "manifest.json ditemukan."

echo ""
echo "Informasi extension:"
echo ""

grep -E \
    '"manifest_version"|"name"|"version"' \
    "$PIA_DIR/manifest.json" \
    | head -10 || true

# Copy ke persistent Docker data
echo ""
info "Copy PIA ke persistent Docker data..."

rm -rf "$PIA_DATA_DIR"
mkdir -p "$PIA_DATA_DIR"

cp -a "$PIA_DIR/." "$PIA_DATA_DIR/"

ok "PIA sudah disiapkan."

# Cek container
CONTAINER_NAME="cloakbrowser-manager-manager-1"

echo ""
info "Cek PIA dari dalam container..."

if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then

    if docker exec "$CONTAINER_NAME" \
        test -f /data/ext/pia/manifest.json; then

        ok "PIA TERBACA DI CONTAINER."

    else

        echo ""
        echo "[WARNING] PIA belum terlihat di /data/ext/pia."
        echo ""

    fi

fi

# ============================================================
# FINAL
# ============================================================

echo ""
echo "============================================================"
echo "              INSTALLASI SELESAI"
echo "============================================================"
echo ""

docker compose ps

echo ""
echo "CloakBrowser Manager:"
echo ""
echo "  http://IP_SERVER:8080"
echo ""

echo "PIA Host:"
echo ""
echo "  $PIA_DATA_DIR"
echo ""

echo "PIA Container:"
echo ""
echo "  /data/ext/pia"
echo ""

echo "Extension argument:"
echo ""
echo "  --load-extension=/data/ext/pia"
echo ""

echo "============================================================"
echo "                    SELESAI"
echo "============================================================"
echo ""

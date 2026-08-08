```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# CLOAKBROWSER MANAGER INSTALLER
# Ubuntu 24.04
# Docker + CloakBrowser Manager + Online :8080
# Manual PIA VPN Upload
# ============================================================

REPO_URL="https://github.com/CloakHQ/CloakBrowser-Manager.git"

APP_DIR="/opt/CloakBrowser-Manager"
PIA_DIR="$APP_DIR/extensions/pia"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

CONTAINER_NAME="cloakbrowser-manager-manager-1"

# ============================================================
# FUNCTIONS
# ============================================================

log() {
    echo
    echo "============================================================"
    echo " $1"
    echo "============================================================"
    echo
}

info() {
    echo "[INFO] $1"
}

ok() {
    echo "[OK] $1"
}

warn() {
    echo "[WARNING] $1"
}

fail() {
    echo
    echo "[ERROR] $1"
    echo
    exit 1
}

trap 'echo ""; echo "[ERROR] Installer berhenti pada baris $LINENO"; exit 1' ERR

# ============================================================
# ROOT
# ============================================================

if [[ "$EUID" -ne 0 ]]; then
    fail "Jalankan installer sebagai root."
fi

echo
echo "============================================================"
echo "        CLOAKBROWSER MANAGER INSTALLER"
echo "============================================================"
echo
echo "Ubuntu 24.04"
echo "Docker"
echo "CloakBrowser Manager"
echo "PIA VPN Extension"
echo
echo "Semua proses akan ditampilkan di terminal."
echo

sleep 2

# ============================================================
# 1. UBUNTU
# ============================================================

log "1/10 - UPDATE UBUNTU"

echo "[1/4] apt update..."
apt update

echo
echo "[2/4] apt upgrade..."
DEBIAN_FRONTEND=noninteractive apt upgrade -y

echo
echo "[3/4] Install ca-certificates..."
apt install -y ca-certificates

echo
echo "[4/4] Install curl, gnupg, git..."
apt install -y curl gnupg git

ok "Ubuntu siap."

# ============================================================
# 2. DOCKER
# ============================================================

log "2/10 - INSTALL / CEK DOCKER"

if command -v docker >/dev/null 2>&1; then

    ok "Docker sudah terpasang."

else

    info "Docker belum terpasang."
    info "Memasang Docker..."

    install -m 0755 -d /etc/apt/keyrings

    echo "[1/5] Download Docker GPG key..."

    curl -fsSL \
        https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    echo
    echo "[2/5] Tambahkan repository Docker..."

    echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list

    echo
    echo "[3/5] apt update..."

    apt update

    echo
    echo "[4/5] Install Docker..."

    apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    echo
    echo "[5/5] Aktifkan Docker..."

    systemctl enable --now docker

    ok "Docker berhasil dipasang."

fi

echo
docker --version

echo
docker compose version

# ============================================================
# 3. DOCKER SERVICE
# ============================================================

log "3/10 - DOCKER SERVICE"

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

    git status --short || true

    echo
    echo "[2/2] Update repository..."

    git pull --ff-only

else

    info "Download CloakBrowser Manager..."

    mkdir -p /opt

    git clone "$REPO_URL" "$APP_DIR"

fi

cd "$APP_DIR"

ok "Source CloakBrowser siap."

# ============================================================
# 5. FOLDER PIA
# ============================================================

log "5/10 - SIAPKAN FOLDER PIA"

mkdir -p "$PIA_DIR"

echo "Folder PIA:"
echo
echo "  $PIA_DIR"
echo

ok "Folder PIA siap."

# ============================================================
# 6. DOCKER COMPOSE PIA MOUNT
# ============================================================

log "6/10 - KONFIGURASI PIA CONTAINER"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    fail "docker-compose.yml tidak ditemukan."
fi

cp "$COMPOSE_FILE" "$COMPOSE_FILE.backup"

info "Memastikan PIA di-mount ke container..."

python3 - "$COMPOSE_FILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

pia_mount = "      - /opt/CloakBrowser-Manager/extensions/pia:/data/extensions/pia:ro"

# Hapus mapping lama PIA jika pernah dibuat
lines = text.splitlines()
lines = [
    line for line in lines
    if "/opt/CloakBrowser-Manager/extensions/pia:" not in line
]

text = "\n".join(lines) + "\n"

# Cari volume /data yang sudah ada
candidates = [
    "      - /root/.cloakbrowser-manager:/data",
    "      - type: bind",
]

needle = "      - /root/.cloakbrowser-manager:/data"

if needle in text:
    text = text.replace(
        needle,
        needle + "\n" + pia_mount,
        1
    )
else:
    # Coba format long-volume yang dihasilkan Compose
    marker = "    volumes:\n"

    if marker in text and pia_mount not in text:
        text = text.replace(
            marker,
            marker + pia_mount + "\n",
            1
        )
    else:
        raise SystemExit(
            "Tidak menemukan bagian volumes yang sesuai."
        )

path.write_text(text)
PY

echo
info "Cek konfigurasi Docker Compose..."

docker compose config >/tmp/cloakbrowser-compose-check.yml

ok "Mount PIA berhasil dikonfigurasi."

echo
echo "Host:"
echo "  $PIA_DIR"

echo
echo "Container:"
echo "  /data/extensions/pia"

# ============================================================
# 7. BUILD
# ============================================================

log "7/10 - BUILD CLOAKBROWSER"

echo "[INFO] Docker Compose build dimulai."
echo "[INFO] Log build akan terlihat di bawah."
echo

docker compose build

ok "Build selesai."

# ============================================================
# 8. START + ONLINE
# ============================================================

log "8/10 - START CLOAKBROWSER + PORT 8080"

docker compose up -d

sleep 5

docker compose ps

echo

if docker compose ps --status running | grep -q manager; then

    ok "Container Manager RUNNING."

else

    docker compose ps
    echo
    docker compose logs --tail=100

    fail "Container Manager gagal berjalan."

fi

# ------------------------------------------------------------
# PORT 8080
# ------------------------------------------------------------

if grep -q '127\.0\.0\.1:8080:8080' "$COMPOSE_FILE"; then

    info "Port masih localhost."

    cp "$COMPOSE_FILE" "$COMPOSE_FILE.port-backup"

    sed -i \
        's/127\.0\.0\.1:8080:8080/0.0.0.0:8080:8080/g' \
        "$COMPOSE_FILE"

    info "Port diubah menjadi 0.0.0.0:8080."

    docker compose up -d

    sleep 3

else

    ok "Port 8080 sudah dikonfigurasi."

fi

echo

docker compose ps

echo

if curl -fsS http://127.0.0.1:8080 >/dev/null 2>&1; then

    ok "HTTP 8080 ONLINE."

else

    warn "HTTP 8080 belum memberikan response."

fi

# ============================================================
# 9. PAUSE UPLOAD PIA
# ============================================================

log "9/10 - UPLOAD PIA VPN"

echo "CloakBrowser sudah terpasang."

echo
echo "Sekarang installer BERHENTI sementara."
echo

echo "Silakan upload folder PIA milik Anda ke:"
echo
echo "  $PIA_DIR"
echo

echo "Gunakan WinSCP / SFTP."

echo
echo "Hasil akhirnya harus seperti:"
echo
echo "  $PIA_DIR/manifest.json"
echo

echo "JANGAN upload PIA ke GitHub jika lisensinya"
echo "tidak mengizinkan redistribusi."

echo
echo "============================================================"
echo

while true; do

    read -r -p "Ketik YES setelah upload PIA selesai: " ANSWER

    if [[ "$ANSWER" == "YES" ]]; then
        break
    fi

    echo
    echo "[INFO] Jawaban harus YES."
    echo

done

# ============================================================
# 10. VALIDASI PIA + RESTART
# ============================================================

log "10/10 - VALIDASI PIA"

echo "[1/5] Cek manifest.json..."

if [[ ! -f "$PIA_DIR/manifest.json" ]]; then

    echo
    echo "[ERROR] manifest.json tidak ditemukan."
    echo
    echo "Folder:"
    echo "$PIA_DIR"
    echo
    echo "Isi folder:"
    ls -la "$PIA_DIR"
    echo

    fail "Upload PIA belum benar."

fi

ok "manifest.json ditemukan."

# ------------------------------------------------------------
# MANIFEST INFO
# ------------------------------------------------------------

echo
echo "[2/5] Informasi extension:"
echo

grep -E \
    '"manifest_version"|"name"|"version"' \
    "$PIA_DIR/manifest.json" \
    | head -10 || true

# ------------------------------------------------------------
# COMPOSE CHECK
# ------------------------------------------------------------

echo
echo "[3/5] Cek Docker Compose..."

docker compose config >/tmp/cloakbrowser-compose-final.yml

ok "Docker Compose valid."

# ------------------------------------------------------------
# RECREATE
# ------------------------------------------------------------

echo
echo "[4/5] Recreate container..."

docker compose up -d --force-recreate

sleep 5

ok "Container sudah direcreate."

# ------------------------------------------------------------
# CONTAINER CHECK
# ------------------------------------------------------------

echo
echo "[5/5] Cek PIA dari dalam container..."

if docker exec "$CONTAINER_NAME" \
    test -f /data/extensions/pia/manifest.json; then

    ok "PIA TERBACA DI CONTAINER."

else

    echo
    echo "[ERROR] PIA tidak terbaca di container."
    echo
    echo "Mount yang digunakan:"
    echo
    echo "  $PIA_DIR"
    echo "       ↓"
    echo "  /data/extensions/pia"
    echo

    docker compose config

    exit 1

fi

# ============================================================
# FINAL
# ============================================================

echo
echo "============================================================"
echo "              INSTALLASI SELESAI"
echo "============================================================"
echo

docker compose ps

echo
echo "CloakBrowser Manager:"
echo
echo "  http://IP_SERVER:8080"
echo

echo "PIA Host:"
echo
echo "  $PIA_DIR"
echo

echo "PIA Container:"
echo
echo "  /data/extensions/pia"
echo

echo "Chromium launch args:"
echo
echo "  --disable-extensions-except=/data/extensions/pia"
echo "  --load-extension=/data/extensions/pia"
echo "  --no-sandbox"
echo

echo "============================================================"
echo "                    SELESAI"
echo "============================================================"
echo
```

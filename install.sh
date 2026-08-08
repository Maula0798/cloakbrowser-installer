```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# CLOAKBROWSER MANAGER INSTALLER
# Ubuntu 24.04 / Docker / Online :8080 / Manual PIA Upload
# ============================================================

REPO_URL="https://github.com/CloakHQ/CloakBrowser-Manager.git"
APP_DIR="/opt/CloakBrowser-Manager"
PIA_UPLOAD_DIR="$APP_DIR/extensions/pia"
DATA_DIR="/root/.cloakbrowser-manager"
PIA_DATA_DIR="$DATA_DIR/ext/pia"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

fail() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# ============================================================
# ROOT CHECK
# ============================================================

[[ $EUID -eq 0 ]] || fail "Jalankan installer sebagai root."

echo
echo "============================================================"
echo "          CLOAKBROWSER MANAGER INSTALLER"
echo "============================================================"
echo

# ============================================================
# 1. UPDATE UBUNTU
# ============================================================

info "Update Ubuntu..."

apt update
apt upgrade -y

apt install -y \
    ca-certificates \
    curl \
    gnupg \
    git

ok "Paket dasar siap."

# ============================================================
# 2. INSTALL DOCKER
# ============================================================

if ! command -v docker >/dev/null 2>&1; then

    info "Docker belum terpasang."

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL \
        https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list

    apt update

    apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

else

    ok "Docker sudah terpasang."

fi

systemctl enable --now docker

echo
docker --version
docker compose version
echo

# ============================================================
# 3. CLOAKBROWSER MANAGER
# ============================================================

if [[ -d "$APP_DIR/.git" ]]; then

    info "CloakBrowser Manager sudah ada."

    cd "$APP_DIR"

    git pull --ff-only

else

    info "Download CloakBrowser Manager..."

    mkdir -p /opt

    git clone "$REPO_URL" "$APP_DIR"

    cd "$APP_DIR"

fi

ok "CloakBrowser Manager siap."

# ============================================================
# 4. BUAT FOLDER PIA
# ============================================================

mkdir -p "$PIA_UPLOAD_DIR"

mkdir -p "$PIA_DATA_DIR"

ok "Folder PIA siap."

echo
echo "Folder upload PIA:"
echo
echo "  $PIA_UPLOAD_DIR"
echo

# ============================================================
# 5. BUILD CLOAKBROWSER
# ============================================================

info "Build CloakBrowser Manager..."

cd "$APP_DIR"

docker compose up -d --build

sleep 5

if ! docker compose ps --status running | grep -q manager; then

    docker compose ps

    docker compose logs --tail=100

    fail "CloakBrowser Manager gagal berjalan."

fi

ok "CloakBrowser Manager berjalan."

# ============================================================
# 6. ONLINE PORT 8080
# ============================================================

if grep -q '127\.0\.0\.1:8080:8080' "$COMPOSE_FILE"; then

    info "Membuka port 8080..."

    cp "$COMPOSE_FILE" "$COMPOSE_FILE.bak"

    sed -i \
        's/127\.0\.0\.1:8080:8080/0.0.0.0:8080:8080/g' \
        "$COMPOSE_FILE"

    docker compose up -d

fi

ok "CloakBrowser tersedia di port 8080."

# ============================================================
# 7. TEST LOCAL
# ============================================================

if curl -fsS http://127.0.0.1:8080 >/dev/null 2>&1; then
    ok "Web Manager merespons di port 8080."
else
    info "Web Manager belum memberikan response HTTP."
fi

# ============================================================
# 8. PAUSE - UPLOAD PIA
# ============================================================

echo
echo "============================================================"
echo "                    UPLOAD PIA VPN"
echo "============================================================"
echo
echo "CloakBrowser sudah terpasang dan online."
echo
echo "Silakan upload folder PIA milik Anda ke:"
echo
echo "  $PIA_UPLOAD_DIR"
echo
echo "Gunakan WinSCP / SFTP."
echo
echo "Contoh:"
echo
echo "  $PIA_UPLOAD_DIR/manifest.json"
echo
echo "  $PIA_UPLOAD_DIR/..."
echo
echo "JANGAN upload PIA ke GitHub jika lisensinya tidak"
echo "mengizinkan redistribusi."
echo
echo "============================================================"
echo

while true; do

    read -r -p "Ketik YES setelah upload PIA selesai: " ANSWER

    if [[ "$ANSWER" == "YES" ]]; then
        break
    fi

    echo
    echo "Belum lanjut."
    echo "Upload PIA terlebih dahulu, kemudian ketik YES."
    echo

done

# ============================================================
# 9. VALIDASI MANIFEST
# ============================================================

echo

if [[ ! -f "$PIA_UPLOAD_DIR/manifest.json" ]]; then

    echo
    echo "============================================================"
    echo "manifest.json BELUM DITEMUKAN"
    echo "============================================================"
    echo
    echo "Pastikan folder PIA berada di:"
    echo
    echo "  $PIA_UPLOAD_DIR"
    echo

    fail "PIA belum lengkap."

fi

ok "manifest.json ditemukan."

# ============================================================
# 10. INFORMASI PIA
# ============================================================

echo
info "Informasi PIA:"

grep -E \
    '"manifest_version"|"name"|"version"' \
    "$PIA_UPLOAD_DIR/manifest.json" \
    | head -10 || true

# ============================================================
# 11. COPY PIA KE DATA DIRECTORY
# ============================================================

info "Menyiapkan PIA untuk CloakBrowser..."

rm -rf "$PIA_DATA_DIR"

mkdir -p "$PIA_DATA_DIR"

cp -a "$PIA_UPLOAD_DIR/." "$PIA_DATA_DIR/"

ok "PIA tersedia di:"
echo
echo "  Host      : $PIA_DATA_DIR"
echo "  Container : /data/ext/pia"
echo

# ============================================================
# 12. VALIDASI CONTAINER
# ============================================================

CONTAINER_NAME="cloakbrowser-manager-manager-1"

if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then

    info "Cek PIA dari dalam container..."

    if docker exec "$CONTAINER_NAME" \
        test -f /data/ext/pia/manifest.json; then

        ok "PIA terbaca dari dalam container."

    else

        fail "PIA belum terbaca dari dalam container."

    fi

else

    info "Nama container tidak ditemukan. Cek docker compose ps."

fi

# ============================================================
# 13. STATUS AKHIR
# ============================================================

echo
echo "============================================================"
echo "                 INSTALASI SELESAI"
echo "============================================================"
echo

docker compose ps

echo
echo "Manager:"
echo
echo "  http://IP_SERVER:8080"
echo

echo "PIA:"
echo
echo "  Host:"
echo "  $PIA_DATA_DIR"
echo
echo "  Container:"
echo "  /data/ext/pia"
echo

echo "Untuk profile Chromium, extension dapat dimuat menggunakan:"
echo
echo "  --load-extension=/data/ext/pia"
echo

echo "============================================================"
echo "                    SELESAI"
echo "============================================================"
echo
```

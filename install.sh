#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# CLOAKBROWSER MOD INSTALLER
# Ubuntu 24.04
# Docker + CloakBrowser MOD + Online :8080
# Manual PIA VPN Upload
# Create Initial Profiles
# ============================================================

REPO_URL="https://github.com/Maula0798/CloakBrowser-MOD.git"

APP_DIR="/opt/CloakBrowser-Manager"
PIA_DIR="$APP_DIR/extensions/pia"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
OVERRIDE_FILE="$APP_DIR/docker-compose.override.yml"

CONTAINER_NAME="cloakbrowser-manager-manager-1"
SERVICE_NAME="manager"

DEFAULT_PROFILE_COUNT=4

# ============================================================
# IMPORTANT:
# Installer dijalankan dengan:
#
# curl ... | bash
#
# Jadi semua input interaktif diarahkan ke terminal asli.
# ============================================================

if [ -t 0 ]; then
    :
else
    exec </dev/tty
fi

# ============================================================
# ERROR HANDLER
# ============================================================

trap '
printf "\n"
printf "%s\n" "============================================================"
printf "%s\n" "[ERROR] Installer berhenti pada baris $LINENO"
printf "%s\n" "============================================================"
printf "\n"
exit 1
' ERR

# ============================================================
# ROOT CHECK
# ============================================================

if [ "$EUID" -ne 0 ]; then
    printf "\n"
    printf '%s\n' '[ERROR] Jalankan sebagai root.'
    exit 1
fi

# ============================================================
# HEADER
# ============================================================

clear 2>/dev/null || true

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' '          CLOAKBROWSER MOD INSTALLER'
printf '%s\n' '============================================================'
printf "\n"

printf '%s\n' 'Ubuntu 24.04'
printf '%s\n' 'Docker'
printf '%s\n' 'CloakBrowser MOD'
printf '%s\n' 'PIA VPN Extension'
printf '%s\n' 'Initial Profiles'
printf "\n"

printf '%s\n' 'Installer akan menampilkan proses secara realtime.'
printf "\n"

sleep 2

# ============================================================
# 1/11 - UPDATE UBUNTU
# ============================================================

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' ' 1/11 - UPDATE UBUNTU'
printf '%s\n' '============================================================'
printf "\n"

printf '%s\n' '[1/4] apt update...'
apt update

printf "\n"
printf '%s\n' '[2/4] apt upgrade...'
DEBIAN_FRONTEND=noninteractive apt upgrade -y

printf "\n"
printf '%s\n' '[3/4] Install ca-certificates...'
apt install -y ca-certificates

printf "\n"
printf '%s\n' '[4/4] Install curl, gnupg, git, python3...'
apt install -y curl gnupg git python3

printf "\n"
printf '%s\n' '[OK] Ubuntu siap.'

# ============================================================
# 2/11 - DOCKER
# ============================================================

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' ' 2/11 - INSTALL / CEK DOCKER'
printf '%s\n' '============================================================'
printf "\n"

if command -v docker >/dev/null 2>&1; then

    printf '%s\n' '[OK] Docker sudah terpasang.'

else

    printf '%s\n' '[INFO] Docker belum terpasang.'
    printf '%s\n' '[INFO] Memasang Docker...'
    printf "\n"

    install -m 0755 -d /etc/apt/keyrings

    printf '%s\n' '[1/5] Download Docker GPG key...'

    curl -fsSL \
        https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    printf "\n"
    printf '%s\n' '[2/5] Tambahkan repository Docker...'

    printf '%s\n' \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list

    printf "\n"
    printf '%s\n' '[3/5] apt update...'

    apt update

    printf "\n"
    printf '%s\n' '[4/5] Install Docker...'

    apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    printf "\n"
    printf '%s\n' '[5/5] Aktifkan Docker...'

    systemctl enable --now docker

    printf "\n"
    printf '%s\n' '[OK] Docker berhasil dipasang.'

fi

printf "\n"
docker --version

printf "\n"
docker compose version

# ============================================================
# 3/11 - DOCKER SERVICE
# ============================================================

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' ' 3/11 - DOCKER SERVICE'
printf '%s\n' '============================================================'
printf "\n"

systemctl enable --now docker

if systemctl is-active --quiet docker; then
    printf '%s\n' '[OK] Docker service ACTIVE.'
else
    printf '%s\n' '[ERROR] Docker service tidak aktif.'
    exit 1
fi

# ============================================================
# 4/11 - CLOAKBROWSER MOD
# ============================================================

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' ' 4/11 - CLOAKBROWSER MOD'
printf '%s\n' '============================================================'
printf "\n"

if [ -d "$APP_DIR/.git" ]; then

    printf '%s\n' '[INFO] Repository sudah ada.'

    cd "$APP_DIR"

    printf "\n"
    printf '%s\n' '[1/3] Set remote repository...'

    git remote set-url origin "$REPO_URL"

    printf '%s\n' '[2/3] Git status...'
    git status --short || true

    printf "\n"
    printf '%s\n' '[3/3] Update repository MOD...'

    git fetch origin
    git pull --ff-only

else

    printf '%s\n' '[INFO] Clone CloakBrowser MOD...'
    printf '%s\n' "$REPO_URL"
    printf "\n"

    mkdir -p /opt

    git clone "$REPO_URL" "$APP_DIR"

fi

cd "$APP_DIR"

printf "\n"
printf '%s\n' '[OK] CloakBrowser MOD siap.'

# ============================================================
# 5/11 - FOLDER PIA
# ============================================================

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' ' 5/11 - SIAPKAN FOLDER PIA'
printf '%s\n' '============================================================'
printf "\n"

mkdir -p "$PIA_DIR"

printf '%s\n' '[OK] Folder PIA siap:'
printf '%s\n' "  $PIA_DIR"

# ============================================================
# 6/11 - DOCKER + PIA
# ============================================================

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' ' 6/11 - KONFIGURASI DOCKER + PIA'
printf '%s\n' '============================================================'
printf "\n"

if [ ! -f "$COMPOSE_FILE" ]; then
    printf '%s\n' '[ERROR] docker-compose.yml tidak ditemukan.'
    exit 1
fi

printf '%s\n' '[INFO] Backup docker-compose.yml...'

cp "$COMPOSE_FILE" "$COMPOSE_FILE.backup"

# ------------------------------------------------------------
# PORT 8080
# ------------------------------------------------------------

printf "\n"
printf '%s\n' '[1/3] Konfigurasi port 8080...'

if grep -q '127\.0\.0\.1:8080:8080' "$COMPOSE_FILE"; then

    sed -i \
        's/127\.0\.0\.1:8080:8080/0.0.0.0:8080:8080/g' \
        "$COMPOSE_FILE"

    printf '%s\n' '[OK] Port diubah menjadi 0.0.0.0:8080.'

else

    printf '%s\n' '[OK] Port 8080 sudah dikonfigurasi.'

fi

# ------------------------------------------------------------
# PIA MOUNT
# ------------------------------------------------------------

printf "\n"
printf '%s\n' '[2/3] Konfigurasi mount PIA...'

cat > "$OVERRIDE_FILE" <<EOF
services:
  manager:
    volumes:
      - type: bind
        source: $PIA_DIR
        target: /data/extensions/pia
        read_only: true
EOF

printf '%s\n' '[OK] PIA mount:'
printf '%s\n' "  $PIA_DIR"
printf '%s\n' '       ↓'
printf '%s\n' '  /data/extensions/pia'

# ------------------------------------------------------------
# COMPOSE CHECK
# ------------------------------------------------------------

printf "\n"
printf '%s\n' '[3/3] Validasi Docker Compose...'

docker compose config >/dev/null

printf '%s\n' '[OK] Docker Compose valid.'

# ============================================================
# 7/11 - BUILD
# ============================================================

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' ' 7/11 - BUILD CLOAKBROWSER MOD'
printf '%s\n' '============================================================'
printf "\n"

printf '%s\n' '[INFO] Docker build dimulai.'
printf '%s\n' '[INFO] Log build ditampilkan realtime.'
printf "\n"

docker compose build

printf "\n"
printf '%s\n' '[OK] Build selesai.'

# ============================================================
# 8/11 - START + ONLINE
# ============================================================

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' ' 8/11 - START CLOAKBROWSER + PORT 8080'
printf '%s\n' '============================================================'
printf "\n"

printf '%s\n' '[INFO] Menjalankan container...'

docker compose up -d

sleep 5

printf "\n"
docker compose ps

printf "\n"

if docker compose ps --status running | grep -q "$SERVICE_NAME"; then
    printf '%s\n' '[OK] Container Manager RUNNING.'
else
    printf '%s\n' '[ERROR] Container Manager tidak berjalan.'
    printf "\n"
    docker compose logs --tail=100
    exit 1
fi

printf "\n"
printf '%s\n' '[INFO] Cek HTTP 8080...'

if curl -fsS http://127.0.0.1:8080 >/dev/null 2>&1; then
    printf '%s\n' '[OK] HTTP 8080 ONLINE.'
else
    printf '%s\n' '[WARNING] HTTP 8080 belum memberikan response.'
fi

# ============================================================
# 9/11 - UPLOAD PIA
# ============================================================

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' ' 9/11 - UPLOAD PIA VPN'
printf '%s\n' '============================================================'
printf "\n"

printf '%s\n' 'CloakBrowser MOD sudah online.'
printf "\n"

printf '%s\n' 'Installer PAUSE sementara.'
printf "\n"

printf '%s\n' 'Silakan upload folder PIA ke:'
printf "\n"
printf '%s\n' "  $PIA_DIR"
printf "\n"

printf '%s\n' 'Gunakan WinSCP / SFTP.'
printf "\n"

printf '%s\n' 'Pastikan manifest.json berada langsung di:'
printf "\n"
printf '%s\n' "  $PIA_DIR/manifest.json"
printf "\n"

printf '%s\n' 'Jangan upload PIA ke GitHub jika lisensinya'
printf '%s\n' 'tidak mengizinkan redistribusi.'
printf "\n"

printf '%s\n' '============================================================'
printf "\n"

ANSWER=""

while true; do

    read -r -p \
        "Ketik YES setelah upload PIA selesai: " \
        ANSWER

    ANSWER="$(
        printf '%s' "$ANSWER" |
        tr -d '[:space:]' |
        tr '[:lower:]' '[:upper:]'
    )"

    if [ "$ANSWER" = "YES" ]; then
        break
    fi

    printf "\n"
    printf '%s\n' '[INFO] Jawaban harus YES.'
    printf "\n"

done

printf "\n"
printf '%s\n' '[OK] YES diterima.'
printf '%s\n' '[INFO] Melanjutkan instalasi...'

# ============================================================
# 10/11 - VALIDASI PIA
# ============================================================

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' ' 10/11 - VALIDASI PIA'
printf '%s\n' '============================================================'
printf "\n"

printf '%s\n' '[1/5] Cek manifest.json...'

if [ ! -f "$PIA_DIR/manifest.json" ]; then

    printf "\n"
    printf '%s\n' '[ERROR] manifest.json tidak ditemukan.'
    printf '%s\n' "Folder: $PIA_DIR"
    printf "\n"

    ls -la "$PIA_DIR"

    printf "\n"
    exit 1

fi

printf '%s\n' '[OK] manifest.json ditemukan.'

# ------------------------------------------------------------
# MANIFEST INFO
# ------------------------------------------------------------

printf "\n"
printf '%s\n' '[2/5] Informasi extension:'
printf "\n"

grep -E \
    '"manifest_version"|"name"|"version"' \
    "$PIA_DIR/manifest.json" |
    head -10 || true

# ------------------------------------------------------------
# COMPOSE VALIDATION
# ------------------------------------------------------------

printf "\n"
printf '%s\n' '[3/5] Validasi Docker Compose...'

docker compose config >/dev/null

printf '%s\n' '[OK] Docker Compose valid.'

# ------------------------------------------------------------
# RECREATE
# ------------------------------------------------------------

printf "\n"
printf '%s\n' '[4/5] Recreate container...'

docker compose up -d --force-recreate

sleep 5

printf '%s\n' '[OK] Container sudah direcreate.'

# ------------------------------------------------------------
# PIA CONTAINER CHECK
# ------------------------------------------------------------

printf "\n"
printf '%s\n' '[5/5] Cek PIA dari dalam container...'

if docker exec "$CONTAINER_NAME" \
    test -f /data/extensions/pia/manifest.json; then

    printf '%s\n' '[OK] PIA TERBACA DI CONTAINER.'

else

    printf "\n"
    printf '%s\n' '[ERROR] PIA tidak terbaca di container.'
    printf "\n"

    printf '%s\n' 'Mount yang diharapkan:'
    printf '%s\n' "  $PIA_DIR"
    printf '%s\n' '       ↓'
    printf '%s\n' '  /data/extensions/pia'

    printf "\n"

    docker inspect "$CONTAINER_NAME" \
        --format '{{json .Mounts}}' || true

    printf "\n"
    docker compose logs --tail=100 || true

    exit 1

fi

# ============================================================
# FORCE CONTINUE
# ============================================================

printf "\n"
printf '%s\n' '[OK] Validasi tahap 10/11 selesai.'
printf '%s\n' '[INFO] Installer melanjutkan ke tahap 11/11...'
printf "\n"

sleep 2

# ============================================================
# 11/11 - CREATE INITIAL PROFILES
# ============================================================

printf '%s\n' '============================================================'
printf '%s\n' ' 11/11 - CREATE INITIAL PROFILES'
printf '%s\n' '============================================================'
printf "\n"

printf '%s\n' "Default jumlah profile: $DEFAULT_PROFILE_COUNT"
printf '%s\n' 'Tekan ENTER untuk memakai 4 profile.'
printf '%s\n' 'Atau masukkan jumlah lain.'
printf "\n"

read -r -p \
    "Berapa profile yang ingin dibuat? [$DEFAULT_PROFILE_COUNT]: " \
    PROFILE_COUNT

if [ -z "$PROFILE_COUNT" ]; then
    PROFILE_COUNT="$DEFAULT_PROFILE_COUNT"
fi

if ! [[ "$PROFILE_COUNT" =~ ^[0-9]+$ ]]; then
    printf '%s\n' '[ERROR] Jumlah profile harus berupa angka.'
    exit 1
fi

if [ "$PROFILE_COUNT" -lt 1 ]; then
    printf '%s\n' '[ERROR] Jumlah profile minimal 1.'
    exit 1
fi

printf "\n"
printf '%s\n' "[INFO] Membuat $PROFILE_COUNT profile..."
printf "\n"

# ------------------------------------------------------------
# Cari database.py
# ------------------------------------------------------------

printf '%s\n' '[INFO] Mencari database.py di container...'

DB_FILE="$(
    docker exec "$CONTAINER_NAME" \
        sh -c 'find /app /opt /workspace /src -type f -name database.py 2>/dev/null | head -1' |
        tr -d '\r'
)"

if [ -z "$DB_FILE" ]; then

    printf "\n"
    printf '%s\n' '[ERROR] database.py tidak ditemukan di container.'
    printf "\n"

    docker exec "$CONTAINER_NAME" \
        sh -c '
            echo "=== /app ==="
            ls -la /app 2>/dev/null || true
            echo
            echo "=== /opt ==="
            ls -la /opt 2>/dev/null || true
            echo
            echo "=== /workspace ==="
            ls -la /workspace 2>/dev/null || true
        '

    exit 1

fi

DB_DIR="$(dirname "$DB_FILE")"

printf '%s\n' '[OK] database.py ditemukan:'
printf '%s\n' "  $DB_FILE"
printf "\n"

printf '%s\n' '[INFO] Menjalankan create_initial_profiles()...'
printf "\n"

# ------------------------------------------------------------
# Create profiles
# ------------------------------------------------------------

docker exec \
    -e PROFILE_COUNT="$PROFILE_COUNT" \
    -e DB_DIR="$DB_DIR" \
    "$CONTAINER_NAME" \
    python3 -c '
import os
import sys

db_dir = os.environ["DB_DIR"]
sys.path.insert(0, db_dir)

from database import create_initial_profiles

count = int(os.environ["PROFILE_COUNT"])

profiles = create_initial_profiles(count)

print("")
print("=" * 60)
print(f"[OK] {len(profiles)} PROFILE BERHASIL DIBUAT")
print("=" * 60)

for i, profile in enumerate(profiles, 1):

    print("")
    print(f"[{i}/{len(profiles)}] {profile.get("name")}")
    print(f"      UUID : {profile.get("id")}")
    print(f"      Seed : {profile.get("fingerprint_seed")}")
    print(f"      Data : {profile.get("user_data_dir")}")

    args = profile.get("launch_args") or []

    print(f"      Launch Args : {len(args)}")

    for arg in args:
        print(f"        - {arg}")
'

# ============================================================
# FINAL STATUS
# ============================================================

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' '              INSTALLASI SELESAI'
printf '%s\n' '============================================================'
printf "\n"

docker compose ps

printf "\n"
printf '%s\n' 'CloakBrowser Manager:'
printf '%s\n' '  http://IP_SERVER:8080'

printf "\n"
printf '%s\n' 'PIA Host:'
printf '%s\n' "  $PIA_DIR"

printf "\n"
printf '%s\n' 'PIA Container:'
printf '%s\n' '  /data/extensions/pia'

printf "\n"
printf '%s\n' 'Default Chromium Launch Args:'
printf '%s\n' '  --disable-extensions-except=/data/extensions/pia'
printf '%s\n' '  --load-extension=/data/extensions/pia'
printf '%s\n' '  --no-sandbox'

printf "\n"
printf '%s\n' 'Initial Profile:'
printf '%s\n' "  $PROFILE_COUNT profile"

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' '                    SELESAI'
printf '%s\n' '============================================================'
printf "\n"

#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# CLOAKBROWSER MOD INSTALLER
# Ubuntu 24.04
# Docker + CloakBrowser MOD + Online :8080
# Manual PIA VPN Upload
# Create Initial Profiles + Proxy Input
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
printf '%s\n' '[4/4] Install curl, gnupg, git...'
apt install -y curl gnupg git

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

DEFAULT_PROFILE_COUNT=4
MANAGER_URL="http://127.0.0.1:8080"

printf '%s\n' "Default jumlah profile: $DEFAULT_PROFILE_COUNT"
printf '%s\n' 'Tekan ENTER untuk memakai 4 profile.'
printf '%s\n' 'Atau masukkan jumlah lain.'
printf "\n"

read -r -p \
    "Berapa profile yang ingin dibuat? [$DEFAULT_PROFILE_COUNT]: " \
    PROFILE_COUNT < /dev/tty

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
printf '%s\n' "[INFO] Jumlah profile: $PROFILE_COUNT"
printf "\n"

# ------------------------------------------------------------
# MANAGER API CHECK
# ------------------------------------------------------------

printf '%s\n' '[1/4] Cek API Manager...'

if ! curl -fsS \
    "$MANAGER_URL/api/status" \
    >/dev/null 2>&1; then

    printf "\n"
    printf '%s\n' '[ERROR] API Manager tidak bisa diakses.'
    printf '%s\n' "  $MANAGER_URL/api/status"
    printf "\n"

    docker compose ps
    printf "\n"
    docker compose logs --tail=50 || true

    exit 1
fi

printf '%s\n' '[OK] API Manager ONLINE.'

# ------------------------------------------------------------
# PROFILE INPUT
# ------------------------------------------------------------

printf "\n"
printf '%s\n' '[2/4] Input proxy...'
printf "\n"

printf '%s\n' 'Masukkan satu proxy untuk setiap profile.'
printf '%s\n' 'Proxy #1 -> Profile 01'
printf '%s\n' 'Proxy #2 -> Profile 02'
printf '%s\n' 'dan seterusnya.'
printf "\n"

printf '%s\n' 'Format yang didukung:'
printf '%s\n' '  socks5://user:pass@host:port'
printf '%s\n' '  http://user:pass@host:port'
printf '%s\n' '  host:port:user:pass'
printf '%s\n' '  host:port'
printf "\n"

printf '%s\n' 'Format tabel Markdown juga dibersihkan otomatis:'
printf '%s\n' '  | socks5://user\:pass\@host:port |'
printf "\n"

printf '%s\n' 'ENTER kosong = profile tanpa proxy.'
printf "\n"

declare -a PROFILE_PROXIES=()

normalize_profile_proxy() {
    local value="$1"

    # Hapus | dari tabel Markdown
    value="${value#|}"
    value="${value%|}"

    # Hapus <br>
    value="${value//<br>/}"
    value="${value//<br\/>/}"
    value="${value//<br \/>/}"

    # Hapus escape Markdown
    value="${value//\\:/\:}"
    value="${value//\\@/@}"

    # Trim
    value="$(
        printf '%s' "$value" |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    )"

    printf '%s' "$value"
}

validate_profile_proxy() {
    local value="$1"

    case "$value" in
        socks5://*|socks5h://*|http://*|https://*)
            return 0
            ;;
    esac

    if [[ "$value" =~ ^[^:]+:[0-9]+$ ]]; then
        return 0
    fi

    if [[ "$value" =~ ^[^:]+:[0-9]+:[^:]+:.+$ ]]; then
        return 0
    fi

    return 1
}

for ((i=1; i<=PROFILE_COUNT; i++)); do

    while true; do

        read -r -p \
            "Proxy Profile $(printf '%02d' "$i"): " \
            RAW_PROXY < /dev/tty

        PROXY="$(normalize_profile_proxy "$RAW_PROXY")"

        # Empty = no proxy
        if [ -z "$PROXY" ]; then
            PROFILE_PROXIES[$i]=""
            break
        fi

        if validate_profile_proxy "$PROXY"; then
            PROFILE_PROXIES[$i]="$PROXY"
            break
        fi

        printf "\n"
        printf '%s\n' '[ERROR] Format proxy tidak dikenali.'
        printf '%s\n' 'Masukkan ulang atau tekan ENTER untuk tanpa proxy.'
        printf "\n"

    done

done

# ------------------------------------------------------------
# JSON ESCAPE
# ------------------------------------------------------------

json_escape() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\t'/\\t}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\n'/\\n}"

    printf '%s' "$value"
}

# ------------------------------------------------------------
# CREATE PROFILE VIA MANAGER API
#
# Tidak memakai python3.
#
# POST /api/profiles
# Backend MOD yang membuat:
# - UUID
# - fingerprint_seed
# - user_data_dir
# - default launch_args
# - proxy
# ------------------------------------------------------------

printf "\n"
printf '%s\n' '[3/4] Membuat profile melalui Manager API...'
printf "\n"

CREATED_COUNT=0
PROXY_COUNT=0

for ((i=1; i<=PROFILE_COUNT; i++)); do

    PROFILE_NAME="Profile $(printf '%02d' "$i")"
    PROFILE_PROXY="${PROFILE_PROXIES[$i]:-}"

    NAME_JSON="$(json_escape "$PROFILE_NAME")"

    if [ -n "$PROFILE_PROXY" ]; then

        PROXY_JSON="$(json_escape "$PROFILE_PROXY")"

        JSON_BODY="$(
            printf '{"name":"%s","proxy":"%s"}' \
                "$NAME_JSON" \
                "$PROXY_JSON"
        )"

        PROXY_COUNT=$((PROXY_COUNT + 1))

    else

        JSON_BODY="$(
            printf '{"name":"%s","proxy":null}' \
                "$NAME_JSON"
        )"

    fi

    RESPONSE_FILE="$(mktemp)"

    HTTP_CODE="$(
        curl -sS \
            -o "$RESPONSE_FILE" \
            -w '%{http_code}' \
            -X POST \
            -H 'Content-Type: application/json' \
            --data "$JSON_BODY" \
            "$MANAGER_URL/api/profiles"
    )"

    if [ "$HTTP_CODE" != "201" ]; then

        printf "\n"
        printf '%s\n' "[ERROR] Gagal membuat $PROFILE_NAME."
        printf '%s\n' "HTTP: $HTTP_CODE"
        printf '%s\n' 'Response:'
        cat "$RESPONSE_FILE"
        printf "\n"

        rm -f "$RESPONSE_FILE"

        printf '%s\n' '[ERROR] Proses dihentikan.'
        exit 1

    fi

    # Ambil informasi dasar dari JSON response tanpa python/jq.
    PROFILE_ID="$(
        sed -n 's/.*"id":"\([^"]*\)".*/\1/p' \
            "$RESPONSE_FILE" |
        head -1
    )"

    FINGERPRINT_SEED="$(
        sed -n 's/.*"fingerprint_seed":\([0-9]*\).*/\1/p' \
            "$RESPONSE_FILE" |
        head -1
    )"

    USER_DATA_DIR="$(
        sed -n 's/.*"user_data_dir":"\([^"]*\)".*/\1/p' \
            "$RESPONSE_FILE" |
        head -1
    )"

    LAUNCH_ARGS_COUNT="$(
        grep -o '"launch_args":\[' "$RESPONSE_FILE" |
        wc -l |
        tr -d ' '
    )"

    CREATED_COUNT=$((CREATED_COUNT + 1))

    if [ -n "$PROFILE_PROXY" ]; then
        PROXY_STATUS="PROXY"
    else
        PROXY_STATUS="TANPA PROXY"
    fi

    printf '%s\n' \
        "[$CREATED_COUNT/$PROFILE_COUNT] $PROFILE_NAME -> $PROXY_STATUS"

    printf '%s\n' "      UUID : ${PROFILE_ID:-OK}"
    printf '%s\n' "      Seed : ${FINGERPRINT_SEED:-OK}"
    printf '%s\n' "      Data : ${USER_DATA_DIR:-OK}"

    rm -f "$RESPONSE_FILE"

    printf "\n"

done

# ------------------------------------------------------------
# FINAL PROFILE CHECK
# ------------------------------------------------------------

printf '%s\n' '[4/4] Verifikasi jumlah profile...'
printf "\n"

PROFILE_STATUS_RESPONSE="$(mktemp)"

HTTP_CODE="$(
    curl -sS \
        -o "$PROFILE_STATUS_RESPONSE" \
        -w '%{http_code}' \
        "$MANAGER_URL/api/status"
)"

if [ "$HTTP_CODE" = "200" ]; then

    TOTAL_PROFILES="$(
        sed -n 's/.*"profiles_total":\([0-9]*\).*/\1/p' \
            "$PROFILE_STATUS_RESPONSE" |
        head -1
    )"

    printf '%s\n' "[OK] Manager melaporkan total profile: ${TOTAL_PROFILES:-UNKNOWN}"

else

    printf '%s\n' '[WARNING] Tidak dapat membaca total profile dari API.'

fi

rm -f "$PROFILE_STATUS_RESPONSE"

printf "\n"
printf '%s\n' '============================================================'
printf '%s\n' '              PROFILE CREATION SELESAI'
printf '%s\n' '============================================================'
printf "\n"

printf '%s\n' "[OK] Profile dibuat: $CREATED_COUNT/$PROFILE_COUNT"
printf '%s\n' "[OK] Profile dengan proxy: $PROXY_COUNT/$PROFILE_COUNT"
printf '%s\n' '[OK] UUID dan fingerprint dibuat oleh MOD backend.'
printf '%s\n' '[OK] Launch Args default berasal dari MOD backend.'
printf "\n"

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

#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
DEFAULT_PROFILE_COUNT=4

header() {
    printf '\n'
    printf '%s\n' '============================================================'
    printf '%s\n' "$1"
    printf '%s\n' '============================================================'
    printf '\n'
}

normalize_proxy() {
    local x="$1"

    x="${x#|}"
    x="${x%|}"
    x="${x//\\:/\:}"
    x="${x//\\@/@}"
    x="${x//<br>/}"
    x="${x//<br/>/}"
    x="${x//<br \/>/}"

    printf '%s' "$x" |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

valid_proxy() {
    local proxy="$1"

    case "$proxy" in
        socks5://*|socks5h://*|http://*|https://*)
            return 0
            ;;
    esac

    [[ "$proxy" =~ ^[^:]+:[0-9]+$ ]] && return 0
    [[ "$proxy" =~ ^[^:]+:[0-9]+:[^:]+:.+$ ]] && return 0

    return 1
}

create_profile() {
    local name="$1"
    local proxy="$2"
    local out
    local code
    local id
    local seed

    out="$(mktemp)"

    if [ -n "$proxy" ]; then
        code="$(
            curl -sS \
                -o "$out" \
                -w '%{http_code}' \
                -X POST \
                -H 'Content-Type: application/json' \
                --data "{\"name\":\"$name\",\"proxy\":\"$proxy\"}" \
                "$BASE_URL/api/profiles"
        )"
    else
        code="$(
            curl -sS \
                -o "$out" \
                -w '%{http_code}' \
                -X POST \
                -H 'Content-Type: application/json' \
                --data "{\"name\":\"$name\",\"proxy\":null}" \
                "$BASE_URL/api/profiles"
        )"
    fi

    if [ "$code" != "201" ]; then
        printf '%s\n' "[ERROR] $name gagal dibuat (HTTP $code)."
        printf '%s\n' 'Response API:'
        cat "$out"
        printf '\n'
        rm -f "$out"
        return 1
    fi

    id="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$out" | head -1)"
    seed="$(sed -n 's/.*"fingerprint_seed":\([0-9]*\).*/\1/p' "$out" | head -1)"

    printf '%s\n' "[OK] $name dibuat."
    printf '%s\n' "     UUID : ${id:-OK}"
    printf '%s\n' "     Seed : ${seed:-OK}"
    printf '%s\n' "     Proxy: ${proxy:-TANPA PROXY}"

    rm -f "$out"
}

# ============================================================
# CHECK API
# ============================================================

header 'CREATE INITIAL PROFILES'

printf '%s\n' '[1/4] Cek API Manager...'

if ! curl -fsS "$BASE_URL/api/status" >/dev/null 2>&1; then
    printf '%s\n' "[ERROR] API Manager tidak bisa diakses: $BASE_URL"
    exit 1
fi

printf '%s\n' '[OK] API Manager ONLINE.'
printf '\n'

# ============================================================
# PROFILE COUNT
# ============================================================

read -r -p \
    "Berapa profile yang ingin dibuat? [$DEFAULT_PROFILE_COUNT]: " \
    PROFILE_COUNT < /dev/tty

PROFILE_COUNT="${PROFILE_COUNT:-$DEFAULT_PROFILE_COUNT}"

if ! [[ "$PROFILE_COUNT" =~ ^[0-9]+$ ]] || [ "$PROFILE_COUNT" -lt 1 ]; then
    printf '%s\n' '[ERROR] Jumlah profile harus berupa angka minimal 1.'
    exit 1
fi

printf '%s\n' "[INFO] Jumlah profile: $PROFILE_COUNT"
printf '\n'

# ============================================================
# MULTI-LINE PROXY INPUT
# ============================================================

printf '%s\n' '[2/4] Input proxy...'
printf '%s\n' "Paste sampai $PROFILE_COUNT proxy sekaligus."
printf '%s\n' 'Satu baris = satu proxy.'
printf '%s\n' 'Proxy baris 1 -> Profile 01, dst.'
printf '%s\n' 'Setelah proxy terakhir, tekan ENTER pada baris kosong.'
printf '%s\n' 'Kalau tidak memakai proxy, langsung ENTER.'
printf '\n'

printf '%s\n' 'Format yang didukung:'
printf '%s\n' '  socks5://user:pass@host:port'
printf '%s\n' '  http://user:pass@host:port'
printf '%s\n' '  host:port:user:pass'
printf '%s\n' '  host:port'
printf '%s\n' 'Format tabel Markdown juga dibersihkan otomatis:'
printf '%s\n' '  | socks5://user:pass@host:port |'
printf '\n'

declare -a PROXIES=()
PROXY_COUNT=0

while [ "$PROXY_COUNT" -lt "$PROFILE_COUNT" ]; do

    # Read one complete line. Pasting multiple lines works:
    # each pasted line becomes one iteration.
    IFS= read -r RAW_PROXY < /dev/tty || RAW_PROXY=""

    PROXY="$(normalize_proxy "$RAW_PROXY")"

    # Blank line ends proxy input.
    if [ -z "$PROXY" ]; then
        break
    fi

    if ! valid_proxy "$PROXY"; then
        printf '%s\n' "[WARNING] Proxy ke-$((PROXY_COUNT + 1)) tidak valid, dilewati:"
        printf '%s\n' "  $PROXY"
        continue
    fi

    PROXY_COUNT=$((PROXY_COUNT + 1))
    PROXIES[$PROXY_COUNT]="$PROXY"

    printf '%s\n' "[OK] Proxy $PROXY_COUNT/$PROFILE_COUNT diterima."
done

printf '\n'

if [ "$PROXY_COUNT" -eq 0 ]; then
    printf '%s\n' '[INFO] Tidak ada proxy.'
else
    printf '%s\n' "[OK] $PROXY_COUNT proxy diterima."
fi

if [ "$PROXY_COUNT" -lt "$PROFILE_COUNT" ]; then
    printf '%s\n' "[INFO] $((PROFILE_COUNT - PROXY_COUNT)) profile akan tanpa proxy."
fi

printf '\n'

# ============================================================
# SUMMARY
# ============================================================

printf '%s\n' '[3/4] Mapping profile -> proxy...'
printf '\n'

for ((i=1; i<=PROFILE_COUNT; i++)); do
    if [ "$i" -le "$PROXY_COUNT" ]; then
        printf '%s\n' "Profile $(printf '%02d' "$i") -> Proxy $i"
    else
        printf '%s\n' "Profile $(printf '%02d' "$i") -> TANPA PROXY"
    fi
done

printf '\n'

# ============================================================
# CREATE
# ============================================================

printf '%s\n' '[4/4] Membuat profile melalui Manager API...'
printf '\n'

for ((i=1; i<=PROFILE_COUNT; i++)); do
    NAME="Profile $(printf '%02d' "$i")"

    if [ "$i" -le "$PROXY_COUNT" ]; then
        PROXY="${PROXIES[$i]}"
    else
        PROXY=""
    fi

    create_profile "$NAME" "$PROXY"
    printf '\n'
done

header 'SELESAI'

printf '%s\n' "[OK] $PROFILE_COUNT profile berhasil dibuat."
printf '%s\n' "[OK] $PROXY_COUNT profile menggunakan proxy."
printf '%s\n' "[OK] $((PROFILE_COUNT - PROXY_COUNT)) profile tanpa proxy."
printf '%s\n' 'UUID, fingerprint seed, user_data_dir, dan Launch Args dibuat oleh MOD backend.'
printf '\n'

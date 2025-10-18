#!/system/bin/sh
set -e

MODPATH=/data/adb/modules/zapret
DNSCRYPT_DIR="$MODPATH/dnscrypt"

BLOCKED_NAMES_FILE="$DNSCRYPT_DIR/blocked-names.txt"
BLOCKED_IPS_FILE="$DNSCRYPT_DIR/blocked-ips.txt"
ALLOWED_NAMES_FILE="$DNSCRYPT_DIR/allowed-names.txt"
ALLOWED_IPS_FILE="$DNSCRYPT_DIR/allowed-ips.txt"

CUSTOM_BLOCKED_NAMES_FILE="$DNSCRYPT_DIR/custom-blocked-names.txt"
CUSTOM_BLOCKED_IPS_FILE="$DNSCRYPT_DIR/custom-blocked-ips.txt"
CUSTOM_ALLOWED_NAMES_FILE="$DNSCRYPT_DIR/custom-allowed-names.txt"
CUSTOM_ALLOWED_IPS_FILE="$DNSCRYPT_DIR/custom-allowed-ips.txt"

ensure_newline() {
  [ -f "$1" ] || return
  [ -s "$1" ] || return
  [ "$(tail -c1 "$1")" = "" ] && return
  printf "\n" >> "$1"
}

append_section() {
  local target="$1"
  local custom="$2"
  local header="$3"

  [ -f "$custom" ] || return
  [ -s "$custom" ] || return
  grep -Fxq "$header" "$target" 2>/dev/null && return

  mkdir -p "$(dirname "$target")"
  touch "$target"

  ensure_newline "$target"

  {
    printf "\n"
    printf "%s\n" "$header"
    cat "$custom"
  } >> "$target"
}

disappend_section() {
  local target="$1"
  local header="$2"
  local tmp="${target}.tmp"

  [ -f "$target" ] || return
  grep -Fxq "$header" "$target" 2>/dev/null || return

  awk -v header="$header" 'found || $0 == header { if ($0 == header) found = 1; next } { print }' "$target" > "$tmp"
  mv "$tmp" "$target"
}

append() {
  append_section "$BLOCKED_NAMES_FILE" "$CUSTOM_BLOCKED_NAMES_FILE" "# custom blocked names"
  append_section "$BLOCKED_IPS_FILE" "$CUSTOM_BLOCKED_IPS_FILE" "# custom blocked ips"
  append_section "$ALLOWED_NAMES_FILE" "$CUSTOM_ALLOWED_NAMES_FILE" "# custom allowed names"
  append_section "$ALLOWED_IPS_FILE" "$CUSTOM_ALLOWED_IPS_FILE" "# custom allowed ips"
}

disappend() {
  disappend_section "$BLOCKED_NAMES_FILE" "# custom blocked names"
  disappend_section "$BLOCKED_IPS_FILE" "# custom blocked ips"
  disappend_section "$ALLOWED_NAMES_FILE" "# custom allowed names"
  disappend_section "$ALLOWED_IPS_FILE" "# custom allowed ips"
}

case "$1" in
  append)    append   ;;
  disappend) disappend ;;
  *)         exit 1    ;;
esac

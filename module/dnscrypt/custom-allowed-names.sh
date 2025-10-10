#!/system/bin/sh
set -e

MODPATH=/data/adb/modules/zapret
LIST_FILE="$MODPATH/dnscrypt/allowed-names.txt"
CUSTOM_FILE="$MODPATH/dnscrypt/custom-allowed-names.txt"
HEADER="# custom allowed names"

ensure_newline() {
  [ -f "$1" ] || return
  [ -s "$1" ] || return
  [ "$(tail -c1 "$1" 2>/dev/null || true)" = "" ] && return
  printf '\n' >> "$1"
}

append() {
  [ -f "$CUSTOM_FILE" ] || return 1
  if [ -f "$LIST_FILE" ] && grep -Fxq "$HEADER" "$LIST_FILE" 2>/dev/null; then
    return 0
  fi

  mkdir -p "$(dirname "$LIST_FILE")"
  touch "$LIST_FILE"
  ensure_newline "$LIST_FILE"

  {
    printf '%s\n' "$HEADER"
    cat "$CUSTOM_FILE"
  } >> "$LIST_FILE"
}

disappend() {
  [ -f "$LIST_FILE" ] || return 1
  tmp="${LIST_FILE}.tmp"
  sed '/^# custom allowed names$/,$d' "$LIST_FILE" > "$tmp"
  mv "$tmp" "$LIST_FILE"
}

case "$1" in
  append)    append   ;;
  disappend) disappend ;;
  *)         exit 1   ;;
esac

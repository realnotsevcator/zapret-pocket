#!/bin/sh
set +e

MODPATH="/data/adb/modules/zapret"
if [ ! -x "$MODPATH/curl" ]; then
    echo "curl command not found: $MODPATH/curl" >&2
    exit 1
fi
DNSCRYPTLISTSDIR="$MODPATH/dnscrypt"
ZAPRETLISTSDIR="$MODPATH/list"
ZAPRETIPSETSDIR="$MODPATH/ipset"
IPV6ENABLE=$(cat "$MODPATH/config/ipv6-enable" 2>/dev/null || echo "0")
CUSTOMLINKIPSETV4=$(cat "$MODPATH/config/ipset-v4-link" 2>/dev/null || echo "https://raw.githubusercontent.com/sevcator/zapret-lists/refs/heads/main/ipset-v4.txt")
CUSTOMLINKIPSETV6=$(cat "$MODPATH/config/ipset-v6-link" 2>/dev/null || echo "https://raw.githubusercontent.com/sevcator/zapret-lists/refs/heads/main/ipset-v6.txt")
CUSTOMLINKREESTR=$(cat "$MODPATH/config/reestr-link" 2>/dev/null || echo "https://raw.githubusercontent.com/sevcator/zapret-lists/refs/heads/main/reestr_filtered.txt")

PREDEFINED_LIST_FILES="reestr.txt default.txt google.txt"
PREDEFINED_IPSET_FILES="ipset-v4.txt ipset-v6.txt"
ZAPRETLISTSDEFAULTLINK="https://raw.githubusercontent.com/sevcator/zapret-pocket/refs/heads/main/module/list/"
ZAPRETIPSETSDEFAULTLINK="https://raw.githubusercontent.com/sevcator/zapret-pocket/refs/heads/main/module/ipset/"
IGNORE_FILES="custom.txt exclude.txt"
get_overwrite_url() {
    file="$1"
    case "$file" in
        "reestr.txt") echo "$CUSTOMLINKREESTR" ;;
        "ipset-v4.txt") echo "$CUSTOMLINKIPSETV4" ;;
        "ipset-v6.txt") echo "$CUSTOMLINKIPSETV6" ;;
        *) echo "" ;;
    esac
}

update_file() {
    file="$1"
    url="$2"
    name=$(basename "$file")

    tmp_file="${file}.tmp"
    for _ in 1 2 3 4 5; do
        if "$MODPATH/curl" -fsSL -o "$tmp_file" "$url" >/dev/null 2>&1; then
            if [ ! -f "$file" ] || ! cmp -s "$tmp_file" "$file"; then
                mv "$tmp_file" "$file"
                echo "[ $name ] Downloaded"
            else
                rm -f "$tmp_file"
                echo "[ $name ] Unchanged"
            fi
            return
        fi
    done
    rm -f "$tmp_file"
    echo "[ $name ] Failed"
}

update_dir() {
    dir="$1"
    base_url="$2"
    predefined_files="$3"

    mkdir -p "$dir"
    updated_files=""

    for file_path in "$dir"/*; do
        [ -f "$file_path" ] || continue
        file_name=$(basename "$file_path")

        case " $IGNORE_FILES " in
            *" $file_name "*) continue ;;
        esac
        case " $updated_files " in
            *" $file_name "*) continue ;;
        esac

        if [ "$dir" = "$ZAPRETIPSETSDIR" ]; then
            url=$(get_overwrite_url "$file_name")
            url="${url:-${base_url}${file_name}}"
        else
            url="${base_url}${file_name}"
        fi

        update_file "$file_path" "$url"
        updated_files="$updated_files $file_name"
    done

    for file_name in $predefined_files; do
        case " $IGNORE_FILES " in
            *" $file_name "*) continue ;;
        esac
        case " $updated_files " in
            *" $file_name "*) continue ;;
        esac

        file_path="$dir/$file_name"
        if [ "$dir" = "$ZAPRETIPSETSDIR" ]; then
            url=$(get_overwrite_url "$file_name")
            url="${url:-${base_url}${file_name}}"
        else
            url="${base_url}${file_name}"
        fi

        update_file "$file_path" "$url"
        updated_files="$updated_files $file_name"
    done
}

DNSCRYPT_CUSTOM_SCRIPTS="custom-cloaking-rules.sh custom-blocked-names.sh custom-blocked-ips.sh custom-allowed-names.sh custom-allowed-ips.sh"

if [ "$IPV6ENABLE" != "1" ]; then
    for script in $DNSCRYPT_CUSTOM_SCRIPTS; do
        [ -f "$MODPATH/dnscrypt/$script" ] || continue
        sh "$MODPATH/dnscrypt/$script" disappend >/dev/null 2>&1 || true
    done
fi

update_dir "$ZAPRETLISTSDIR" "$ZAPRETLISTSDEFAULTLINK" "$PREDEFINED_LIST_FILES"
update_dir "$ZAPRETIPSETSDIR" "$ZAPRETIPSETSDEFAULTLINK" "$PREDEFINED_IPSET_FILES"

if [ "$IPV6ENABLE" != "1" ]; then
    for script in $DNSCRYPT_CUSTOM_SCRIPTS; do
        [ -f "$MODPATH/dnscrypt/$script" ] || continue
        sh "$MODPATH/dnscrypt/$script" append >/dev/null 2>&1 || true
    done
fi

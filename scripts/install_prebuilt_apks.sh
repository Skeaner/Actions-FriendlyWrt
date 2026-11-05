#!/bin/bash
set -eu

PROJECT_DIR="$1"
REPO_ROOT="$2"

PM_BIN="$(find "$PROJECT_DIR" -path '*/staging_dir/host/bin/apk' -type f | head -n 1)"
if [ -z "$PM_BIN" ]; then
    echo "ERROR: host apk package manager was not found under $PROJECT_DIR"
    exit 1
fi
chmod +x "$PM_BIN"

ROOTFS_DIR="$(
    find "$PROJECT_DIR" -type d -path '*/etc/apk' 2>/dev/null |
    while IFS= read -r apk_dir; do
        candidate="$(dirname "$(dirname "$apk_dir")")"
        if [ -d "$candidate/etc/apk" ]; then
            printf '%s\n' "$candidate"
            break
        fi
    done
)"

if [ -z "$ROOTFS_DIR" ]; then
    echo "ERROR: extracted rootfs containing etc/apk was not found under $PROJECT_DIR"
    exit 1
fi

APP_APK="$REPO_ROOT/luci-app-emmc-tools.apk"
I18N_APK="$REPO_ROOT/luci-i18n-emmc-tools-zh-cn.apk"

for apk_file in "$APP_APK" "$I18N_APK"; do
    if [ ! -f "$apk_file" ]; then
        echo "ERROR: required APK not found: $apk_file"
        exit 1
    fi
done

"$PM_BIN" --root "$ROOTFS_DIR" add --allow-untrusted \
    "$APP_APK" "$I18N_APK"

"$PM_BIN" --root "$ROOTFS_DIR" info luci-app-emmc-tools >/dev/null
"$PM_BIN" --root "$ROOTFS_DIR" info luci-i18n-emmc-tools-zh-cn >/dev/null

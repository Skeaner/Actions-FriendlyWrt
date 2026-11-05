#!/bin/bash

install_rtw88_build_patch() {
  local BUILD_KERNEL="scripts/sd-fuse/build-kernel.sh"
  local MARKER="# FriendlyWrt: patch rtw88 for kernel 6.1"

  [ -f "$BUILD_KERNEL" ] || return 0
  grep -Fq "$MARKER" "$BUILD_KERNEL" && return 0

  awk -v marker="$MARKER" '
    /\(cd rtw88\/ && \{/ {
      print
      print marker
      print "            find . -type f \\( -name '\''*.c'\'' -o -name '\''*.h'\'' \\) \\"
      print "                -exec sed -i '\''/^[[:space:]]*#[[:space:]]*define[[:space:]]\\+FIELD_PREP_CONST/d'\'' {} +"
      print "            find . -type f \\( -name '\''*.c'\'' -o -name '\''*.h'\'' \\) \\"
      print "                -exec sed -i '\''s/FIELD_PREP_CONST[[:space:]]*(/FIELD_PREP(/g'\'' {} +"
      print "            if [ -f rtw8723bs.c ]; then"
      print "                sed -i \\"
      print "                    -e '\''s/SDIO_VENDOR_ID_REALTEK/0x024c/g'\'' \\"
      print "                    -e '\''s/SDIO_DEVICE_ID_REALTEK_RTW8723BS/0xb723/g'\'' \\"
      print "                    rtw8723bs.c"
      print "            fi"
      next
    }
    { print }
  ' "$BUILD_KERNEL" > "${BUILD_KERNEL}.friendlywrt.tmp"
  chmod --reference="$BUILD_KERNEL" "${BUILD_KERNEL}.friendlywrt.tmp"
  mv "${BUILD_KERNEL}.friendlywrt.tmp" "$BUILD_KERNEL"
}

install_rtw88_build_patch

CONFIGS=(
  "CONFIG_NET_ACT_CT=m"
  "CONFIG_NET_ACT_CTINFO=m"
)

source .current_config.mk
KCFG=kernel/arch/arm64/configs/$(awk '{print $1}' <<< "$TARGET_KERNEL_CONFIG")

for CFG in "${CONFIGS[@]}"; do
  KEY=${CFG%%=*}
  if grep -q "^#\?${KEY}=" "${KCFG}"; then
    sed -i "s@^#\?${KEY}=.*@${CFG}@g" "${KCFG}"
  else
    echo "$CFG" >> "${KCFG}"
  fi


done

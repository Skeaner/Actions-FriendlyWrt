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

install_usbdrd_host_mode() {
  local DTS="kernel/arch/arm64/boot/dts/rockchip/rk3528-nanopi-rev03.dts"

  [ -f "$DTS" ] || return 0

  # Patch &usbdrd_dwc3 in kernel DTS during build
  awk '
    /^[[:space:]]*&usbdrd_dwc3[[:space:]]*\{/ {
      print
      print "\tdr_mode = \"host\";"
      print "\t/delete-property/ extcon;"
      print "\tstatus = \"okay\";"
      in_node = 1
      next
    }
    in_node && /^[[:space:]]*dr_mode[[:space:]]*=/ { next }
    in_node && /^[[:space:]]*status[[:space:]]*=/ { next }
    in_node && /^[[:space:]]*\/delete-property\/[[:space:]]*extcon;/ { next }
    in_node && /^[[:space:]]*\};/ {
      in_node = 0
      print
      next
    }
    { print }
  ' "$DTS" > "${DTS}.tmp" && mv "${DTS}.tmp" "$DTS"
}

install_usbdrd_host_mode

CONFIGS=(
  "CONFIG_NET_ACT_CT=m"
  "CONFIG_NET_ACT_CTINFO=m"
  "CONFIG_USB_NET_DRIVERS=y"
  "CONFIG_USB_RTL8152=m"
  "CONFIG_USB_NET_AX88179_178A=m"
  "CONFIG_USB_NET_CDCETHER=m"
  "CONFIG_USB_NET_CDC_NCM=m"
  "CONFIG_USB_NET_RNDIS_HOST=m"
  "CONFIG_USB_IPHETH=m"
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

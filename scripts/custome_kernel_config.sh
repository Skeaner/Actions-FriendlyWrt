#!/bin/bash

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

# Kernel 6.1 has no FIELD_PREP_CONST. Remove driver-local definitions,
# then replace calls with the available FIELD_PREP macro.
if [ -d scripts/sd-fuse/out/rtw88 ]; then
  find scripts/sd-fuse/out/rtw88 -type f \( -name '*.c' -o -name '*.h' \) \
    -exec sed -i '/^[[:space:]]*#[[:space:]]*define[[:space:]]\+FIELD_PREP_CONST/d' {} +
  find scripts/sd-fuse/out/rtw88 -type f \( -name '*.c' -o -name '*.h' \) \
    -exec sed -i 's/FIELD_PREP_CONST[[:space:]]*(/FIELD_PREP(/g' {} +

  RTW8723BS=scripts/sd-fuse/out/rtw88/rtw8723bs.c

  # Kernel 6.1 predates these IDs. Use numeric values directly so
  # this also works when rtw88 does not include the sdio_ids header.
  sed -i \
    -e 's/SDIO_VENDOR_ID_REALTEK/0x024c/g' \
    -e 's/SDIO_DEVICE_ID_REALTEK_RTW8723BS/0xb723/g' \
    "$RTW8723BS"

  head -n 15 "$RTW8723BS"
  grep -nE 'SDIO_DEVICE\(|0x024c|0xb723' "$RTW8723BS"
fi
#!/usr/bin/env bash
set -euo pipefail

: "${KERNEL_RELEASE:?set KERNEL_RELEASE}"
: "${OUT_DIR:?set OUT_DIR}"
: "${CHANNEL_DTB:?set CHANNEL_DTB}"
KREL="$KERNEL_RELEASE"
KERNEL_DTB="$OUT_DIR/Image.gz-dtb-$KREL"
BOOTIMG="$OUT_DIR/boot-channel.img"
CHANNEL_ROOT_DEVICE="${CHANNEL_ROOT_DEVICE:-PARTLABEL=userdata}"

if [ -n "${KERNEL_IMAGE:-}" ]; then
  KERNEL="$KERNEL_IMAGE"
else
  : "${KERNEL_DIR:?set KERNEL_DIR or KERNEL_IMAGE}"
  KERNEL="$KERNEL_DIR/arch/arm64/boot/Image.gz"
fi

test -s "$KERNEL"
test -s "$CHANNEL_DTB"

cat "$KERNEL" "$CHANNEL_DTB" > "$KERNEL_DTB"

CMDLINE="${KERNEL_CMDLINE:-console=ttyMSM0,115200n8 console=tty0 root=$CHANNEL_ROOT_DEVICE rootfstype=ext4 rootwait rw loglevel=7 ignore_loglevel}"

if [ -n "${MKBOOTIMG_PY:-}" ]; then
  test -s "$MKBOOTIMG_PY"
  PACKER=(python3 "$MKBOOTIMG_PY")
else
  command -v mkbootimg >/dev/null
  PACKER=(mkbootimg)
fi

"${PACKER[@]}" \
  --header_version 0 \
  --kernel "$KERNEL_DTB" \
  --cmdline "$CMDLINE" \
  --base 0x80000000 \
  --kernel_offset 0x00008000 \
  --ramdisk_offset 0x01000000 \
  --second_offset 0x00f00000 \
  --tags_offset 0x00000100 \
  --pagesize 2048 \
  --output "$BOOTIMG"

BOOT_SIZE="$(stat -c %s "$BOOTIMG")"
if [ "$BOOT_SIZE" -gt $((48 * 1024 * 1024)) ]; then
  echo "boot-channel.img is too large: $BOOT_SIZE bytes" >&2
  exit 1
fi

printf '%s\n' "$CMDLINE" > "$OUT_DIR/kernel-cmdline.txt"
echo "boot-channel.img: $BOOT_SIZE bytes"

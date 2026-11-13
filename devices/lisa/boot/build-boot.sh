#!/usr/bin/env bash
# Build Xiaomi 11 Lite 5G NE (lisa) Android header v3 boot image:
# kernel Image, shared Phonewave initramfs (--ramdisk), and the EROFS tail
# carrying modules, small board firmware, and tail units.
#
# Usage: build-boot.sh RELEASE_DIR TEMPLATE OUTPUT [--dev-access]
#   RELEASE_DIR  linux-perpetua-build release folder (with manifest.json,
#                artifacts/, and modules-root/)
#   TEMPLATE     stock boot.img (Android header v3, 192 MiB)
#   OUTPUT       output boot.img path
set -euo pipefail

usage='usage: build-boot.sh RELEASE_DIR TEMPLATE OUTPUT [--dev-access]'
release=${1:?$usage}
template=${2:?$usage}
output=${3:?$usage}
shift 3

dev_access=
for arg; do
  case $arg in
    --dev-access) dev_access=1 ;;
    *) echo "$usage" >&2; exit 2 ;;
  esac
done

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
k=${LINUX_PERPETUA:-/mnt/development/denial-os/linux-perpetua}
v=${PHONEWAVE_VAULT:-/mnt/development/denial-os/device-vault}/lisa

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/device/firmware/ath11k/WCN6750/hw1.0" \
         "$work/device/firmware/qcom/sm7325/xiaomi/lisa"
cp -a "$here/tail/." "$work/device/"

f=$v/firmware
if [ -f "$f/SHA256SUMS" ]; then
  (cd "$f" && sha256sum -c --quiet SHA256SUMS)
fi
install -m644 "$f/tfa98xx.cnt" "$work/device/firmware/tfa98xx.cnt"
install -m644 "$f/ath11k/WCN6750/hw1.0/board-2.bin" \
  "$work/device/firmware/ath11k/WCN6750/hw1.0/board-2.bin"
install -m644 \
  "$f/qcom/sm7325/xiaomi/lisa/a660_zap.mbn" \
  "$f/qcom/sm7325/xiaomi/lisa/ipa_fws.mbn" \
  "$f/qcom/sm7325/xiaomi/lisa/vpu20_1v.mbn" \
  "$work/device/firmware/qcom/sm7325/xiaomi/lisa/"

"$root/image/boot-tail" "$release" "$work/device" "$work/tail.erofs"
LINUX_PERPETUA="$k" "$root/image/init-boot" "$work/ramdisk.cpio.lz4" \
  --ramdisk ${dev_access:+--dev-access}
"$k/devices/boot/android-v3" "$template" "$release/artifacts/Image" \
  "$work/ramdisk.cpio.lz4" "$output" --tail "$work/tail.erofs"

# Xiaomi 11 Lite 5G NE (lisa)

Arch Linux on `linux-perpetua` using the Phonewave image (`image/`).

## Boot layout (Android header v3)

`lisa` launched on Android 11 with a version 3 `boot` partition (192 MiB, no
`init_boot` partition), alongside stock `vendor_boot` and `dtbo`.

`boot/build-boot.sh` packs a single v3 `boot.img` via
`linux-perpetua/devices/boot/android-v3` containing:

1. `Image` with built-in `qcom/sm7325-xiaomi-lisa.dtb` (`ARM64_FDT_HANDOFF`)
2. Shared Phonewave early userspace (`image/init-boot --ramdisk`, LZ4 legacy)
3. Page-aligned EROFS tail (`image/boot-tail`) holding kernel modules,
   small board firmware, and tail units (`hexagonrpcd.service`)

`image/initramfs/init` reads both `kernel_size` and `ramdisk_size` from the
v3 header to mount the EROFS tail at `/usr/lib/modules`, and writes the
detected slot suffix to `/run/phonewave-slot` so `stock-sensors` and rescue
`fastboot` know the active slot even when `fdt-handoff` replaces vendor
`bootargs`.

## Firmware split (Plan 2B)

The full `firmware-xiaomi-lisa` set (~178 MiB) does not fit inside the
192 MiB `boot` partition alongside kernel, ramdisk, and modules. It is
split as follows:

- **Tail (`$PHONEWAVE_VAULT/lisa/firmware/`)**:
  - `tfa98xx.cnt` (TFA9873 SmartPA protection container)
  - `ath11k/WCN6750/hw1.0/board-2.bin` (WCN6750 Wi-Fi board data)
  - `qcom/sm7325/xiaomi/lisa/{a660_zap.mbn,ipa_fws.mbn,vpu20_1v.mbn}`
- **Rootfs (`/usr/lib/firmware/qcom/sm7325/xiaomi/lisa/`)**:
  - `modem.mbn`, `adsp.mbn`, `cdsp.mbn`, `wpss.mbn`, and `modem_pr/`
    (loaded on demand after `switch_root` when `firmware_class` falls back
    from the tail's firmware path to `/usr/lib/firmware`).
- **Stock partitions (`super` + `persist`)**:
  - `hexagonrpcd.service` (`hexagonrpcd-stock-sensors.service`) reads sensor
    configs from `vendor` + `odm` inside intact `super` and calibration
    from `persist`.

## Open bring-up items

- First on-device boot test of ABL header v3 + `fdt-handoff` against stock
  `vendor_boot` / `dtbo` (watchdog and `fb` / memory reservations).
- Modem (`dmail`): add `boot/tail/dmail/device.toml` and enable
  `dmail.service` once SM7325 IPA embedded endpoint IDs are verified on-device.
- Audio: add `VoiceCall.conf` under
  `services/audio/ucm/ucm2/Qualcomm/sm7325/Xiaomi-Lisa/` for modem call audio.
- Fingerprint: side-mounted power-button sensor is not yet wired.

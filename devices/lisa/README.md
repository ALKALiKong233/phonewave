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

The rootfs must also install `linux-firmware-qcom` and its dependencies from
Arch Linux ARM (`image/packages/base`). The board's proprietary package and
tail do not contain the standard `qcom/a660_sqe.fw` and `qcom/a660_gmu.bin`
GPU microcode. Without them KMS still exposes DSI-1, but Mesa cannot create
the GPU context and Denial aborts during GBM initialization.

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

## Bring-up status

- ABL header v3 + `fdt-handoff` against restored stock `vendor_boot_a` and
  `dtbo_a` boots the installed rootfs. With `linux-firmware-qcom` installed,
  Denial's hardware GLES renderer and DSI-1 at 1080x2400/90 Hz were verified
  on-device, including a captured first-start setup screen (2026-11-13).
- Audio: `MultiMedia1` (`PCM0`) playback and `MultiMedia2` (`PCM1`) capture
  are verified with `services/audio/ucm/ucm2/Qualcomm/sm7325/Xiaomi-Lisa/HiFi.conf`
  and `52-xiaomi-lisa.conf` (48 kHz S16_LE stereo into the TFA9873 protection
  container). Add `VoiceCall.conf` under that UCM directory for modem call audio.
- Sensors & rotation: ADSP uses non-secure FastRPC `/dev/fastrpc-adsp` via
  `boot/tail/systemd/system/hexagonrpcd.service.d/lisa.conf`, with real
  registry writes and mainline `qcom_socinfo` metadata in `hexagonrpcd`.
  `steinerd` defaults (`+y` top edge) match the panel frame and Denial rotates
  `DSI-1` across all four orientations.
- Modem (`dmail`): add `boot/tail/dmail/device.toml` and enable
  `dmail.service` once SM7325 IPA embedded endpoint IDs are verified on-device.
- Fingerprint: side-mounted power-button sensor is not yet wired.

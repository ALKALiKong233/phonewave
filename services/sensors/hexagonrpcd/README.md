# hexagonrpcd

linux-msm's [hexagonrpc](https://github.com/linux-msm/hexagonrpc), the
FastRPC server that hands the ADSP's sensor drivers their configuration when
the ADSP starts, built for the phones with Phonewave's patches. steinerd
needs it running from boot on every phone whose sensors live on the ADSP.

## Patches

| Patch | Why |
| --- | --- |
| `0000-Support-real-registry-writes.patch` | The complete five-commit series from [upstream PR 27](https://github.com/linux-msm/hexagonrpc/pull/27), ending at `40e50412812adce9dddc2be9a4510ebce05eef89`: real registry writes/rename/truncate, the physical registry parent, large request buffers, and error replies without disconnecting the listener. Not PR 21's fake write acknowledgements. |
| `0001-rpcd-Serve-the-sensor-configuration-from-odm-too.patch` | Xiaomi's ADSP firmware reads its sensor JSON files from `/odm/etc/sensors/config`. hexagonrpcd serves that from `odm/sensors/config/` under its `-R` directory, and an empty directory where that is missing, so phones without it see no change. |
| `0002-rpcd-Serve-odm-etc-sensor-config-too.patch` | OnePlus's ADSP firmware reads them from `/odm/etc/sensor/config`, without the s: served from `odm/sensor/config/` the same way. |
| `0003-Honor-registry-sync-and-open-modes.patch` | Sync the real host descriptor before acknowledging fsync, and propagate failed read-write opens rather than silently replacing them with read-only descriptors. |

## On the phones

`image/recipes/hexagonrpcd` builds upstream `da7a374` with the vendored patches;
the recipe checks every patch's SHA-256. It never downloads a moving PR head.
A phone whose sensors live on the ADSP turns on `hexagonrpcd.service` from its
boot image's tail. Once per boot, `hexagonrpcd-stock-sensors.service` copies
the phone's own stock files, read-only, into `/run/hexagonrpcd`:

- Slot-matched vendor sensor JSON and `sns_reg_config`.
- ODM sensor JSON, where present.
- The **whole** persist `sensors/registry` directory into `sensors/persist`,
  including the nested `registry`, sibling `sns_reg_version` and properties.
- SoC selector fields into `socinfo`. Android sysfs is preferred; on mainline,
  platform ID/name, subtype and version come from the real `qcom_socinfo`
  SMEM debugfs fields. Names follow
  [Xiaomi's stock driver](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/blob/lisa-r-oss/drivers/soc/qcom/socinfo.c),
  not a guessed device model. Missing identity/version fails before attach.

Only the RAM copy of `sensors/persist` is writable inside the daemon's
`ProtectSystem=strict` sandbox. Stock partitions and calibration remain
untouched. The oneshot remains active so a listener restart neither remounts
stock partitions nor replaces the live registry copy.

### Lisa bring-up safety

Kodiak declares ADSP `qcom,non-secure-domain`, so Linux registers
`/dev/fastrpc-adsp`, **not** `fastrpc-adsp-secure`. Lisa's tail drop-in selects
that actual endpoint in ExecStart, BindPaths and DeviceAllow, retaining
PrivateDevices and the device cgroup restriction. `-s` selects sensors PD;
the endpoint's name does not select or create that PD. No DT change is needed.

Do not deploy only that drop-in with the old daemon/copier. On Lisa, starting
the old read-only daemon without SoC metadata or `sns_reg_version` reached
`SNS_REG_TASK` fatal, then ADSP recovery and an unexpected phone reboot.
The `sns_registry` request was unsupported; the old listener also disconnected
instead of replying with an error. The imported listener returns the actual
unsupported error, never a fabricated successful interface.

Build with `image/pack hexagonrpcd`. For initial controlled deployment, keep
the service masked until the complete package and Lisa drop-in are installed.
Use a runtime `Restart=no` override and a manual start only; do not enable it
at boot until the sensor inventory, samples and real rotation are accepted.
Capture the boot ID and ADSP state beforehand; a changed boot ID, fatal
message, lost SSC or an empty inventory is a failure, not a successful start.

For the narrow acceptance check, use `steinerctl list accel gyro` and
`steinerctl status`, then `steinerctl watch orientation accel`. Ask the user
to hold the screen upright, left-edge-up, upside down, and right-edge-up;
orientation must follow and Denial must rotate its DSI output. Use
`steinerctl raw accel 25` only when establishing the screen frame: upright
must have approximately +9.8 on screen y, face-up approximately +9.8 on z.
Do not infer a second matrix from the chip's stock `.orient`: the SSC
already applies it. Leave `steinerd/top` at its +y default unless real
screen-relative samples demonstrate a different top edge.

## License

GPL-3.0-or-later, as hexagonrpc.

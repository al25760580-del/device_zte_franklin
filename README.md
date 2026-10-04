# ZTE / IZZI B820C-A15 (`franklin`) — LineageOS 19.1 device tree

## Validation status

This package is a device tree and prebuilt base prepared from the supplied stock dump. A complete LineageOS source tree has not yet been synchronized, the tree has not been built, and it has not been tested on hardware; therefore, it must not be described as a functional/bootable ROM or flashed as such.

There is also one specific uncertainty that blocks a flashing recommendation: `vbmeta` declares a separate `dt` partition, but the dump does not include `dt.img`. The tree preserves that partition (`TARGET_FLASH_DTB_PARTITION := false`) and packages the multi-DTB bundle found in the stock boot image into `boot.img`. It has not been demonstrated that this bundle can replace `dt`.

## Identification and technical basis

- Product: ZTE / IZZI B820C-A15, build codename `franklin`.
- SoC: Amlogic G12A / S905X2; U-Boot reported `aml_dt=g12a_u212_mtk`.
- Selected bootloader variant: `g12a_u212_mtk`. `g12a_u212_2g` is also retained for reference.
- Stock: Android 12, vendor API 31, first-level API 28; ARM32 userspace, ARM64 Linux 4.9.269 kernel.
- Target branch: LineageOS 19.1, corresponding to Android 12L/12.1 (API 32); it is not exactly the same API level as the stock system's API 31.
- Kernel, multi-DTB, and DTBO are prebuilts extracted from the dump. No kernel source code was provided or is being compiled.
- Stock `super` is dynamic and non-A/B; observed physical size: 1,887,436,800 bytes. `dtbo` is 8 MiB. The size of `dt` could not be verified; 256 KiB is a common Amlogic value, not a measurement from the Franklin dump.

## Contents

- `BoardConfig.mk`, `device.mk`, `lineage_franklin.mk`, `AndroidProducts.mk`, and dependency on `device/amlogic/g12-common`.
- Packaging rules that reuse `prebuilt/Image.gz`, `prebuilt/aml-dtb-multi.img`, and the stock DTBO payload without padding.
- `proprietary-files.txt` with Franklin blobs not covered by the common tree, including 4.9.269 modules, Wi-Fi/BT firmware, TV/tuner components, and init/VINTF files.
- `extract-stock-dump.sh` and `extract-stock-prebuilts.py` for reproducing extraction from the local dump.
- `hardware-dts/` containing diagnostic decompilations of the DTB/DTBO; these are not used as compilation sources. `dtc` warnings reflect properties/names inherited from the stock DTB.
- `init.amlogic.wifi_buildin.rc` is an intentionally empty stub: the common init imports it, but the file was not present in the inspected Franklin image.

The package does not contain the complete `boot_partition.img`, the 8 MiB `dtbo.img`, `super.img`, `userdata`, `factory`/`param`/`tee` partitions, SSH keys, or provisioning blobs.

## Integration into the LineageOS tree

1. Prepare a LineageOS 19.1 source tree for `arm`, and copy `device/zte/franklin/` from this package into the root of the checkout.

2. Resolve the LineageOS dependencies, especially `device/amlogic/g12-common` (and its dependency `device/amlogic/common`), on the `lineage-19.1` branch. The usual procedure is:

   ```sh
   source build/envsetup.sh
   breakfast franklin

 If the initial setup stops because `vendor/amlogic/g12-common/BoardConfigVendor.mk` does not yet exist, this is because the blobs have not been extracted yet. Keep the common tree that `breakfast` synchronized, continue with the next step, and run `breakfast franklin` again after extraction.

 3. With the stock dump available as a local directory, extract the prebuilts and blobs:

   ```
   device/zte/franklin/extract-stock-dump.sh /path/to/B820C-A15_20260928_005317
   ```
    `lpunpack`, `debugfs` (e2fsprogs), and Python 3 are required. The script only works with `system`, `vendor`, `product`, `odm`, `boot`, and `dtbo`; it does not access `userdata`, `factory`, `param`, or `tee`. The LineageOS common tree and `tools/extract-utils` must be synchronized before running it.
4. Build:

   ```
   lunch lineage_franklin-userdebug
   mka bacon
   ```
    The result of this build still requires review on the device before it can be considered functional.

 ## Extraction and privacy

 The `extract-files.sh` wrapper requires a local partition directory; it rejects direct extraction through `adb`. Before running the common extractor, `scripts/with_pruned_proprietary_lists.py` filters out blobs missing from Franklin (for example, packages specific to ADT-3) and automatically excludes DRM/HDCP provisioning material.

 It restores the upstream lists after completion, and the `setup-makefiles.sh` wrapper filters again against the blobs that were actually extracted.

 The following are intentionally omitted:

 - `odm/etc/firmware/firmware.le`
- Private PlayReady files (`bgroupcert.dat`, `zgpriv*.dat`)
- `tee_hdcp`
- `tee_key_inject`
- The PlayReady service

 Do not publish the generated `vendor/` directory.

 Due to these omissions and the lack of hardware testing, HDCP/PlayReady/protected-level Widevine functionality is not guaranteed.

 Keep the factory partitions containing provisioning material on the device; do not include them in the repository or ZIP.

 ## Risks before any flashing

 1. **Pending `dt` partition:** The stock AVB descriptor references `dt`, but there is no dump of that partition. `dt.PARTITION` is built as an auxiliary artifact, but it is not included in `INSTALLED_RADIOIMAGE_TARGET`.
    Do not flash `dt` until an actual dump of `dt` has been obtained and compared and the partition table/AVB configuration has been verified.
2. **AVB/bootloader:** The Amlogic common tree uses test keys for unlockable builds. The bootloader's unlock state and the AVB policy it enforces are unknown.
    Keep a complete backup of all partitions and a tested recovery method.
3. **Old proprietary kernel:** The vendor modules are for the stock 4.9.269 kernel and are not compiled from source. Compatibility with changes in the Android 12L branch, as well as modern security support, is not guaranteed.
4. **No boot testing:** Wi-Fi, Bluetooth, audio, HDMI/CEC, decoding, tuner functionality, and recovery still require functional testing and review of `dmesg`, `logcat`, VINTF, and SELinux.
5. **Inferred sizes:** The size of `dt` was not observed; `BOARD_DTBIMAGE_PARTITION_SIZE` inherits 262,144 bytes from the common Amlogic tree.
    The userdata size also inherits the common value because `userdata` was not included in the dump.

 ## Local prebuilt verification

 From this device directory:

```
sha256sum -c prebuilt/SHA256SUMS
```

 The `g12a_u212_mtk` FDT selection comes from the value reported by U-Boot; it must not be replaced with the Wade DTB or a generic U212 DTB without validating GPIOs and peripherals.

```

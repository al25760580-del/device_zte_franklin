# Stock prebuilts

Only these binaries are inputs to the ROM build:

- `Image.gz`: gzip-compressed Linux ARM64 4.9.269 kernel from the stock boot image.
- `aml-dtb-multi.img`: stock second/DTB section, containing the `g12a_u212_2g` and `g12a_u212_mtk` FDTs.
- `dtbo.payload.img`: the 438-byte Android DTBO payload before stock partition padding.

The individual `.dtb` files are references for inspection. `dtbo_dummy_battery_charger.dtb` is the sole stock overlay payload, not an independently flashable image. Full stock `boot_partition.img` and the padded 8 MiB `dtbo.img` are intentionally not included.

Verify files with `sha256sum -c SHA256SUMS` from this directory.

# Diagnostic DT source files

These `.dts` files were decompiled from Franklin's stock FDTs/DTBO with `dtc` 1.7.2. They preserve the stock hardware description for review; they are **not** inputs to this device tree's build. The build reuses the unmodified stock multi-DTB bundle in `../prebuilt/aml-dtb-multi.img`.

The active U-Boot selection is `g12a_u212_mtk`. The alternate `g12a_u212_2g` variant differs in board GPIO configuration. `dtc` emits unit-address/naming warnings when decompiling these vendor trees; a successful round-trip was checked, but no source-level cleanup or kernel rebuild was performed.

The checked decompilation contained no obvious serial-number or MAC-address values. The `usid` and `deviceid` text found in it names key lookup nodes; no key values are present in the included DTS files.

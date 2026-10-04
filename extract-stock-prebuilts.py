#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Extract only the stock kernel, multi-DTB, and DTBO payload from a dump.

No ramdisk, userdata, factory, param, tee, or per-device provisioning files
are copied. The generated artifacts are the prebuilts consumed by this tree.
"""
from __future__ import annotations

import gzip
import hashlib
from pathlib import Path
import struct
import sys

BOOT_MAGIC = b"ANDROID!"
FDT_MAGIC = b"\xd0\x0d\xfe\xed"
DTBO_MAGIC = 0xD7B7AB1E
PAGE_SIZE_EXPECTED = 2048


def align(value: int, alignment: int) -> int:
    return (value + alignment - 1) // alignment * alignment


def fdt_blobs(data: bytes) -> list[tuple[int, bytes]]:
    found: list[tuple[int, bytes]] = []
    search = 0
    while True:
        offset = data.find(FDT_MAGIC, search)
        if offset < 0:
            break
        if offset + 8 <= len(data):
            size = struct.unpack_from(">I", data, offset + 4)[0]
            if 40 <= size <= len(data) - offset:
                blob = data[offset:offset + size]
                found.append((offset, blob))
                search = offset + size
                continue
        search = offset + 1
    return found


def board_id(blob: bytes) -> str:
    for label in (b"g12a_u212_mtk", b"g12a_u212_2g"):
        if label in blob:
            return label.decode("ascii")
    printable = bytes(c if 32 <= c < 127 else 32 for c in blob)
    for prefix in (b"g12a_u212_",):
        start = printable.find(prefix)
        if start >= 0:
            end = start
            while end < len(printable) and (printable[end:end + 1].isalnum() or printable[end] in b"_.-"):
                end += 1
            return printable[start:end].decode("ascii", errors="replace")
    return "unknown"


def write_hashes(directory: Path, names: list[str]) -> None:
    lines = []
    for name in names:
        digest = hashlib.sha256((directory / name).read_bytes()).hexdigest()
        lines.append(f"{digest}  {name}")
    (directory / "SHA256SUMS").write_text("\n".join(lines) + "\n", encoding="ascii")


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(f"Usage: {sys.argv[0]} <stock-dump-directory> [prebuilt-output-directory]", file=sys.stderr)
        return 2

    dump = Path(sys.argv[1]).expanduser().resolve()
    output = Path(sys.argv[2]).expanduser().resolve() if len(sys.argv) == 3 else Path(__file__).resolve().parent / "prebuilt"
    boot_path = dump / "boot_partition.img"
    if not boot_path.exists():
        boot_path = dump / "boot.img"
    dtbo_path = dump / "dtbo.img"
    if not boot_path.is_file() or not dtbo_path.is_file():
        raise SystemExit("Need boot_partition.img (or boot.img) and dtbo.img in the dump directory")

    boot = boot_path.read_bytes()
    if not boot.startswith(BOOT_MAGIC) or len(boot) < 1660:
        raise SystemExit("Not a valid Android boot image")

    kernel_size, = struct.unpack_from("<I", boot, 8)
    ramdisk_size, = struct.unpack_from("<I", boot, 16)
    second_size, = struct.unpack_from("<I", boot, 24)
    page_size, = struct.unpack_from("<I", boot, 36)
    header_version, = struct.unpack_from("<I", boot, 40)
    if page_size != PAGE_SIZE_EXPECTED or header_version != 2:
        raise SystemExit(f"Unexpected boot header: page={page_size}, version={header_version}")

    kernel_offset = page_size
    ramdisk_offset = kernel_offset + align(kernel_size, page_size)
    second_offset = ramdisk_offset + align(ramdisk_size, page_size)
    kernel = boot[kernel_offset:kernel_offset + kernel_size]
    second = boot[second_offset:second_offset + second_size]
    if len(kernel) != kernel_size or len(second) != second_size:
        raise SystemExit("Boot component extends beyond the supplied boot image")
    if not kernel.startswith(b"\x1f\x8b"):
        raise SystemExit("Stock kernel is not gzip-compressed as expected")
    try:
        uncompressed = gzip.decompress(kernel)
    except OSError as exc:
        raise SystemExit(f"Stock kernel gzip data is corrupt: {exc}") from exc
    if b"Linux version 4.9.269" not in uncompressed:
        print("Warning: kernel version string was not found in the decompressed image", file=sys.stderr)

    dtbo = dtbo_path.read_bytes()
    if len(dtbo) < 32:
        raise SystemExit("DTBO image is too short")
    magic, total_size, header_size, entry_size, entry_count, entries_offset, _, _ = struct.unpack_from(">8I", dtbo, 0)
    if magic != DTBO_MAGIC or total_size > len(dtbo) or total_size < header_size:
        raise SystemExit("Invalid Android DTBO image header")
    if entries_offset + entry_size * entry_count > total_size:
        raise SystemExit("DTBO entry table exceeds the declared payload")
    dtbo_entries: list[bytes] = []
    for index in range(entry_count):
        entry_offset = entries_offset + index * entry_size
        image_size, image_offset = struct.unpack_from(">II", dtbo, entry_offset)
        if image_offset + image_size > total_size:
            raise SystemExit(f"DTBO overlay {index} exceeds the declared payload")
        overlay = dtbo[image_offset:image_offset + image_size]
        if not overlay.startswith(FDT_MAGIC):
            raise SystemExit(f"DTBO entry {index} is not an FDT blob")
        dtbo_entries.append(overlay)

    fdt_entries = fdt_blobs(second)
    if not fdt_entries:
        raise SystemExit("No FDT blobs found in the boot image second/Dtb section")
    identified = [(offset, blob, board_id(blob)) for offset, blob in fdt_entries]
    if not any(name == "g12a_u212_mtk" for _, _, name in identified):
        raise SystemExit("Stock boot DTB bundle has no g12a_u212_mtk Franklin variant")

    output.mkdir(parents=True, exist_ok=True)
    (output / "Image.gz").write_bytes(kernel)
    (output / "aml-dtb-multi.img").write_bytes(second)
    (output / "dtbo.payload.img").write_bytes(dtbo[:total_size])

    names = []
    for _, blob, name in identified:
        safe_name = name.replace("/", "_")
        target = f"{safe_name}.dtb"
        if target in names:
            target = f"{safe_name}-{len(names)}.dtb"
        (output / target).write_bytes(blob)
        names.append(target)
    for index, overlay in enumerate(dtbo_entries):
        target = "dtbo_dummy_battery_charger.dtb" if entry_count == 1 else f"dtbo_overlay_{index}.dtb"
        (output / target).write_bytes(overlay)
        names.append(target)
    write_hashes(output, ["Image.gz", "aml-dtb-multi.img", "dtbo.payload.img", *names])

    print(f"Boot header v{header_version}, page {page_size}; kernel {kernel_size} bytes; second/DTB {second_size} bytes")
    print(f"DTBO payload {total_size} bytes, {entry_count} overlay entr{'y' if entry_count == 1 else 'ies'}")
    for offset, blob, name in identified:
        print(f"FDT {name}: second offset 0x{offset:x}, {len(blob)} bytes")
    print(f"Prebuilts written to: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

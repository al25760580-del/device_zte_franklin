#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Temporarily prune Lineage/Amlogic blob lists while extracting/generating.

This prevents missing ADT-3-only blobs from becoming dangling Soong sources,
and excludes device-provisioned DRM/HDCP material even when the stock dump has
those paths. Original upstream list files are restored in a finally block.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import sys

SENSITIVE = {
    "odm/etc/firmware/firmware.le",
    "vendor/etc/drm/playready/bgroupcert.dat",
    "vendor/etc/drm/playready/zgpriv.dat",
    "vendor/etc/drm/playready/zgpriv_protected.dat",
    "vendor/bin/tee_hdcp",
    "vendor/bin/tee_key_inject",
    "vendor/bin/hdcp_tx22",
    "vendor/etc/init/tee_hdcp.rc",
    "vendor/etc/init/tee_key_inject.rc",
    "vendor/etc/init/android.hardware.drm@1.4-service.playready.rc",
    "vendor/bin/hw/android.hardware.drm@1.4-service.playready",
    "vendor/lib/libplayready.so",
    "vendor/lib/libplayreadymediadrmplugin.so",
    "vendor/etc/vintf/manifest/manifest_android.hardware.drm@1.4-service.playready.xml",
}


def normalize(path: str) -> str:
    return path.strip().lstrip("/")


def split_spec(line: str) -> tuple[str, str]:
    spec = line.strip().split("|", 1)[0].split(";", 1)[0]
    if spec.startswith("-"):
        spec = spec[1:]
    if ":" in spec:
        src, dst = spec.split(":", 1)
    else:
        src = dst = spec
    return normalize(src), normalize(dst)


def source_exists(root: Path, path: str) -> bool:
    """Approximate extract-utils' local-source fallbacks for a path."""
    p = normalize(path)
    candidates = [root / p]
    if p.startswith("system/"):
        candidates.append(root / p[len("system/"):])
    else:
        candidates.append(root / "system" / p)
    # The AOSP helper also tries a system/ prefix and a stripped /system prefix.
    candidates.append(root / "system" / p.lstrip("/"))
    return any(candidate.exists() or candidate.is_symlink() for candidate in candidates)


def vendor_exists(root: Path, path: str) -> bool:
    p = normalize(path)
    candidate = root / p
    return candidate.exists() or candidate.is_symlink()


def is_sensitive(src: str, dst: str) -> bool:
    return normalize(src) in SENSITIVE or normalize(dst) in SENSITIVE


def list_files(android_root: Path) -> list[Path]:
    common = android_root / "device/amlogic/g12-common"
    device = android_root / "device/zte/franklin"
    return [
        common / "proprietary-files.txt",
        common / "proprietary-files-atv.txt",
        common / "proprietary-files-tee.txt",
        device / "proprietary-files.txt",
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path,
                        help="sanitized extracted system/vendor/product/odm root")
    parser.add_argument("--vendor-root-common", type=Path,
                        help="generated vendor/amlogic/g12-common/proprietary root")
    parser.add_argument("--vendor-root-device", type=Path,
                        help="generated vendor/zte/franklin/proprietary root")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    if not args.command:
        parser.error("a command must follow --")
    command = args.command[1:] if args.command[0] == "--" else args.command
    if not command:
        parser.error("a command must follow --")

    script_dir = Path(__file__).resolve().parent
    device_dir = script_dir.parent
    android_root = device_dir.parents[2]
    if not (android_root / "device/amlogic/g12-common").is_dir():
        parser.error(f"Amlogic common tree not found under {android_root}")

    lists = list_files(android_root)
    backups: dict[Path, str] = {}
    dropped_missing = 0
    dropped_sensitive = 0

    try:
        for path in lists:
            if not path.is_file():
                continue
            original = path.read_text(encoding="utf-8")
            backups[path] = original
            is_device_list = path == android_root / "device/zte/franklin/proprietary-files.txt"
            if args.source_root:
                root = args.source_root.resolve()
                exists = lambda dst: source_exists(root, dst)
            else:
                vendor_root = args.vendor_root_device if is_device_list else args.vendor_root_common
                if vendor_root is None:
                    parser.error("provide --source-root or both vendor-root arguments")
                root = vendor_root.resolve()
                exists = lambda dst: vendor_exists(root, dst)

            kept: list[str] = []
            for line in original.splitlines(keepends=True):
                stripped = line.strip()
                if not stripped or stripped.startswith("#"):
                    kept.append(line)
                    continue
                src, dst = split_spec(line)
                if is_sensitive(src, dst):
                    dropped_sensitive += 1
                    continue
                # For a source tree, either source or destination may be pulled;
                # after extraction, only the destination is present in vendor/.
                present = ((source_exists(root, src) or source_exists(root, dst))
                           if args.source_root else exists(dst))
                if not present:
                    dropped_missing += 1
                    continue
                kept.append(line)
            path.write_text("".join(kept), encoding="utf-8")

        result = subprocess.run(command, check=False)
        return result.returncode
    finally:
        for path, original in backups.items():
            path.write_text(original, encoding="utf-8")
        if backups:
            print(
                f"[franklin] temporarily pruned blob lists: "
                f"{dropped_missing} missing, {dropped_sensitive} sensitive entries; "
                "original list files restored",
                file=sys.stderr,
            )


if __name__ == "__main__":
    raise SystemExit(main())

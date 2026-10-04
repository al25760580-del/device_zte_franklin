#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Safely extract the Franklin stock dump for LineageOS blob generation.
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /path/to/B820C-A15_stock_dump" >&2
    exit 2
fi

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_ROOT="$(cd "$MY_DIR/../../.." && pwd)"
DUMP_DIR="$(cd "$1" && pwd)"

for f in super.img dtbo.img; do
    [[ -f "$DUMP_DIR/$f" ]] || { echo "Missing $DUMP_DIR/$f" >&2; exit 2; }
done
[[ -f "$DUMP_DIR/boot_partition.img" || -f "$DUMP_DIR/boot.img" ]] || {
    echo "Missing boot_partition.img (or boot.img) in $DUMP_DIR" >&2
    exit 2
}
[[ -d "$ANDROID_ROOT/device/amlogic/g12-common" ]] || {
    echo "Run this inside a synced LineageOS 19.1 source tree with device/amlogic/g12-common present." >&2
    exit 2
}

LPUNPACK="$(command -v lpunpack || true)"
if [[ -z "$LPUNPACK" && -x "$ANDROID_ROOT/prebuilts/extract-tools/linux-x86/bin/lpunpack" ]]; then
    LPUNPACK="$ANDROID_ROOT/prebuilts/extract-tools/linux-x86/bin/lpunpack"
fi
[[ -n "$LPUNPACK" ]] || { echo "lpunpack is required (or sync Lineage extract-tools)." >&2; exit 2; }
command -v debugfs >/dev/null 2>&1 || { echo "debugfs is required (e2fsprogs)." >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required." >&2; exit 2; }

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/franklin-extract.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
mkdir -p "$TMP_ROOT/parts" "$TMP_ROOT/source"

# Extract only logical partitions. userdata, factory, param, tee and other
# physical/provisioning partitions are deliberately never opened here.
for part in system vendor product odm; do
    echo "[franklin] unpacking $part from super.img"
    "$LPUNPACK" -p "$part" "$DUMP_DIR/super.img" "$TMP_ROOT/parts"
    image="$TMP_ROOT/parts/$part.img"
    [[ -f "$image" ]] || { echo "lpunpack did not produce $image" >&2; exit 1; }
    mkdir -p "$TMP_ROOT/source/$part"
    debugfs -R "rdump / $TMP_ROOT/source/$part" "$image" >/dev/null 2>&1
 done

# Provisioned HDCP/DRM material is not needed for the base ROM and must not be
# copied into the workspace/vendor tree. The generated product makefiles also
# filter these common-list entries as a second safeguard.
rm -f \
    "$TMP_ROOT/source/odm/etc/firmware/firmware.le" \
    "$TMP_ROOT/source/vendor/etc/drm/playready/bgroupcert.dat" \
    "$TMP_ROOT/source/vendor/etc/drm/playready/zgpriv.dat" \
    "$TMP_ROOT/source/vendor/etc/drm/playready/zgpriv_protected.dat" \
    "$TMP_ROOT/source/vendor/bin/tee_hdcp" \
    "$TMP_ROOT/source/vendor/bin/tee_key_inject" \
    "$TMP_ROOT/source/vendor/bin/hdcp_tx22" \
    "$TMP_ROOT/source/vendor/etc/init/tee_hdcp.rc" \
    "$TMP_ROOT/source/vendor/etc/init/tee_key_inject.rc" \
    "$TMP_ROOT/source/vendor/etc/init/android.hardware.drm@1.4-service.playready.rc" \
    "$TMP_ROOT/source/vendor/bin/hw/android.hardware.drm@1.4-service.playready" \
    "$TMP_ROOT/source/vendor/lib/libplayready.so" \
    "$TMP_ROOT/source/vendor/lib/libplayreadymediadrmplugin.so" \
    "$TMP_ROOT/source/vendor/etc/vintf/manifest/manifest_android.hardware.drm@1.4-service.playready.xml"

echo "[franklin] extracting stock kernel/DTB/DTBO prebuilts"
python3 "$MY_DIR/extract-stock-prebuilts.py" "$DUMP_DIR" "$MY_DIR/prebuilt"

echo "[franklin] extracting only present, non-provisioning vendor blobs"
"$MY_DIR/extract-files.sh" "$TMP_ROOT/source"

echo "[franklin] done. Generated vendor files live in vendor/amlogic/g12-common and vendor/zte/franklin."
echo "[franklin] sensitive provisioning files were omitted; see README.md for DRM/HDCP limits."

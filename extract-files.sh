#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

# When sourced by the Amlogic common extractor, do not recurse.
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return
fi

set -euo pipefail
MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_ROOT="$(cd "$MY_DIR/../../.." && pwd)"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <sanitized-extracted-partitions-root> [common extract options]" >&2
    echo "Use extract-stock-dump.sh for a stock super/boot/dtbo dump." >&2
    exit 2
fi

# The final argument is the local source root (extract-stock-dump.sh always
# supplies it). Refuse direct adb extraction so provisioned key blobs cannot
# accidentally be copied into a build tree.
SRC_ARG="${!#}"
if [[ "$SRC_ARG" == "adb" || ! -d "$SRC_ARG" ]]; then
    echo "A local extracted source directory is required; direct adb extraction is disabled." >&2
    exit 2
fi
if command -v realpath >/dev/null 2>&1; then
    SRC_ROOT="$(realpath "$SRC_ARG")"
else
    SRC_ROOT="$(cd "$SRC_ARG" && pwd)"
fi
ARGS=("$@")
ARGS[$(( ${#ARGS[@]} - 1 ))]="$SRC_ROOT"

export DEVICE=franklin
export DEVICE_COMMON=g12-common
export VENDOR_COMMON=amlogic
export VENDOR_DEVICE=zte

python3 "$MY_DIR/scripts/with_pruned_proprietary_lists.py" \
    --source-root "$SRC_ROOT" -- \
    "$ANDROID_ROOT/device/amlogic/g12-common/extract-files.sh" "${ARGS[@]}"

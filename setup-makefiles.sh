#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_ROOT="$(cd "$MY_DIR/../../.." && pwd)"

export DEVICE=franklin
export DEVICE_COMMON=g12-common
export VENDOR_COMMON=amlogic
export VENDOR_DEVICE=zte

COMMON_BLOBS="$ANDROID_ROOT/vendor/amlogic/g12-common/proprietary"
DEVICE_BLOBS="$ANDROID_ROOT/vendor/zte/franklin/proprietary"
if [[ ! -d "$COMMON_BLOBS" || ! -d "$DEVICE_BLOBS" ]]; then
    echo "Vendor blobs not found. Run device/zte/franklin/extract-stock-dump.sh first." >&2
    exit 2
fi

python3 "$MY_DIR/scripts/with_pruned_proprietary_lists.py" \
    --vendor-root-common "$COMMON_BLOBS" \
    --vendor-root-device "$DEVICE_BLOBS" -- \
    "$ANDROID_ROOT/device/amlogic/g12-common/setup-makefiles.sh" "$@"

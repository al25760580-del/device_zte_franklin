# SPDX-License-Identifier: Apache-2.0
# The stock DTBO header and its sole overlay are already built; reuse the
# unpadded 438-byte payload and let the Android AVB rules add the footer.

DTBO_SOURCE := $(DEVICE_PATH)/prebuilt/dtbo.payload.img

$(BOARD_PREBUILT_DTBOIMAGE): $(INSTALLED_KERNEL_TARGET) $(DTBO_SOURCE) | $(ACP)
	$(hide) $(ACP) $(DTBO_SOURCE) $@

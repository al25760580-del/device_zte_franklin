# SPDX-License-Identifier: Apache-2.0
# Package the complete stock Amlogic multi-DTB bundle; no kernel source is used.

DTB_SOURCE := $(DEVICE_PATH)/prebuilt/aml-dtb-multi.img
TARGET_FLASH_DTB_PARTITION ?= false
INSTALLED_DTBIMAGE_PARTITION_TARGET := $(PRODUCT_OUT)/dt.PARTITION
DTB_PARTITION_NAME := dt

$(INSTALLED_DTBIMAGE_TARGET): $(INSTALLED_KERNEL_TARGET) $(DTB_SOURCE) | $(ACP)
	$(hide) $(ACP) $(DTB_SOURCE) $@

$(INSTALLED_DTBIMAGE_PARTITION_TARGET): $(INSTALLED_DTBIMAGE_TARGET) $(AVBTOOL)
	$(hide) $(ACP) $(INSTALLED_DTBIMAGE_TARGET) $@
	$(hide) $(AVBTOOL) add_hash_footer \
		--image $@ \
		--partition_size $(BOARD_DTBIMAGE_PARTITION_SIZE) \
		--partition_name $(DTB_PARTITION_NAME)

ifeq ($(TARGET_FLASH_DTB_PARTITION),true)
INSTALLED_RADIOIMAGE_TARGET += $(INSTALLED_DTBIMAGE_TARGET)
endif

# SPDX-License-Identifier: Apache-2.0
# Device configuration for ZTE / IZZI B820C-A15 (franklin).

DEVICE_PATH := device/zte/franklin
TARGET_BOOTLOADER_BOARD_NAME := franklin
TARGET_KERNEL_VERSION := 4.9
TARGET_AMLOGIC_SOC := g12a
TARGET_HAS_TEE := true
BOARD_HAVE_BLUETOOTH := true

# super size must be set before the common tree computes the dynamic group.
BOARD_SUPER_PARTITION_SIZE := 1887436800

include device/amlogic/g12-common/BoardConfigCommon.mk

# BoardConfigAmlogic.mk supplies reference-box sizes; restore Franklin's sizes.
BOARD_BOOTIMAGE_PARTITION_SIZE := 16777216
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 25165824
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_CACHEIMAGE_PARTITION_SIZE := 1048576000
BOARD_METADATAIMAGE_PARTITION_SIZE := 16777216
# Not measured: inherited Amlogic 4.9 default; do not flash this guessed dt image.
BOARD_DTBIMAGE_PARTITION_SIZE := 262144

# Stock vendor was built against Android 12's VNDK/API 31.
BOARD_VNDK_VERSION := 31

# Stock build fingerprint reports the vendor security patch level below.
VENDOR_SECURITY_PATCH := 2024-11-01

# The stock kernel is 64-bit Linux 4.9.269; userspace is 32-bit ARM.
# No kernel source was provided, so do not try to compile the common kernel.
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/Image.gz
TARGET_KERNEL_SOURCE :=
TARGET_KERNEL_CONFIG :=
TARGET_KERNEL_VARIANT_CONFIG :=
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_VERSION := 4.9
BOARD_KERNEL_IMAGE_NAME := Image.gz

# Use the stock Amlogic multi-DTB bundle and stock DTBO payload.
BOARD_CUSTOM_DTBIMG_MK := $(DEVICE_PATH)/mkdtbimg-prebuilt.mk
BOARD_CUSTOM_DTBOIMG_MK := $(DEVICE_PATH)/mkdtboimg-prebuilt.mk
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
TARGET_NEEDS_DTBOIMAGE := true

# The stock vbmeta descriptor names a separate "dt" partition, but that
# partition was not present in the supplied dump. Keep it untouched; the
# stock multi-DTB is still included in boot.img. Do not publish dt as a radio
# image until that partition has been independently dumped and compared.
TARGET_FLASH_DTB_PARTITION := false

# Preserve Amlogic's kernel/ramdisk offsets and header-v2 settings from the
# common BoardConfig. Match the stock boot command line where it is known.
BOARD_KERNEL_CMDLINE := androidboot.dynamic_partitions=true androidboot.boot_devices=ffe07000.emmc androidboot.dtbo_idx=0 use_uvm=1 hdr_policy=1 otg_device=1

# Franklin-specific properties, appended to the Amlogic common property files.
TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

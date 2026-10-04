# SPDX-License-Identifier: Apache-2.0

$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, vendor/lineage/config/common_full_tv.mk)
$(call inherit-product, device/zte/franklin/device.mk)

PRODUCT_NAME := lineage_franklin
PRODUCT_DEVICE := franklin
PRODUCT_BRAND := IZZI
PRODUCT_MODEL := B820C-A15
PRODUCT_MANUFACTURER := ZTE
PRODUCT_RELEASE_NAME := franklin
PRODUCT_IS_ATV := true
PRODUCT_CHARACTERISTICS := tv,nosdcard

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=B820C-A15_ZTE \
    TARGET_DEVICE=B820C-A15_ZTE

# Keep the stock vendor-facing identity for framework/vendor compatibility.
BUILD_FINGERPRINT := IZZI/B820C-A15_ZTE/B820C-A15_ZTE:12/SC/V83511301.2070:user/release-keys

# OTA package assertions. This device is not A/B.
TARGET_OTA_ASSERT_DEVICE := franklin,B820C-A15_ZTE

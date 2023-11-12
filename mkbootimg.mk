#
# Copyright (C) 2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

BOOT_SIGNER := $(HOST_OUT_EXECUTABLES)/boot_signer

VERITY_KEYS := $(LOCAL_PATH)/tools/verity.pk8 \
               $(LOCAL_PATH)/tools/verity.x509.pem

## Boot Image Generation
$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES) $(INSTALLED_KERNEL_TARGET) $(BOOT_SIGNER)
	$(call pretty,"Target boot image from recovery: $@")
	$(call build-recoveryimage-target, $@, $(PRODUCT_OUT)/$(subst .img,,$(subst boot,kernel,$(notdir $@))))
	$(BOOT_SIGNER) /boot $@ $(VERITY_KEYS) $@
	$(hide) $(call assert-max-image-size,$@,$(BOARD_BOOTIMAGE_PARTITION_SIZE),raw)
	@echo "Made boot image: $@"

#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=
ONLY_TARGET=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-common )
                ONLY_COMMON=true
                ;;
        --only-target )
                ONLY_TARGET=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"
                shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        system_ext/etc/permissions/vendor.qti.hardware.data.connection-V1.0-java.xml | system_ext/etc/permissions/vendor.qti.hardware.data.connection-V1.1-java.xml)
        # Fix xml version
            [ "$2" = "" ] && return 0
            sed -i 's|xml version="2.0"|xml version="1.0"|g' "${2}"
        # Move telephony packages to /system_ext
            [ "$2" = "" ] && return 0
            sed -i 's|product|system_ext|g' "${2}"
            ;;
        # Fix missing symbols
        system_ext/lib64/lib-imscamera.so | system_ext/lib64/lib-imsvideocodec.so | system_ext/lib/lib-imscamera.so | system_ext/lib/lib-imsvideocodec.so)
            [ "$2" = "" ] && return 0
            grep -q "libgui_shim.so" "${2}" || "${PATCHELF}" --add-needed "libgui_shim.so" "${2}"
            ;;
        # memset shim
        vendor/bin/charge_only_mode)
            [ "$2" = "" ] && return 0
            grep -q "libmemset_shim.so" "${2}" || "${PATCHELF}" --add-needed "libmemset_shim.so" "${2}"
            ;;
        vendor/bin/pm-service)
            [ "$2" = "" ] && return 0
            grep -q libutils-v33.so "${2}" || "${PATCHELF}" --add-needed "libutils-v33.so" "${2}"
            ;;
        # Fix missing symbols
        vendor/lib/libmot_gpu_mapper.so)
            [ "$2" = "" ] && return 0
            grep -q "libgui_shim_vendor.so" "${2}" || "${PATCHELF}" --add-needed "libgui_shim_vendor.so" "${2}"
            ;;
        # Load wrapped shim
        vendor/lib64/libmdmcutback.so)
            [ "$2" = "" ] && return 0
             "${PATCHELF}" --replace-needed "libqsap_sdk.so" "libqsap_shim.so" "${2}"
            ;;
        # Fix missing symbols
        vendor/lib64/libril-qc-hal-qmi.so)
            [ "$2" = "" ] && return 0
            grep -q "libcutils_shim.so" "${2}" || "${PATCHELF}" --add-needed "libcutils_shim.so" "${2}"
            ;;
        system_ext/etc/permissions/com.qualcomm.qti.imscmservice-V2.0-java.xml | system_ext/etc/permissions/com.qualcomm.qti.imscmservice-V2.1-java.xml | system_ext/etc/permissions/com.qualcomm.qti.imscmservice-V2.2-java.xml | system_ext/etc/permissions/qcrilhook.xml | system_ext/etc/permissions/telephonyservice.xml)
        # Move telephony packages to /system_ext
            [ "$2" = "" ] && return 0
            sed -i 's|product|system_ext|g' "${2}"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

function blob_fixup_dry() {
    blob_fixup "$1" ""
}

if [ -z "${ONLY_TARGET}" ]; then
    # Initialize the helper for common device
    setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/../${DEVICE}/setup-makefiles.sh"

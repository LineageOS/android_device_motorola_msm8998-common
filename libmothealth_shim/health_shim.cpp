/*
 * SPDX-FileCopyrightText: The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * libmothealth_shim: minimal android.hardware.health@2.0::IHealth for
 * motorola.hardware.health@1.0-service.
 *
 * The Motorola blob calls IHealth::getService() (HIDL health 2.0) without a
 * null check and then IHealth::getCapacity() while reading the mod battery
 * (MotHealth::getModBatteryProperties). LineageOS now ships the AIDL health
 * HAL only, so getService() returns nullptr and the blob crashes whenever a
 * battery mod (e.g. JBL SoundBoost) is attached, leaving mod_level at -1.
 *
 * This shim interposes IHealth::getService() and returns an in-process
 * object whose getCapacity() reads the main battery capacity from sysfs.
 * Every other method reports NOT_SUPPORTED.
 */
#define LOG_TAG "mothealth_shim"

#include <android/hardware/health/2.0/IHealth.h>
#include <log/log.h>

#include <fstream>
#include <string>

using ::android::sp;
using ::android::hardware::hidl_handle;
using ::android::hardware::hidl_string;
using ::android::hardware::hidl_vec;
using ::android::hardware::Return;
using ::android::hardware::Void;
using ::android::hardware::health::V2_0::DiskStats;
using ::android::hardware::health::V2_0::HealthInfo;
using ::android::hardware::health::V2_0::IHealth;
using ::android::hardware::health::V2_0::IHealthInfoCallback;
using ::android::hardware::health::V2_0::Result;
using ::android::hardware::health::V2_0::StorageInfo;
using ::android::hardware::health::V1_0::BatteryStatus;

namespace {

constexpr char kCapacityPath[] = "/sys/class/power_supply/battery/capacity";

class HealthShim : public IHealth {
  public:
    Return<Result> registerCallback(const sp<IHealthInfoCallback>&) override {
        return Result::NOT_SUPPORTED;
    }
    Return<Result> unregisterCallback(const sp<IHealthInfoCallback>&) override {
        return Result::NOT_SUPPORTED;
    }
    Return<Result> update() override { return Result::NOT_SUPPORTED; }

    Return<void> getChargeCounter(getChargeCounter_cb cb) override {
        cb(Result::NOT_SUPPORTED, 0);
        return Void();
    }
    Return<void> getCurrentNow(getCurrentNow_cb cb) override {
        cb(Result::NOT_SUPPORTED, 0);
        return Void();
    }
    Return<void> getCurrentAverage(getCurrentAverage_cb cb) override {
        cb(Result::NOT_SUPPORTED, 0);
        return Void();
    }

    Return<void> getCapacity(getCapacity_cb cb) override {
        std::ifstream f(kCapacityPath);
        int32_t capacity;
        if (f >> capacity) {
            cb(Result::SUCCESS, capacity);
        } else {
            ALOGE("Failed to read %s", kCapacityPath);
            cb(Result::UNKNOWN, 0);
        }
        return Void();
    }

    Return<void> getEnergyCounter(getEnergyCounter_cb cb) override {
        cb(Result::NOT_SUPPORTED, 0);
        return Void();
    }
    Return<void> getChargeStatus(getChargeStatus_cb cb) override {
        cb(Result::NOT_SUPPORTED, BatteryStatus::UNKNOWN);
        return Void();
    }
    Return<void> getStorageInfo(getStorageInfo_cb cb) override {
        cb(Result::NOT_SUPPORTED, hidl_vec<StorageInfo>());
        return Void();
    }
    Return<void> getDiskStats(getDiskStats_cb cb) override {
        cb(Result::NOT_SUPPORTED, hidl_vec<DiskStats>());
        return Void();
    }
    Return<void> getHealthInfo(getHealthInfo_cb cb) override {
        cb(Result::NOT_SUPPORTED, HealthInfo());
        return Void();
    }
};

}  // namespace

namespace android::hardware::health::V2_0 {

// Interposes the definition from android.hardware.health@2.0.so.
sp<IHealth> IHealth::getService(const std::string& /* serviceName */, bool /* getStub */) {
    static sp<IHealth> instance = new HealthShim();
    return instance;
}

}  // namespace android::hardware::health::V2_0

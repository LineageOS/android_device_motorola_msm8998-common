package msm8998

import (
    "android/soong/android"
)

func init() {
    android.RegisterModuleType("motorola_msm8998_init_library_static", initLibraryFactory)
}

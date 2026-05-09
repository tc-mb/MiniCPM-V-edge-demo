// HarmonyOS port of the Android demo's logging.h. Maps the LOG{v,d,i,w,e}
// macros and the GGML log callback to OpenHarmony hilog so the rest of the
// JNI/NAPI bridge stays untouched.
#pragma once

#include <hilog/log.h>
#include <ggml.h>

#ifndef LOG_TAG
#define LOG_TAG "minicpm-v"
#endif

// 0xC0DE is a generic application domain. If you reserve a Huawei-allocated
// domain ID later, override LOG_DOMAIN at compile time.
#ifndef LOG_DOMAIN
#define LOG_DOMAIN 0xC0DE
#endif

// hilog has no compile-time level switch, but OH_LOG_Print itself is cheap
// when the device-side log filter rejects the entry. Keep parity with the
// Android version's macro names so llama_napi.cpp compiles unchanged.
#define LOGv(...)   ((void) OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, __VA_ARGS__))
#define LOGd(...)   ((void) OH_LOG_Print(LOG_APP, LOG_DEBUG, LOG_DOMAIN, LOG_TAG, __VA_ARGS__))
#define LOGi(...)   ((void) OH_LOG_Print(LOG_APP, LOG_INFO,  LOG_DOMAIN, LOG_TAG, __VA_ARGS__))
#define LOGw(...)   ((void) OH_LOG_Print(LOG_APP, LOG_WARN,  LOG_DOMAIN, LOG_TAG, __VA_ARGS__))
#define LOGe(...)   ((void) OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, __VA_ARGS__))

static inline LogLevel hilog_level_from_ggml(enum ggml_log_level level) {
    switch (level) {
        case GGML_LOG_LEVEL_ERROR: return LOG_ERROR;
        case GGML_LOG_LEVEL_WARN:  return LOG_WARN;
        case GGML_LOG_LEVEL_INFO:  return LOG_INFO;
        case GGML_LOG_LEVEL_DEBUG: return LOG_DEBUG;
        default:                   return LOG_INFO;
    }
}

static inline void minicpm_hilog_callback(enum ggml_log_level level,
                                          const char *text,
                                          void * /*user*/) {
    OH_LOG_Print(LOG_APP, hilog_level_from_ggml(level), LOG_DOMAIN, LOG_TAG, "%{public}s", text);
}

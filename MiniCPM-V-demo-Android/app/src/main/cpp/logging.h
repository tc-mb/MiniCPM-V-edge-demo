#pragma once
#include <android/log.h>
#include <ggml.h>

#ifndef LOG_TAG
#define LOG_TAG "minicpm-v"
#endif

#ifndef LOG_MIN_LEVEL
#if defined(NDEBUG)
#define LOG_MIN_LEVEL ANDROID_LOG_INFO
#else
#define LOG_MIN_LEVEL ANDROID_LOG_VERBOSE
#endif
#endif

static inline int minicpm_should_log(int prio) {
#if __ANDROID_API__ >= 30
    // Runtime-configurable threshold (e.g. via `setprop log.tag.minicpm-v VERBOSE`).
    return __android_log_is_loggable(prio, LOG_TAG, LOG_MIN_LEVEL);
#else
    // __android_log_is_loggable was introduced in API 30, so on older
    // platforms fall back to the compile-time threshold.
    return prio >= LOG_MIN_LEVEL ? 1 : 0;
#endif
}

#if LOG_MIN_LEVEL <= ANDROID_LOG_VERBOSE
#define LOGv(...) do { if (minicpm_should_log(ANDROID_LOG_VERBOSE)) __android_log_print(ANDROID_LOG_VERBOSE, LOG_TAG, __VA_ARGS__); } while (0)
#else
#define LOGv(...) ((void)0)
#endif

#if LOG_MIN_LEVEL <= ANDROID_LOG_DEBUG
#define LOGd(...) do { if (minicpm_should_log(ANDROID_LOG_DEBUG)) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__); } while (0)
#else
#define LOGd(...) ((void)0)
#endif

#define LOGi(...)   do { if (minicpm_should_log(ANDROID_LOG_INFO )) __android_log_print(ANDROID_LOG_INFO , LOG_TAG, __VA_ARGS__); } while (0)
#define LOGw(...)   do { if (minicpm_should_log(ANDROID_LOG_WARN )) __android_log_print(ANDROID_LOG_WARN , LOG_TAG, __VA_ARGS__); } while (0)
#define LOGe(...)   do { if (minicpm_should_log(ANDROID_LOG_ERROR)) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__); } while (0)

static inline int android_log_prio_from_ggml(enum ggml_log_level level) {
    switch (level) {
        case GGML_LOG_LEVEL_ERROR: return ANDROID_LOG_ERROR;
        case GGML_LOG_LEVEL_WARN:  return ANDROID_LOG_WARN;
        case GGML_LOG_LEVEL_INFO:  return ANDROID_LOG_INFO;
        case GGML_LOG_LEVEL_DEBUG: return ANDROID_LOG_DEBUG;
        default:                   return ANDROID_LOG_DEFAULT;
    }
}

static inline void minicpm_android_log_callback(enum ggml_log_level level,
                                                const char* text,
                                                void* /*user*/) {
    const int prio = android_log_prio_from_ggml(level);
    if (!minicpm_should_log(prio)) return;
    __android_log_write(prio, LOG_TAG, text);
}

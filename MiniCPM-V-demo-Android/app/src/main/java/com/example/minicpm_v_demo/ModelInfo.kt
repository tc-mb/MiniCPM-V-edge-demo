package com.example.minicpm_v_demo

/**
 * Metadata for a downloadable MiniCPM-V variant.
 *
 * Two download strategies are supported, in priority order:
 *
 * 1. **Direct URL** ([directGgufUrl] / [directMmprojUrl]) — used as-is. This is
 *    how the iOS demo handles MiniCPM-V-4.6 today: the GGUFs are not yet on
 *    HuggingFace, so a temporary OSS link (Huawei Cloud OBS) is used during
 *    the TestFlight period. Whenever both direct URLs are non-null, HF/MS are
 *    skipped entirely.
 *
 * 2. **HuggingFace + ModelScope fallback** ([hfRepo] / [msRepo]) — the
 *    standard path for already-published models such as MiniCPM-V-4.0.
 *    The downloader probes HF first and falls back to ModelScope on failure.
 *
 * When [ggufMd5] / [mmprojMd5] are provided, the downloader verifies the
 * downloaded file's MD5 and deletes + raises on mismatch. Mirrors iOS demo
 * MBV4ModelDownloadManager / MBV46ModelDownloadManager behaviour.
 */
data class ModelInfo(
    val id: String,
    val displayName: String,
    val description: String,
    val ggufFileName: String,
    val mmprojFileName: String,
    val hfRepo: String? = null,
    val msRepo: String? = null,
    val hfBranch: String = "main",
    val msBranch: String = "master",
    val directGgufUrl: String? = null,
    val directMmprojUrl: String? = null,
    val ggufMd5: String? = null,
    val mmprojMd5: String? = null
) {
    val hasDirectUrls: Boolean
        get() = !directGgufUrl.isNullOrBlank() && !directMmprojUrl.isNullOrBlank()

    companion object {
        // Mirrors iOS demo MiniCPMModelConst.swift. Keep the lists in sync so
        // the Android download config doesn't drift from the iOS one.
        private const val V46_OBS_BASE =
            "https://data-transfer-huawei.obs.cn-north-4.myhuaweicloud.com/minicpmv46-instruct"

        val AVAILABLE_MODELS = listOf(
            ModelInfo(
                id = "minicpm-v-4",
                displayName = "MiniCPM-V-4 (Q4_K_M)",
                description = "轻量级多模态模型，支持图文理解 (4.1B)",
                ggufFileName = "ggml-model-Q4_K_M.gguf",
                mmprojFileName = "mmproj-model-f16.gguf",
                hfRepo = "openbmb/MiniCPM-V-4-gguf",
                msRepo = "OpenBMB/MiniCPM-V-4-gguf"
                // No MD5 here on purpose: HF / ModelScope serve via git-LFS
                // which already provides hash-based integrity checks. The
                // iOS demo's MD5 (8fc4cc88...) refers to ggml-model-Q4_0.gguf,
                // which is a different quant from the Q4_K_M we use here.
            ),
            // MiniCPM-V-4.6 instruct: temporary OBS direct link, identical to
            // the iOS demo. The thinking variant is intentionally omitted for
            // now — it still needs more validation before shipping on Android.
            ModelInfo(
                id = "minicpm-v-4_6-instruct",
                displayName = "MiniCPM-V-4.6 instruct (Q4_K_M)",
                description = "新一代多模态模型，支持图文理解 (1.2B)",
                ggufFileName = "minicpmv46-llm-Q4_K_M.gguf",
                mmprojFileName = "mmproj-v46-model-f16.gguf",
                directGgufUrl = "$V46_OBS_BASE/minicpmv46-llm-Q4_K_M.gguf",
                directMmprojUrl = "$V46_OBS_BASE/mmproj-v46-model-f16.gguf",
                // MD5 values copied verbatim from MiniCPMModelConst.swift to
                // guarantee Android pulls the exact same bytes as iOS.
                ggufMd5 = "bd9f90774f0e81c49a22ea6445e9de91",
                mmprojMd5 = "64d56c8cc6bd59b5d94c011eb23ce777"
            )
        )

        val DEFAULT_MODEL = AVAILABLE_MODELS.first()
    }
}

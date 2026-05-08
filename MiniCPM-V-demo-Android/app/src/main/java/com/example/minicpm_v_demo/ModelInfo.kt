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
            // MiniCPM-V-4.6 (release / instruct): direct OBS link, identical
            // to the iOS demo. File names follow the upstream HF naming for
            // the released GGUFs. ID kept as "minicpm-v-4_6-instruct" so the
            // per-model subdirectory layout is unchanged from previous demo
            // builds; LEGACY_FILE_RENAMES handles the old filenames.
            ModelInfo(
                id = "minicpm-v-4_6-instruct",
                displayName = "MiniCPM-V-4.6 (Q4_K_M)",
                description = "新一代多模态模型，支持图文理解 (1.2B)",
                ggufFileName = "MiniCPM-V-4_6-Q4_K_M.gguf",
                mmprojFileName = "mmproj-model-f16.gguf",
                directGgufUrl = "$V46_OBS_BASE/MiniCPM-V-4_6-Q4_K_M.gguf",
                directMmprojUrl = "$V46_OBS_BASE/mmproj-model-f16.gguf",
                // MD5 values must match the OBS objects exactly; keep this
                // constant in sync with MiniCPMModelConst.swift on iOS so
                // both clients fetch the exact same bytes.
                ggufMd5 = "fd778481dd56b6036dd8f9cf7c1519cf",
                // mmproj is converted on the Support-iOS-Demo branch (writes
                // clip.projector_type=merger, which the demo's clip.cpp accepts);
                // the upstream-branch conversion would write minicpmv4_6 and fail to load.
                mmprojMd5 = "aad0d36e43a35412d72ed27a1248c7ef"
            )
        )

        val DEFAULT_MODEL = AVAILABLE_MODELS.first()
    }
}

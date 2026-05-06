package com.example.minicpm_v_demo

data class ModelInfo(
    val id: String,
    val displayName: String,
    val description: String,
    val ggufFileName: String,
    val mmprojFileName: String,
    val hfRepo: String,
    val msRepo: String,
    val hfBranch: String = "main",
    val msBranch: String = "master"
) {
    companion object {
        val AVAILABLE_MODELS = listOf(
            ModelInfo(
                id = "minicpm-v-4",
                displayName = "MiniCPM-V-4 (Q4_K_M)",
                description = "轻量级多模态模型，支持图文理解",
                ggufFileName = "ggml-model-Q4_K_M.gguf",
                mmprojFileName = "mmproj-model-f16.gguf",
                hfRepo = "openbmb/MiniCPM-V-4-gguf",
                msRepo = "OpenBMB/MiniCPM-V-4-gguf"
            )
        )

        val DEFAULT_MODEL = AVAILABLE_MODELS.first()
    }
}

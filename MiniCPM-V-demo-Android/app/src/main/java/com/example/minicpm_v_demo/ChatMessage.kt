package com.example.minicpm_v_demo

import android.graphics.Bitmap

sealed class ChatMessage {
    abstract val id: Long

    data class UserMessage(
        override val id: Long,
        val text: String,
        val imageBitmap: Bitmap? = null,
        val imageInfo: String? = null,
        val isPrefilling: Boolean = false
    ) : ChatMessage()

    data class AiMessage(
        override val id: Long,
        val text: String,
        val isGenerating: Boolean = false
    ) : ChatMessage()

    data class WelcomeCard(
        override val id: Long = 0L
    ) : ChatMessage()
}

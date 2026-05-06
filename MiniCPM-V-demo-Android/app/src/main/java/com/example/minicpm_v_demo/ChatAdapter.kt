package com.example.minicpm_v_demo

import android.graphics.Bitmap
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.google.android.material.progressindicator.LinearProgressIndicator

class ChatAdapter : ListAdapter<ChatMessage, RecyclerView.ViewHolder>(DiffCallback()) {

    companion object {
        private const val TYPE_WELCOME = 0
        private const val TYPE_USER = 1
        private const val TYPE_AI = 2
    }

    private var onSuggestionClick: ((String) -> Unit)? = null
    private var onStopClick: (() -> Unit)? = null

    private var activeAiHolder: AiMessageViewHolder? = null
    private var activeAiId: Long = -1L

    fun setOnSuggestionClick(listener: (String) -> Unit) {
        onSuggestionClick = listener
    }

    fun setOnStopClick(listener: () -> Unit) {
        onStopClick = listener
    }

    fun setActiveAiMessage(id: Long) {
        activeAiId = id
    }

    fun clearActiveAiMessage() {
        activeAiId = -1L
        activeAiHolder = null
    }

    fun updateStreamingText(id: Long, text: String) {
        if (id == activeAiId) {
            activeAiHolder?.updateText(text)
        }
    }

    fun setGeneratingDone(id: Long) {
        if (id == activeAiId) {
            activeAiHolder?.setStopButtonVisible(false)
        }
    }

    override fun getItemViewType(position: Int): Int {
        return when (getItem(position)) {
            is ChatMessage.WelcomeCard -> TYPE_WELCOME
            is ChatMessage.UserMessage -> TYPE_USER
            is ChatMessage.AiMessage -> TYPE_AI
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        return when (viewType) {
            TYPE_WELCOME -> {
                val view = LayoutInflater.from(parent.context)
                    .inflate(R.layout.item_welcome_card, parent, false)
                WelcomeViewHolder(view)
            }
            TYPE_USER -> {
                val view = LayoutInflater.from(parent.context)
                    .inflate(R.layout.item_user_message, parent, false)
                UserMessageViewHolder(view)
            }
            TYPE_AI -> {
                val view = LayoutInflater.from(parent.context)
                    .inflate(R.layout.item_ai_message, parent, false)
                AiMessageViewHolder(view)
            }
            else -> throw IllegalArgumentException("Unknown view type: $viewType")
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        when (val item = getItem(position)) {
            is ChatMessage.WelcomeCard -> (holder as WelcomeViewHolder).bind(item)
            is ChatMessage.UserMessage -> (holder as UserMessageViewHolder).bind(item)
            is ChatMessage.AiMessage -> {
                val aiHolder = holder as AiMessageViewHolder
                aiHolder.bind(item)
                if (item.id == activeAiId) {
                    activeAiHolder = aiHolder
                }
            }
        }
    }

    override fun onViewRecycled(holder: RecyclerView.ViewHolder) {
        if (holder is AiMessageViewHolder && holder == activeAiHolder) {
            activeAiHolder = null
        }
    }

    inner class WelcomeViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val btnSuggestion1: MaterialButton = itemView.findViewById(R.id.btn_suggestion_1)
        private val btnSuggestion2: MaterialButton = itemView.findViewById(R.id.btn_suggestion_2)

        fun bind(item: ChatMessage.WelcomeCard) {
            btnSuggestion1.setOnClickListener {
                onSuggestionClick?.invoke(itemView.context.getString(R.string.suggestion_1))
            }
            btnSuggestion2.setOnClickListener {
                onSuggestionClick?.invoke(itemView.context.getString(R.string.suggestion_2))
            }
        }
    }

    inner class UserMessageViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val tvText: TextView = itemView.findViewById(R.id.tv_user_text)
        private val ivImage: ImageView = itemView.findViewById(R.id.iv_user_image)
        private val tvImageInfo: TextView = itemView.findViewById(R.id.tv_image_info)
        private val progressImage: LinearProgressIndicator = itemView.findViewById(R.id.progress_image)

        fun bind(item: ChatMessage.UserMessage) {
            tvText.text = item.text
            tvText.visibility = if (item.text.isNotBlank()) View.VISIBLE else View.GONE

            if (item.imageBitmap != null) {
                ivImage.setImageBitmap(item.imageBitmap)
                ivImage.visibility = View.VISIBLE
                tvImageInfo.visibility = View.VISIBLE
                tvImageInfo.text = item.imageInfo ?: ""
                progressImage.visibility = if (item.isPrefilling) View.VISIBLE else View.GONE
            } else {
                ivImage.visibility = View.GONE
                tvImageInfo.visibility = View.GONE
                progressImage.visibility = View.GONE
            }
        }
    }

    inner class AiMessageViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val tvText: TextView = itemView.findViewById(R.id.tv_ai_text)
        private val btnStop: MaterialButton = itemView.findViewById(R.id.btn_stop_generating)

        fun bind(item: ChatMessage.AiMessage) {
            tvText.text = item.text
            btnStop.visibility = if (item.isGenerating) View.VISIBLE else View.GONE
            btnStop.setOnClickListener {
                onStopClick?.invoke()
            }
        }

        fun updateText(text: String) {
            tvText.text = text
        }

        fun setStopButtonVisible(visible: Boolean) {
            btnStop.visibility = if (visible) View.VISIBLE else View.GONE
        }
    }

    class DiffCallback : DiffUtil.ItemCallback<ChatMessage>() {
        override fun areItemsTheSame(oldItem: ChatMessage, newItem: ChatMessage): Boolean {
            return oldItem.id == newItem.id
        }

        override fun areContentsTheSame(oldItem: ChatMessage, newItem: ChatMessage): Boolean {
            return when {
                oldItem is ChatMessage.UserMessage && newItem is ChatMessage.UserMessage ->
                    oldItem.text == newItem.text &&
                            oldItem.imageBitmap == newItem.imageBitmap &&
                            oldItem.imageInfo == newItem.imageInfo &&
                            oldItem.isPrefilling == newItem.isPrefilling
                oldItem is ChatMessage.AiMessage && newItem is ChatMessage.AiMessage ->
                    oldItem.isGenerating == newItem.isGenerating &&
                            (oldItem.isGenerating || oldItem.text == newItem.text)
                oldItem is ChatMessage.WelcomeCard && newItem is ChatMessage.WelcomeCard -> true
                else -> false
            }
        }
    }
}

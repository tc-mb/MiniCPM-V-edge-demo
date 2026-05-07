package com.example.minicpm_v_demo

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.ImageButton
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.appbar.AppBarLayout
import com.google.android.material.textfield.TextInputEditText
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.onCompletion
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : AppCompatActivity() {

    private lateinit var recyclerChat: RecyclerView
    private lateinit var chatAdapter: ChatAdapter
    private lateinit var etInput: TextInputEditText
    private lateinit var btnSend: ImageButton
    private lateinit var btnImage: ImageButton
    private lateinit var btnClearChat: ImageButton
    private lateinit var btnModelManager: ImageButton
    private lateinit var cardInputBar: View
    private lateinit var appBarLayout: AppBarLayout

    private lateinit var engine: LlamaEngine
    private var generationJob: Job? = null
    private var isModelReady = false
    private var isImagePrefilled = false
    private var hasAutoLoaded = false
    private var messageIdCounter = 1L
    private val messages = mutableListOf<ChatMessage>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        LlamaEngine.migrateLegacyLayoutIfNeeded(applicationContext)

        initViews()
        setupRecyclerView()
        setupClickListeners()
        initEngine()
    }

    private fun initViews() {
        recyclerChat = findViewById(R.id.recycler_chat)
        etInput = findViewById(R.id.et_input)
        btnSend = findViewById(R.id.btn_send)
        btnImage = findViewById(R.id.btn_image)
        btnClearChat = findViewById(R.id.btn_clear_chat)
        btnModelManager = findViewById(R.id.btn_model_manager)
        cardInputBar = findViewById(R.id.card_input_bar)
        appBarLayout = findViewById(R.id.appBarLayout)
    }

    private fun setupRecyclerView() {
        chatAdapter = ChatAdapter()
        chatAdapter.setOnStopClick {
            engine.cancelGeneration()
        }
        chatAdapter.setOnSuggestionClick { suggestion ->
            if (isModelReady) {
                etInput.setText(suggestion)
                handleUserInput()
            } else {
                Toast.makeText(this, "请先加载模型", Toast.LENGTH_SHORT).show()
            }
        }

        recyclerChat.layoutManager = LinearLayoutManager(this)
        recyclerChat.adapter = chatAdapter

        cardInputBar.viewTreeObserver.addOnGlobalLayoutListener {
            recyclerChat.setPadding(
                recyclerChat.paddingLeft,
                recyclerChat.paddingTop,
                recyclerChat.paddingRight,
                cardInputBar.height
            )
        }

        messages.add(ChatMessage.WelcomeCard())
        chatAdapter.submitList(messages.toList())
    }

    private fun setupClickListeners() {
        btnImage.setOnClickListener { getImage.launch(arrayOf("image/*")) }
        btnSend.setOnClickListener { handleUserInput() }
        btnClearChat.setOnClickListener { showClearChatDialog() }
        btnModelManager.setOnClickListener {
            startActivity(Intent(this, ModelManagerActivity::class.java))
        }

        etInput.setOnFocusChangeListener { _, hasFocus ->
            if (hasFocus) {
                collapseAppBar()
                scrollToBottom()
            }
        }
    }

    private fun collapseAppBar() {
        appBarLayout.setExpanded(false, true)
    }

    private fun scrollToBottom() {
        recyclerChat.post {
            val layoutManager = recyclerChat.layoutManager as? LinearLayoutManager ?: return@post
            val lastPos = layoutManager.findLastCompletelyVisibleItemPosition()
            val adapterCount = chatAdapter.itemCount
            if (adapterCount == 0) return@post
            if (lastPos < adapterCount - 2) {
                recyclerChat.scrollToPosition(adapterCount - 1)
            } else {
                recyclerChat.smoothScrollToPosition(adapterCount - 1)
            }
        }
    }

    private fun showClearChatDialog() {
        AlertDialog.Builder(this)
            .setTitle(R.string.clear_chat)
            .setMessage(R.string.clear_chat_confirm)
            .setPositiveButton("确定") { _, _ ->
                clearChat()
            }
            .setNegativeButton("取消", null)
            .show()
    }

    private fun clearChat() {
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                engine.clearContext()
                engine.setSystemPrompt("你是一个有用且诚实的AI助手。当用户发送图片时，请仔细观察图片内容并准确回答用户的问题。")
                withContext(Dispatchers.Main) {
                    messages.clear()
                    messages.add(ChatMessage.WelcomeCard())
                    messageIdCounter = 1L
                    isImagePrefilled = false
                    chatAdapter.submitList(messages.toList())
                    Toast.makeText(this@MainActivity, R.string.clear_chat_toast, Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error clearing context", e)
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@MainActivity, "清空对话失败: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun initEngine() {
        lifecycleScope.launch(Dispatchers.Default) {
            engine = LlamaEngine.getInstance(applicationContext)
            withContext(Dispatchers.Main) {
                observeEngineState()
            }
        }
    }

    private fun observeEngineState() {
        lifecycleScope.launch {
            engine.state.collect { state ->
                when (state) {
                    is LlamaState.Uninitialized,
                    is LlamaState.Initializing -> {
                        enableInput(false)
                    }
                    is LlamaState.Initialized -> {
                        enableInput(false)
                        if (!hasAutoLoaded) {
                            hasAutoLoaded = true
                            loadDefaultModel()
                        }
                    }
                    is LlamaState.LoadingModel -> {
                        enableInput(false)
                    }
                    is LlamaState.ModelReady -> {
                        isModelReady = true
                        enableInput(true)
                        btnImage.isEnabled = engine.isVisionSupported
                    }
                    is LlamaState.ProcessingSystemPrompt,
                    is LlamaState.ProcessingUserPrompt,
                    is LlamaState.Generating -> {
                        enableInput(false)
                    }
                    is LlamaState.PrefillingImage -> {
                        isModelReady = true
                        etInput.isEnabled = true
                        btnSend.isEnabled = true
                        btnImage.isEnabled = false
                    }
                    is LlamaState.UnloadingModel -> {
                        enableInput(false)
                    }
                    is LlamaState.Error -> {
                        enableInput(false)
                    }
                }
            }
        }
    }

    private fun enableInput(enable: Boolean) {
        etInput.isEnabled = enable
        btnSend.isEnabled = enable
        if (!enable) {
            btnImage.isEnabled = false
        } else {
            btnImage.isEnabled = engine.isVisionSupported
        }
    }

    private fun loadDefaultModel() {
        val modelPath = LlamaEngine.modelPath(applicationContext)
        val mmprojPath = LlamaEngine.mmprojPath(applicationContext)

        if (!File(modelPath).exists()) {
            Toast.makeText(this, "模型文件不存在，请先下载", Toast.LENGTH_LONG).show()
            return
        }

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val mmprojFile = File(mmprojPath)
                engine.loadModel(modelPath, if (mmprojFile.exists()) mmprojPath else null)
                engine.setSystemPrompt("你是一个有用且诚实的AI助手。当用户发送图片时，请仔细观察图片内容并准确回答用户的问题。")
            } catch (e: Exception) {
                Log.e(TAG, "Error loading model", e)
                engine.resetToInitialized()
                hasAutoLoaded = false
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@MainActivity, "模型加载失败: ${e.message}", Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    private val getImage = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        uri?.let { handleSelectedImage(it) }
    }

    private fun handleSelectedImage(uri: Uri) {
        if (!isModelReady) {
            Toast.makeText(this, "请先加载模型", Toast.LENGTH_SHORT).show()
            return
        }

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val imageData = contentResolver.openInputStream(uri)?.use { input ->
                    val bitmap = BitmapFactory.decodeStream(input)
                        ?: throw RuntimeException("无法解码图片")
                    val stream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                    Pair(stream.toByteArray(), bitmap)
                } ?: throw RuntimeException("无法读取图片")

                val (imageBytes, bitmap) = imageData

                val imageName = getFileName(uri)
                val width = bitmap.width
                val height = bitmap.height
                val sizeKb = imageBytes.size / 1024
                val imageInfo = "$width x $height ($sizeKb KB)"
                val msgId = messageIdCounter++

                withContext(Dispatchers.Main) {
                    val imageMessage = ChatMessage.UserMessage(
                        id = msgId,
                        text = "",
                        imageBitmap = bitmap,
                        imageInfo = imageInfo,
                        isPrefilling = true
                    )
                    messages.add(imageMessage)
                    chatAdapter.submitList(messages.toList()) {
                        scrollToBottom()
                    }
                }

                engine.prefillImage(imageBytes)

                isImagePrefilled = true

                withContext(Dispatchers.Main) {
                    val index = messages.indexOfFirst { it.id == msgId }
                    if (index >= 0) {
                        messages[index] = (messages[index] as ChatMessage.UserMessage).copy(
                            isPrefilling = false
                        )
                        chatAdapter.submitList(messages.toList())
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing image", e)
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@MainActivity, "处理图片失败: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun getFileName(uri: Uri): String {
        val cursor = contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            if (it.moveToFirst()) {
                val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) {
                    return it.getString(nameIndex)
                }
            }
        }
        return "file-${System.currentTimeMillis()}"
    }

    private fun handleUserInput() {
        val userMsg = etInput.text.toString().trim()
        if (userMsg.isEmpty()) {
            Toast.makeText(this, "请输入文字消息", Toast.LENGTH_SHORT).show()
            return
        }

        etInput.text = null
        enableInput(false)

        collapseAppBar()

        val msgId = messageIdCounter++
        val userMessage = ChatMessage.UserMessage(
            id = msgId,
            text = userMsg,
            imageBitmap = null,
            imageInfo = null
        )
        messages.add(userMessage)
        chatAdapter.submitList(messages.toList()) {
            scrollToBottom()
        }

        isImagePrefilled = false

        val aiMsgId = messageIdCounter++
        val aiMessage = ChatMessage.AiMessage(id = aiMsgId, text = "", isGenerating = true)
        messages.add(aiMessage)
        chatAdapter.setActiveAiMessage(aiMsgId)
        chatAdapter.submitList(messages.toList()) {
            scrollToBottom()
        }

        generationJob = lifecycleScope.launch(Dispatchers.Default) {
            val fullResponse = StringBuilder()
            engine.sendUserPrompt(userMsg)
                .onCompletion {
                    withContext(Dispatchers.Main) {
                        val index = messages.indexOfFirst { it.id == aiMsgId }
                        if (index >= 0) {
                            messages[index] = (messages[index] as ChatMessage.AiMessage).copy(
                                text = fullResponse.toString(),
                                isGenerating = false
                            )
                        }
                        chatAdapter.setGeneratingDone(aiMsgId)
                        chatAdapter.clearActiveAiMessage()
                        chatAdapter.submitList(messages.toList())
                        enableInput(true)
                        scrollToBottom()
                    }
                }
                .collect { token ->
                    fullResponse.append(token)
                    withContext(Dispatchers.Main) {
                        val currentText = fullResponse.toString()
                        val index = messages.indexOfFirst { it.id == aiMsgId }
                        if (index >= 0) {
                            messages[index] = ChatMessage.AiMessage(
                                id = aiMsgId,
                                text = currentText,
                                isGenerating = true
                            )
                        }
                        chatAdapter.updateStreamingText(aiMsgId, currentText)
                        scrollToBottom()
                    }
                }
        }
    }

    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        if (ev.action == MotionEvent.ACTION_DOWN) {
            val v = currentFocus
            if (v is TextInputEditText) {
                val outRect = android.graphics.Rect()
                v.getGlobalVisibleRect(outRect)
                if (!outRect.contains(ev.rawX.toInt(), ev.rawY.toInt())) {
                    v.clearFocus()
                    val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.hideSoftInputFromWindow(v.windowToken, 0)
                }
            }
        }
        return super.dispatchTouchEvent(ev)
    }

    override fun onStop() {
        generationJob?.cancel()
        super.onStop()
    }

    override fun onDestroy() {
        if (::engine.isInitialized) {
            engine.destroy()
        }
        super.onDestroy()
    }

    companion object {
        private val TAG = MainActivity::class.java.simpleName
    }
}

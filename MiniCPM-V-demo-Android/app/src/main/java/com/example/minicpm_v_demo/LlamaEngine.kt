package com.example.minicpm_v_demo

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

sealed class LlamaState {
    object Uninitialized : LlamaState()
    object Initializing : LlamaState()
    object Initialized : LlamaState()
    object LoadingModel : LlamaState()
    object ModelReady : LlamaState()
    object ProcessingSystemPrompt : LlamaState()
    object PrefillingImage : LlamaState()
    object ProcessingUserPrompt : LlamaState()
    object Generating : LlamaState()
    object UnloadingModel : LlamaState()
    data class Error(val exception: Exception) : LlamaState()
}

class LlamaEngine private constructor(
    private val context: Context,
    private val nativeLibDir: String
) {

    companion object {
        private val TAG = LlamaEngine::class.java.simpleName

        @Volatile
        private var instance: LlamaEngine? = null

        const val DEFAULT_PREDICT_LENGTH = 1024

        const val MODEL_SUBDIR = "models"

        private const val PREFS_NAME = "model_prefs"
        private const val KEY_SELECTED_MODEL = "selected_model_id"

        fun getInstance(context: Context): LlamaEngine =
            instance ?: synchronized(this) {
                val nativeLibDir = context.applicationInfo.nativeLibraryDir
                require(nativeLibDir.isNotBlank()) { "Expected a valid native library path!" }
                LlamaEngine(context, nativeLibDir).also { instance = it }
            }

        private fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        fun getSelectedModel(context: Context): ModelInfo {
            val modelId = prefs(context).getString(KEY_SELECTED_MODEL, ModelInfo.DEFAULT_MODEL.id) ?: ModelInfo.DEFAULT_MODEL.id
            return ModelInfo.AVAILABLE_MODELS.find { it.id == modelId } ?: ModelInfo.DEFAULT_MODEL
        }

        fun setSelectedModel(context: Context, modelId: String) {
            prefs(context).edit().putString(KEY_SELECTED_MODEL, modelId).apply()
        }

        fun modelDir(context: Context): String =
            File(context.filesDir, MODEL_SUBDIR).absolutePath

        fun modelPath(context: Context): String {
            val model = getSelectedModel(context)
            return File(modelDir(context), model.ggufFileName).absolutePath
        }

        fun mmprojPath(context: Context): String {
            val model = getSelectedModel(context)
            return File(modelDir(context), model.mmprojFileName).absolutePath
        }

        fun modelsExist(context: Context): Boolean =
            File(modelPath(context)).exists() && File(mmprojPath(context)).exists()

        suspend fun downloadModels(
            context: Context,
            onProgress: (String) -> Unit
        ) = withContext(Dispatchers.IO) {
            val model = getSelectedModel(context)
            val dir = File(modelDir(context))
            if (!dir.exists()) dir.mkdirs()

            val files = listOf(model.ggufFileName, model.mmprojFileName)

            val hfBase = "https://huggingface.co/${model.hfRepo}/resolve/${model.hfBranch}"
            val msBase = "https://www.modelscope.cn/models/${model.msRepo}/resolve/${model.msBranch}"

            onProgress("正在连接 HuggingFace...")

            val hfOk = try {
                val testUrl = URL("$hfBase/${model.ggufFileName}")
                val conn = (testUrl.openConnection() as HttpURLConnection).apply {
                    connectTimeout = 5000
                    readTimeout = 5000
                    requestMethod = "HEAD"
                    setRequestProperty("User-Agent", "MiniCPMV-demo/1.0")
                }
                val code = conn.responseCode
                conn.disconnect()
                code == HttpURLConnection.HTTP_OK
            } catch (e: Exception) {
                Log.w(TAG, "HuggingFace check failed: ${e.message}")
                false
            }

            val (baseUrl, source) = if (hfOk) {
                onProgress("HuggingFace 连接成功，开始下载...")
                Pair(hfBase, "HuggingFace")
            } else {
                onProgress("HuggingFace 连接失败，切换到 ModelScope...")

                val msOk = try {
                    val testUrl = URL("$msBase/${model.ggufFileName}")
                    val conn = (testUrl.openConnection() as HttpURLConnection).apply {
                        connectTimeout = 5000
                        readTimeout = 5000
                        requestMethod = "HEAD"
                        setRequestProperty("User-Agent", "MiniCPMV-demo/1.0")
                    }
                    val code = conn.responseCode
                    conn.disconnect()
                    code == HttpURLConnection.HTTP_OK
                } catch (e: Exception) {
                    Log.w(TAG, "ModelScope check failed: ${e.message}")
                    false
                }

                if (!msOk) {
                    throw RuntimeException("HuggingFace 和 ModelScope 均无法连接，请检查网络后重试")
                }

                onProgress("ModelScope 连接成功，开始下载...")
                Pair(msBase, "ModelScope")
            }

            for (fileName in files) {
                val targetFile = File(dir, fileName)
                val url = URL("$baseUrl/$fileName")

                onProgress("[$source] 下载 $fileName...")
                Log.i(TAG, "Downloading $fileName from $source: $url")

                val conn = (url.openConnection() as HttpURLConnection).apply {
                    connectTimeout = 10000
                    readTimeout = 120000
                    requestMethod = "GET"
                    setRequestProperty("User-Agent", "MiniCPMV-demo/1.0")
                }

                try {
                    val responseCode = conn.responseCode
                    if (responseCode != HttpURLConnection.HTTP_OK) {
                        throw RuntimeException("$source returned $responseCode for $fileName")
                    }

                    val contentLength = conn.contentLength.toLong()
                    val tmpFile = File(dir, "$fileName.tmp")

                    conn.inputStream.use { input ->
                        FileOutputStream(tmpFile).use { output ->
                            val buffer = ByteArray(8192)
                            var totalRead = 0L
                            var lastProgressTime = 0L

                            while (true) {
                                val read = input.read(buffer)
                                if (read == -1) break
                                output.write(buffer, 0, read)
                                totalRead += read

                                val now = System.currentTimeMillis()
                                if (now - lastProgressTime > 500) {
                                    lastProgressTime = now
                                    val progress = if (contentLength > 0) {
                                        val pct = totalRead * 100 / contentLength
                                        val mb = totalRead / (1024 * 1024)
                                        val totalMb = contentLength / (1024 * 1024)
                                        "$fileName: $pct% ($mb/$totalMb MB)"
                                    } else {
                                        val mb = totalRead / (1024 * 1024)
                                        "$fileName: $mb MB downloaded"
                                    }
                                    onProgress(progress)
                                }
                            }
                        }
                    }

                    if (targetFile.exists()) targetFile.delete()
                    if (!tmpFile.renameTo(targetFile)) {
                        tmpFile.copyTo(targetFile, overwrite = true)
                        tmpFile.delete()
                    }

                    onProgress("$fileName 下载完成 (${targetFile.length() / (1024 * 1024)} MB)")
                    Log.i(TAG, "$fileName saved to ${targetFile.absolutePath}")
                } finally {
                    conn.disconnect()
                }
            }

            onProgress("所有模型文件下载完成!")
        }
    }

    @Volatile
    private var _mmprojLoaded = false

    @ExperimentalCoroutinesApi
    private val llamaDispatcher = Dispatchers.IO.limitedParallelism(1)
    private val llamaScope = CoroutineScope(llamaDispatcher + SupervisorJob())

    private val _state = MutableStateFlow<LlamaState>(LlamaState.Uninitialized)
    val state: StateFlow<LlamaState> = _state.asStateFlow()

    @Volatile
    private var _cancelGeneration = false

    @Volatile
    private var _readyForSystemPrompt = false

    private external fun init(nativeLibDir: String)
    private external fun load(modelPath: String): Int
    private external fun loadMmproj(mmprojPath: String): Int
    private external fun prepare(): Int
    private external fun systemInfo(): String
    private external fun processSystemPrompt(systemPrompt: String): Int
    private external fun processUserPrompt(userPrompt: String, predictLength: Int): Int
    private external fun generateNextToken(): String?
    private external fun prefillImage(imageData: ByteArray, imageSize: Int): Int
    private external fun fullReset()
    private external fun nativeCancelGeneration()
    private external fun unload()
    private external fun shutdown()

    init {
        llamaScope.launch {
            try {
                check(_state.value is LlamaState.Uninitialized) {
                    "Cannot load native library in ${_state.value.javaClass.simpleName}!"
                }
                _state.value = LlamaState.Initializing
                Log.i(TAG, "Loading native library...")
                System.loadLibrary("minicpm_v_demo")
                init(nativeLibDir)
                _state.value = LlamaState.Initialized
                Log.i(TAG, "Native library loaded! System info: \n${systemInfo()}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load native library", e)
                _state.value = LlamaState.Error(e)
                throw e
            }
        }
    }

    suspend fun loadModel(pathToModel: String, pathToMmproj: String? = null) =
        withContext(llamaDispatcher) {
            check(_state.value is LlamaState.Initialized) {
                "Cannot load model in ${_state.value.javaClass.simpleName}!"
            }
            try {
                Log.i(TAG, "Checking access to model file... \n$pathToModel")
                File(pathToModel).let {
                    require(it.exists()) { "File not found: $pathToModel" }
                    require(it.isFile) { "Not a valid file: $pathToModel" }
                    require(it.canRead()) { "Cannot read file: $pathToModel" }
                }

                Log.i(TAG, "Loading model... \n$pathToModel")
                _readyForSystemPrompt = false
                _state.value = LlamaState.LoadingModel
                load(pathToModel).let {
                    if (it != 0) throw RuntimeException("Failed to load model (code: $it)")
                }

                if (pathToMmproj != null) {
                    Log.i(TAG, "Checking access to mmproj file... \n$pathToMmproj")
                    File(pathToMmproj).let {
                        require(it.exists()) { "mmproj file not found: $pathToMmproj" }
                        require(it.isFile) { "Not a valid mmproj file: $pathToMmproj" }
                        require(it.canRead()) { "Cannot read mmproj file: $pathToMmproj" }
                    }

                    Log.i(TAG, "Loading mmproj... \n$pathToMmproj")
                    loadMmproj(pathToMmproj).let {
                        if (it != 0) {
                            Log.w(TAG, "Failed to load mmproj (code: $it), continuing without vision support")
                        } else {
                            _mmprojLoaded = true
                            Log.i(TAG, "mmproj loaded successfully!")
                        }
                    }
                }

                prepare().let {
                    if (it != 0) throw RuntimeException("Failed to prepare resources (code: $it)")
                }
                Log.i(TAG, "Model loaded!")
                _readyForSystemPrompt = true
                _cancelGeneration = false
                _state.value = LlamaState.ModelReady
            } catch (e: Exception) {
                Log.e(TAG, (e.message ?: "Error loading model") + "\n" + pathToModel, e)
                _state.value = LlamaState.Error(e)
                throw e
            }
        }

    val isVisionSupported: Boolean get() = _mmprojLoaded

    suspend fun setSystemPrompt(prompt: String) =
        withContext(llamaDispatcher) {
            require(prompt.isNotBlank()) { "Cannot process empty system prompt!" }
            check(_readyForSystemPrompt) { "System prompt must be set RIGHT AFTER model loaded!" }
            check(_state.value is LlamaState.ModelReady) {
                "Cannot process system prompt in ${_state.value.javaClass.simpleName}!"
            }

            Log.i(TAG, "Sending system prompt...")
            _readyForSystemPrompt = false
            _state.value = LlamaState.ProcessingSystemPrompt
            processSystemPrompt(prompt).let { result ->
                if (result != 0) {
                    RuntimeException("Failed to process system prompt: $result").also {
                        _state.value = LlamaState.Error(it)
                        throw it
                    }
                }
            }
            Log.i(TAG, "System prompt processed! Awaiting user prompt...")
            _state.value = LlamaState.ModelReady
        }

    suspend fun prefillImage(imageData: ByteArray) =
        withContext(llamaDispatcher) {
            check(_mmprojLoaded) { "Vision model not loaded!" }
            check(_state.value is LlamaState.ModelReady) {
                "Cannot prefill image in ${_state.value.javaClass.simpleName}!"
            }

            Log.i(TAG, "Prefilling image...")
            _state.value = LlamaState.PrefillingImage
            val result = prefillImage(imageData, imageData.size)
            if (result != 0) {
                _state.value = LlamaState.ModelReady
                throw RuntimeException("Failed to prefill image (code: $result)")
            }
            Log.i(TAG, "Image prefilled!")
            _state.value = LlamaState.ModelReady
        }

    suspend fun clearContext() =
        withContext(llamaDispatcher) {
            check(_state.value is LlamaState.ModelReady) {
                "Cannot clear context in ${_state.value.javaClass.simpleName}"
            }
            fullReset()
            _readyForSystemPrompt = true
            Log.i(TAG, "Context fully reset - context recreated, ready for new conversation")
        }

    fun sendUserPrompt(
        message: String,
        predictLength: Int = DEFAULT_PREDICT_LENGTH
    ): Flow<String> = flow {
        require(message.isNotEmpty()) { "User prompt must not be empty!" }
        check(_state.value is LlamaState.ModelReady) {
            "User prompt discarded due to: ${_state.value.javaClass.simpleName}"
        }

        try {
            _cancelGeneration = false
            Log.i(TAG, "Sending user prompt...")
            _readyForSystemPrompt = false
            _state.value = LlamaState.ProcessingUserPrompt

            processUserPrompt(message, predictLength).let { result ->
                if (result != 0) {
                    Log.e(TAG, "Failed to process user prompt: $result")
                    return@flow
                }
            }

            Log.i(TAG, "User prompt processed. Generating assistant prompt...")
            _state.value = LlamaState.Generating
            while (!_cancelGeneration) {
                generateNextToken()?.let { utf8token ->
                    if (utf8token.isNotEmpty()) emit(utf8token)
                } ?: break
            }
            if (_cancelGeneration) {
                Log.i(TAG, "Assistant generation aborted per requested.")
            } else {
                Log.i(TAG, "Assistant generation complete. Awaiting user prompt...")
            }
            _state.value = LlamaState.ModelReady
        } catch (e: CancellationException) {
            Log.i(TAG, "Assistant generation's flow collection cancelled.")
            _state.value = LlamaState.ModelReady
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Error during generation!", e)
            _state.value = LlamaState.Error(e)
            throw e
        }
    }.flowOn(llamaDispatcher)

    fun cancelGeneration() {
        _cancelGeneration = true
        llamaScope.launch {
            nativeCancelGeneration()
        }
    }

    suspend fun unloadModel() = withContext(llamaDispatcher) {
        if (_state.value is LlamaState.ModelReady) {
            Log.i(TAG, "Unloading model...")
            _readyForSystemPrompt = false
            _mmprojLoaded = false
            _state.value = LlamaState.UnloadingModel
            unload()
            _state.value = LlamaState.Initialized
            Log.i(TAG, "Model unloaded")
        }
    }

    fun resetToInitialized() {
        _mmprojLoaded = false
        _readyForSystemPrompt = false
        _cancelGeneration = false
        _state.value = LlamaState.Initialized
    }

    fun cleanUp() {
        _cancelGeneration = true
        runBlocking(llamaDispatcher) {
            when (val state = _state.value) {
                is LlamaState.ModelReady -> {
                    Log.i(TAG, "Unloading model and free resources...")
                    _readyForSystemPrompt = false
                    _mmprojLoaded = false
                    _state.value = LlamaState.UnloadingModel
                    unload()
                    _state.value = LlamaState.Initialized
                    Log.i(TAG, "Model unloaded!")
                }
                is LlamaState.Error -> {
                    Log.i(TAG, "Resetting error states...")
                    _mmprojLoaded = false
                    _state.value = LlamaState.Initialized
                }
                else -> throw IllegalStateException("Cannot unload model in ${state.javaClass.simpleName}")
            }
        }
    }

    fun destroy() {
        _cancelGeneration = true
        runBlocking(llamaDispatcher) {
            _readyForSystemPrompt = false
            _mmprojLoaded = false
            when (_state.value) {
                is LlamaState.Uninitialized -> {}
                is LlamaState.Initialized -> shutdown()
                else -> { unload(); shutdown() }
            }
        }
        llamaScope.cancel()
    }

}

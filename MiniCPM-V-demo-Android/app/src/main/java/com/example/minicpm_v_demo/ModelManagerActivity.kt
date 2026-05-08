package com.example.minicpm_v_demo

import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.Toolbar
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.google.android.material.progressindicator.LinearProgressIndicator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class ModelManagerActivity : AppCompatActivity() {

    private lateinit var tvModelStatus: TextView
    private lateinit var btnDownload: MaterialButton
    private lateinit var btnLoadModel: MaterialButton
    private lateinit var btnDeleteModel: MaterialButton
    private lateinit var progressDownload: LinearProgressIndicator
    private lateinit var recyclerModels: RecyclerView

    private lateinit var engine: LlamaEngine
    private lateinit var modelAdapter: ModelAdapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_model_manager)

        val toolbar = findViewById<Toolbar>(R.id.toolbar)
        toolbar.setNavigationOnClickListener { finish() }

        tvModelStatus = findViewById(R.id.tv_model_status)
        btnDownload = findViewById(R.id.btn_download)
        btnLoadModel = findViewById(R.id.btn_load_model)
        btnDeleteModel = findViewById(R.id.btn_delete_model)
        progressDownload = findViewById(R.id.progress_download)
        recyclerModels = findViewById(R.id.recycler_models)

        engine = LlamaEngine.getInstance(applicationContext)

        setupModelList()
        updateLoadButtonState()
        observeEngineState()

        btnDownload.setOnClickListener { downloadModels() }
        btnLoadModel.setOnClickListener { loadSelectedModel() }
        btnDeleteModel.setOnClickListener { confirmDeleteModel() }
    }

    private fun setupModelList() {
        val selectedModel = LlamaEngine.getSelectedModel(this)
        modelAdapter = ModelAdapter(
            models = ModelInfo.AVAILABLE_MODELS,
            selectedModelId = selectedModel.id,
            onModelSelected = { model ->
                LlamaEngine.setSelectedModel(this, model.id)
                updateLoadButtonState()
                Toast.makeText(this, "已选择: ${model.displayName}", Toast.LENGTH_SHORT).show()
            }
        )

        recyclerModels.layoutManager = LinearLayoutManager(this)
        recyclerModels.adapter = modelAdapter
    }

    private fun observeEngineState() {
        lifecycleScope.launch {
            engine.state.collect { state ->
                when (state) {
                    is LlamaState.Uninitialized -> {
                        tvModelStatus.text = getString(R.string.status_uninitialized)
                    }
                    is LlamaState.Initializing -> {
                        tvModelStatus.text = getString(R.string.status_initializing)
                    }
                    is LlamaState.Initialized -> {
                        tvModelStatus.text = getString(R.string.status_initialized)
                        updateLoadButtonState()
                    }
                    is LlamaState.LoadingModel -> {
                        tvModelStatus.text = getString(R.string.status_loading)
                        btnLoadModel.isEnabled = false
                        btnDownload.isEnabled = false
                    }
                    is LlamaState.ModelReady -> {
                        tvModelStatus.text = getString(R.string.status_ready)
                        btnLoadModel.isEnabled = true
                        btnDownload.isEnabled = true
                        updateLoadButtonState()
                    }
                    is LlamaState.ProcessingSystemPrompt,
                    is LlamaState.ProcessingUserPrompt -> {
                        tvModelStatus.text = getString(R.string.status_generating)
                    }
                    is LlamaState.PrefillingImage -> {
                        tvModelStatus.text = "正在处理图片..."
                    }
                    is LlamaState.Generating -> {
                        tvModelStatus.text = getString(R.string.status_generating)
                    }
                    is LlamaState.UnloadingModel -> {
                        tvModelStatus.text = "正在卸载模型..."
                    }
                    is LlamaState.Error -> {
                        tvModelStatus.text = "错误: ${state.exception.message}"
                        btnLoadModel.isEnabled = true
                        btnDownload.isEnabled = true
                    }
                }
            }
        }
    }

    private fun updateLoadButtonState() {
        val exists = LlamaEngine.modelsExist(this)
        val isReady = engine.state.value is LlamaState.ModelReady
        btnLoadModel.isEnabled = exists
        btnDeleteModel.visibility = if (exists) View.VISIBLE else View.GONE
        btnLoadModel.text = when {
            isReady -> "重新加载"
            exists -> getString(R.string.load_model)
            else -> "无模型文件"
        }
    }

    private fun downloadModels() {
        if (LlamaEngine.modelsExist(this)) {
            Toast.makeText(this, "模型文件已存在，无需重复下载", Toast.LENGTH_SHORT).show()
            return
        }

        btnDownload.isEnabled = false
        btnLoadModel.isEnabled = false
        progressDownload.visibility = View.VISIBLE
        tvModelStatus.text = getString(R.string.status_downloading)

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                LlamaEngine.downloadModels(applicationContext) { progress ->
                    lifecycleScope.launch(Dispatchers.Main) {
                        tvModelStatus.text = progress
                    }
                }

                withContext(Dispatchers.Main) {
                    updateLoadButtonState()
                    tvModelStatus.text = "下载完成! 请点击加载模型"
                    Toast.makeText(this@ModelManagerActivity, "下载完成!", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Download failed", e)
                withContext(Dispatchers.Main) {
                    tvModelStatus.text = "下载失败: ${e.message}"
                    Toast.makeText(this@ModelManagerActivity, "下载失败: ${e.message}", Toast.LENGTH_LONG).show()
                }
            } finally {
                withContext(Dispatchers.Main) {
                    btnDownload.isEnabled = true
                    progressDownload.visibility = View.GONE
                    updateLoadButtonState()
                }
            }
        }
    }

    private fun loadSelectedModel() {
        val currentState = engine.state.value
        if (currentState is LlamaState.LoadingModel) {
            Toast.makeText(this, "模型正在加载中...", Toast.LENGTH_SHORT).show()
            return
        }

        val modelPath = LlamaEngine.modelPath(applicationContext)
        val mmprojPath = LlamaEngine.mmprojPath(applicationContext)

        if (!File(modelPath).exists()) {
            Toast.makeText(this, "模型文件不存在，请先下载", Toast.LENGTH_LONG).show()
            return
        }

        val isReload = currentState is LlamaState.ModelReady

        btnLoadModel.isEnabled = false
        btnDownload.isEnabled = false

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                if (isReload) {
                    Log.i(TAG, "Unloading model for reload...")
                    engine.unloadModel()
                }

                val mmprojFile = File(mmprojPath)
                engine.loadModel(modelPath, if (mmprojFile.exists()) mmprojPath else null)

                engine.setSystemPrompt("你是一个有用且诚实的AI助手。当用户发送图片时，请仔细观察图片内容并准确回答用户的问题。")

                withContext(Dispatchers.Main) {
                    btnLoadModel.isEnabled = true
                    btnDownload.isEnabled = true
                    updateLoadButtonState()
                    Toast.makeText(this@ModelManagerActivity, "模型加载成功!", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error loading model", e)
                engine.resetToInitialized()
                withContext(Dispatchers.Main) {
                    tvModelStatus.text = "加载失败: ${e.message}"
                    btnLoadModel.isEnabled = true
                    btnDownload.isEnabled = true
                    updateLoadButtonState()
                }
            }
        }
    }

    private fun confirmDeleteModel() {
        val model = LlamaEngine.getSelectedModel(this)
        AlertDialog.Builder(this)
            .setTitle("删除模型文件")
            .setMessage("确定要删除 ${model.displayName} 的模型文件吗？\n\n这将删除:\n• ${model.ggufFileName}\n• ${model.mmprojFileName}\n\n删除后需要重新下载才能使用。")
            .setPositiveButton("删除") { _, _ -> deleteModelFiles() }
            .setNegativeButton("取消", null)
            .show()
    }

    private fun deleteModelFiles() {
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val modelPath = LlamaEngine.modelPath(applicationContext)
                val mmprojPath = LlamaEngine.mmprojPath(applicationContext)

                var deleted = false
                File(modelPath).let { if (it.exists()) { it.delete(); deleted = true } }
                File(mmprojPath).let { if (it.exists()) { it.delete(); deleted = true } }

                withContext(Dispatchers.Main) {
                    updateLoadButtonState()
                    if (deleted) {
                        tvModelStatus.text = "模型文件已删除"
                        Toast.makeText(this@ModelManagerActivity, "模型文件已删除", Toast.LENGTH_SHORT).show()
                    } else {
                        Toast.makeText(this@ModelManagerActivity, "没有可删除的文件", Toast.LENGTH_SHORT).show()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error deleting model", e)
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@ModelManagerActivity, "删除失败: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    companion object {
        private val TAG = ModelManagerActivity::class.java.simpleName
    }
}

# MiniCPM-V Demo — iOS 与 Android

[English](README.md) | **中文**

本项目演示了 MiniCPM-V 系列多模态模型在 iOS 与 Android 设备上的端侧本地推理。当前已支持以下三个模型版本：

* **MiniCPM-V 2.6**
* **MiniCPM-V 4.0**
* **MiniCPM-V 4.6**

仓库中包含两份基于 `llama.cpp` 完整本地推理的 demo：

* `MiniCPM-V-demo/` — iOS demo（Xcode 工程）
* `MiniCPM-V-demo-Android/` — Android demo（Gradle / Kotlin）

两端共享仓库根目录的同一份 `llama.cpp` 子模块（分支 `Support-iOS-Demo`）。

> **提示**：本项目通过 git submodule 引入 `llama.cpp`，clone 后请运行：
>
> ```bash
> git clone https://github.com/tc-mb/MiniCPM-o-demo-iOS.git
> cd MiniCPM-o-demo-iOS
> git submodule update --init --recursive
> ```

---

## 1. iOS Demo

**注意：在 iOS 设备上部署和测试 demo，可能需要 Apple Developer 账号。**

安装 Xcode：

* 在 App Store 下载 Xcode
* 安装命令行工具：

  ```bash
  xcode-select --install
  ```
* 同意软件许可协议：

  ```bash
  sudo xcodebuild -license
  ```

用 Xcode 打开 `MiniCPM-V-demo/MiniCPM-V-demo.xcodeproj`，等待 Xcode 自动下载所需依赖。

在 Xcode 顶部选择目标设备，点击 "Run"（三角形）按钮启动 demo。

**注意：如果遇到 `thirdparty/llama.xcframework` 路径相关报错，请按下方步骤手动构建 `llama.xcframework`。**

### 手动构建 llama.xcframework

直接在子模块内构建（无需重复 clone）：

```bash
cd llama.cpp
./build-xcframework.sh
cp -r ./build-apple/llama.xcframework ../MiniCPM-V-demo/thirdparty
```

---

## 2. Android Demo

环境要求：

* Android Studio（Giraffe 或更新版本）
* Android SDK + NDK（项目固定 NDK `28.2.13676358`、CMake `3.22.1`）
* 64 位 ARM 架构（`arm64-v8a`）的真机，建议内存 ≥ 6 GB

构建并运行：

```bash
cd MiniCPM-V-demo-Android
./gradlew assembleDebug
```

或直接用 Android Studio 打开 `MiniCPM-V-demo-Android/` 目录，点击 Run。

首次启动时，应用会自动把 GGUF 模型文件下载到外部存储。也可以通过 `adb push` 手动侧载模型文件——具体目录结构请参考 App 内的 **模型管理** 页面。

---

## 3. MiniCPM-V 2.6 GGUF 模型文件

### 1: 下载官方 GGUF 文件

* HuggingFace: [https://huggingface.co/openbmb/MiniCPM-V-2_6-gguf](https://huggingface.co/openbmb/MiniCPM-V-2_6-gguf)
* ModelScope: [https://modelscope.cn/models/OpenBMB/MiniCPM-V-2_6-gguf](https://modelscope.cn/models/OpenBMB/MiniCPM-V-2_6-gguf)

请从仓库下载语言模型文件（例如 `ggml-model-Q4_0.gguf`）以及视觉模型文件（`mmproj-model-f16.gguf`）。

## 4. MiniCPM-V 4.0 GGUF 模型文件

### 方式 A：下载官方 GGUF 文件

* HuggingFace: [https://huggingface.co/openbmb/MiniCPM-V-4-gguf](https://huggingface.co/openbmb/MiniCPM-V-4-gguf)
* ModelScope: [https://modelscope.cn/models/OpenBMB/MiniCPM-V-4-gguf](https://modelscope.cn/models/OpenBMB/MiniCPM-V-4-gguf)

请从仓库下载语言模型文件（例如 `ggml-model-Q4_K_M.gguf`）以及视觉模型文件（`mmproj-model-f16.gguf`）。

### 方式 B：从 PyTorch 模型转换

将 MiniCPM-V-4 的 PyTorch 模型下载到名为 `MiniCPM-V-4` 的文件夹：

* HuggingFace: [https://huggingface.co/openbmb/MiniCPM-V-4](https://huggingface.co/openbmb/MiniCPM-V-4)
* ModelScope: [https://modelscope.cn/models/OpenBMB/MiniCPM-V-4](https://modelscope.cn/models/OpenBMB/MiniCPM-V-4)

将 PyTorch 模型转换为 GGUF 格式：

```bash
cd llama.cpp

python ./tools/mtmd/legacy-models/minicpmv-surgery.py -m ../MiniCPM-V-4

python ./tools/mtmd/legacy-models/minicpmv-convert-image-encoder-to-gguf.py -m ../MiniCPM-V-4 --minicpmv-projector ../MiniCPM-V-4/minicpmv.projector --output-dir ../MiniCPM-V-4/ --minicpmv_version 5

python ./convert_hf_to_gguf.py ../MiniCPM-V-4/model

# int4 量化
./llama-quantize ../MiniCPM-V-4/model/Model-3.6B-f16.gguf ../MiniCPM-V-4/model/ggml-model-Q4_K_M.gguf Q4_K_M
```

## 5. MiniCPM-V 4.6 GGUF 模型文件

### 1: 下载官方 GGUF 文件

* HuggingFace: [https://huggingface.co/openbmb/MiniCPM-V-4_6-gguf](https://huggingface.co/openbmb/MiniCPM-V-4_6-gguf)
* ModelScope: [https://modelscope.cn/models/OpenBMB/MiniCPM-V-4_6-gguf](https://modelscope.cn/models/OpenBMB/MiniCPM-V-4_6-gguf)

请从仓库下载语言模型文件（例如 `minicpmv46-llm-Q4_K_M.gguf`）以及视觉模型文件（`mmproj-v46-model-f16.gguf`）。

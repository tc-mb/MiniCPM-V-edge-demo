# MiniCPM-V Demo — iOS, Android & HarmonyOS

**English** | [中文](README_zh.md)

This demo runs the MiniCPM-V family of multimodal models fully on-device on iOS, Android, and HarmonyOS NEXT. Three model versions are currently supported:

* **MiniCPM-V 2.6**
* **MiniCPM-V 4.0**
* **MiniCPM-V 4.6**

This repository contains three on-device demos for MiniCPM-V (multimodal LLM) running fully locally via `llama.cpp`:

* `MiniCPM-V-demo/` — iOS demo (Xcode project)
* `MiniCPM-V-demo-Android/` — Android demo (Gradle / Kotlin)
* `MiniCPM-V-demo-HarmonyOS/` — HarmonyOS NEXT demo (DevEco Studio / ArkTS)

All three demos share the same `llama.cpp` submodule (branch `Support-iOS-Demo`) at the repo root.

> **NOTE**: This project bundles `llama.cpp` as a git submodule. After cloning, run:
>
> ```bash
> git clone https://github.com/tc-mb/MiniCPM-V-edge-demo.git
> cd MiniCPM-V-edge-demo
> git submodule update --init --recursive
> ```

---

## 1. iOS Demo

**NOTE: To deploy and test the app on an iOS device, you may need an Apple Developer account.**

Install Xcode:

* Download Xcode from the App Store
* Install the Command Line Tools:

  ```bash
  xcode-select --install
  ```
* Agree to the software license agreement:

  ```bash
  sudo xcodebuild -license
  ```

Open `MiniCPM-V-demo/MiniCPM-V-demo.xcodeproj` with Xcode. It may take a moment for Xcode to automatically download the required dependencies.

In Xcode, select the target device at the top of the window, then click the "Run" (triangle) button to launch the demo.

**NOTE: If you encounter errors related to the `thirdparty/llama.xcframework` path, please follow the steps below to build the `llama.xcframework` manually.**

### Manually Building the llama.xcframework

Build directly inside the submodule (no extra clone needed):

```bash
cd llama.cpp
./build-xcframework.sh
cp -r ./build-apple/llama.xcframework ../MiniCPM-V-demo/thirdparty
```

---

## 2. Android Demo

Requirements:

* Android Studio (Giraffe or newer)
* Android SDK + NDK (the project pins NDK `28.2.13676358` and CMake `3.22.1`)
* A physical device with a 64-bit ARM SoC (`arm64-v8a`) and ≥ 6 GB RAM recommended

Build & run:

```bash
cd MiniCPM-V-demo-Android
./gradlew assembleDebug
```

Or open `MiniCPM-V-demo-Android/` directly in Android Studio and click Run.

The first launch will download the GGUF model files into the app's external storage. You can also sideload model files manually via `adb push` — see in-app **Model Manager** for the expected directory layout.

---

## 3. HarmonyOS Demo

Requirements:

* DevEco Studio 5.0 or newer (with the HarmonyOS Native SDK / NDK)
* A real device or emulator running HarmonyOS API 12+ (e.g. nova 14 vitality / Mate 60 / Pura 70)
* 64-bit ARM architecture (`arm64-v8a`)

Build & run:

1. Open `MiniCPM-V-demo-HarmonyOS/` in DevEco Studio.
2. `File` → `Project Structure` → `Signing Configs` and tick **Automatically generate signature** (requires a Huawei developer account; this only needs to be done once).
3. Connect the device with USB debugging enabled, then click Run (the green triangle).

After the first launch, open the in-app **Model Manager** and tap **Download**. You can also sideload model files via `hdc file send`; see `MiniCPM-V-demo-HarmonyOS/README_zh.md` for the expected directory layout.

> The HarmonyOS port shares the exact same `llama.cpp` submodule, model catalogue, OBS direct-link URLs and MD5 hashes with the iOS / Android demos.

---

## 4. MiniCPM-V 2.6 GGUF Files

### 1: Download Official GGUF Files

* HuggingFace: [https://huggingface.co/openbmb/MiniCPM-V-2_6-gguf](https://huggingface.co/openbmb/MiniCPM-V-2_6-gguf)
* ModelScope: [https://modelscope.cn/models/OpenBMB/MiniCPM-V-2_6-gguf](https://modelscope.cn/models/OpenBMB/MiniCPM-V-2_6-gguf)

Download the language model file (e.g., `ggml-model-Q4_0.gguf`) and the vision model file (`mmproj-model-f16.gguf`) from the repository.

## 5. MiniCPM-V 4.0 GGUF Files

### Option A: Download Official GGUF Files

* HuggingFace: [https://huggingface.co/openbmb/MiniCPM-V-4-gguf](https://huggingface.co/openbmb/MiniCPM-V-4-gguf)
* ModelScope: [https://modelscope.cn/models/OpenBMB/MiniCPM-V-4-gguf](https://modelscope.cn/models/OpenBMB/MiniCPM-V-4-gguf)

Download the language model file (e.g., `ggml-model-Q4_K_M.gguf`) and the vision model file (`mmproj-model-f16.gguf`) from the repository.

### Option B: Convert from PyTorch Model

Download the MiniCPM-V-4 PyTorch model into a folder named `MiniCPM-V-4`:

* HuggingFace: [https://huggingface.co/openbmb/MiniCPM-V-4](https://huggingface.co/openbmb/MiniCPM-V-4)
* ModelScope: [https://modelscope.cn/models/OpenBMB/MiniCPM-V-4](https://modelscope.cn/models/OpenBMB/MiniCPM-V-4)

Convert the PyTorch model to GGUF format:

```bash
cd llama.cpp

python ./tools/mtmd/legacy-models/minicpmv-surgery.py -m ../MiniCPM-V-4

python ./tools/mtmd/legacy-models/minicpmv-convert-image-encoder-to-gguf.py -m ../MiniCPM-V-4 --minicpmv-projector ../MiniCPM-V-4/minicpmv.projector --output-dir ../MiniCPM-V-4/ --minicpmv_version 5

python ./convert_hf_to_gguf.py ../MiniCPM-V-4/model

# int4 quantized
./llama-quantize ../MiniCPM-V-4/model/Model-3.6B-f16.gguf ../MiniCPM-V-4/model/ggml-model-Q4_K_M.gguf Q4_K_M
```

## 6. MiniCPM-V 4.6 GGUF Files

### 1: Download Official GGUF Files

* HuggingFace: [https://huggingface.co/openbmb/MiniCPM-V-4_6-gguf](https://huggingface.co/openbmb/MiniCPM-V-4_6-gguf)
* ModelScope: [https://modelscope.cn/models/OpenBMB/MiniCPM-V-4_6-gguf](https://modelscope.cn/models/OpenBMB/MiniCPM-V-4_6-gguf)

Download the language model file (e.g., `minicpmv46-llm-Q4_K_M.gguf`) and the vision model file (`mmproj-v46-model-f16.gguf`) from the repository.

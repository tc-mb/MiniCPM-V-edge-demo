# 下载 MiniCPM-V Demo 应用

[English](DOWNLOAD.md) | **中文**

下面列出了 **iOS**、**Android** 和 **HarmonyOS NEXT** 三端预编译 App 的下载方式。三端均通过 `llama.cpp` 在 **本地端侧** 运行 MiniCPM-V 多模态模型——无需服务端、无需联网推理，数据不离开手机。

> 想从源码自行构建？请参考根目录 [README_zh.md](README_zh.md)。

---

## iOS —— TestFlight 公测版

**公开链接：** [https://testflight.apple.com/join/yNKyFZwW](https://testflight.apple.com/join/yNKyFZwW)

> **请注意：iOS 版本比 Android / HarmonyOS 更新更慢。**
> iOS 每次发版都必须先通过 Apple 的 TestFlight 审核才能推送到用户，因此新功能和问题修复在 iOS 上**通常会比 Android APK 和 HarmonyOS HAP 滞后数天到一两周**。如需第一时间体验最新修复，请使用本页下方的 Android 或 HarmonyOS 安装包。

### 系统要求

* 运行 **iOS / iPadOS 16 及以上** 的 iPhone 或 iPad
* 推荐内存 ≥ 6 GB 的设备（如 iPhone 15 Pro、搭载 M 系列芯片的 iPad），以获得流畅的端侧推理体验
* 设备上需先安装 App Store 版的 **TestFlight**

### 安装步骤

1. 在 App Store 安装 **TestFlight**。
2. 在同一台 iPhone / iPad 上打开上方公开链接，点击 **Accept** → **Install**。
3. 从主屏幕启动 **MiniCPM-V Demo**，按 App 内提示下载模型文件即可使用。

> 每个 TestFlight 构建版本最多可使用 90 天，新版本发布时 TestFlight 会自动推送通知。

---

## Android —— APK

**最新版本：** **v1.7** &nbsp;·&nbsp; [下载 `MiniCPM-V-demo-Android-v1.7.apk`](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases/download/android-v1.7/MiniCPM-V-demo-Android-v1.7.apk) &nbsp;·&nbsp; [发布说明](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases/tag/android-v1.7) &nbsp;·&nbsp; [全部版本](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases?q=tag%3Aandroid)

* MD5: `9d16d89205cc6c43b68886a42b560600`
* 大小：约 16 MB

### 系统要求

* **64 位 ARM** 架构（`arm64-v8a`）的安卓设备
* **Android 8.0（API 26）及以上**
* 推荐内存 ≥ 6 GB

### 安装步骤

1. 在手机上点击上方下载链接获取最新 `.apk` 安装包。
2. 若系统提示安全风险，请在 **设置 → 应用 → 安装未知应用** 中允许安装来源。
3. 打开 **MiniCPM-V Demo**，进入 App 内的 **模型管理** 页面点击 **下载模型** 即可。

---

## HarmonyOS NEXT —— HAP

**最新版本：** **v1.1** &nbsp;·&nbsp; [下载 `MiniCPM-V-demo-HarmonyOS-v1.1.hap`](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases/download/harmonyos-v1.1/MiniCPM-V-demo-HarmonyOS-v1.1.hap) &nbsp;·&nbsp; [发布说明](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases/tag/harmonyos-v1.1) &nbsp;·&nbsp; [全部版本](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases?q=tag%3Aharmonyos)

* MD5: `f3824e4b85940fcd8fbfe8f9a566519b`
* 大小：约 29 MB

### 系统要求

* **HarmonyOS API 12 及以上** 的设备（如 nova 14 活力版 / Mate 60 / Pura 70 等）
* 64 位 ARM 架构（`arm64-v8a`）
* 推荐内存 ≥ 6 GB

### 安装步骤

1. 在设备上开启 **开发者模式** 与 **USB 调试**。
2. 连接到已安装 `hdc` 工具的电脑，执行：

   ```bash
   hdc install MiniCPM-V-demo-HarmonyOS-v1.1.hap
   ```
3. 打开 App，进入应用内的 **模型管理** 页面点击 **下载模型** 即可。

> 华为应用市场的上架渠道正在准备中，目前请先使用上方的 HAP 安装包。

---

## 注意事项

* 三端 App 在 **首次启动** 时都会下载 GGUF 模型文件（数 GB），建议使用 Wi-Fi 完成首次下载。
* 当前版本仅用于 **研究 / 预览**，并非正式产品。
* 发现问题或有改进建议？欢迎提交 [Issue](https://github.com/tc-mb/MiniCPM-V-edge-demo/issues)，或通过 TestFlight（iOS）反馈。

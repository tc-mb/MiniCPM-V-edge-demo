# 下载 MiniCPM-V Demo 应用

[English](DOWNLOAD.md) | **中文**

下面列出了 **iOS**、**Android** 和 **HarmonyOS NEXT** 三端预编译 App 的下载方式。三端均通过 `llama.cpp` 在 **本地端侧** 运行 MiniCPM-V 多模态模型——无需服务端、无需联网推理，数据不离开手机。

> 想从源码自行构建？请参考根目录 [README_zh.md](README_zh.md)。

---

## iOS —— TestFlight 公测版

**公开链接：** [https://testflight.apple.com/join/yNKyFZwW](https://testflight.apple.com/join/yNKyFZwW)

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

## Android —— APK（即将放出）

预编译 **APK 暂未发布**。你看到的所有 Android 端 demo 视频和截图，都是直接基于本仓库的源码录制的，行为与现在自行构建出来的版本完全一致。

公开 APK 仍在打磨中，很快会发布。早期版本可能会有一些瑕疵，我们会持续更新，也非常希望社区能多给我们 **提 issue / 反馈**。

在 APK 上线之前，你可以：

* 直接从源码构建运行 Android demo，详见 [README_zh.md](README_zh.md#2-android-demo) 的 **Android Demo** 章节。
* 关注 [GitHub Releases](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases)（或在仓库点 **Watch → Custom → Releases**），首个 APK 发布后会第一时间收到通知。
* 在 [Issues](https://github.com/tc-mb/MiniCPM-V-edge-demo/issues) 提交任何问题或建议。

---

## HarmonyOS NEXT —— HAP（即将放出）

预编译 **HAP 暂未发布**。你看到的所有 HarmonyOS 端 demo 视频和截图同样来自本仓库的源码，与现在自行构建出来的版本完全一致。

公开 HAP 仍在打磨中，很快会发布。早期版本难免会有一些瑕疵，我们会快速迭代，也非常希望大家能多多 **提 issue**，帮我们尽快定位问题。

在 HAP 上线之前，你可以：

* 直接从源码构建运行 HarmonyOS demo，详见 [README_zh.md](README_zh.md#3-harmonyos-demo) 的 **HarmonyOS Demo** 章节。
* 关注 [GitHub Releases](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases)，首个 HAP 发布后会第一时间通知到你。
* 在 [Issues](https://github.com/tc-mb/MiniCPM-V-edge-demo/issues) 提交任何问题或建议。

---

## 注意事项

* 三端 demo 视频 / 截图均直接基于本仓库源码录制；后续放出的预编译 APK / HAP 也将由同一份源码直接打包。
* 三端 App 在 **首次启动** 时都会下载 GGUF 模型文件（数 GB），建议使用 Wi-Fi 完成首次下载。
* 当前版本仅用于 **研究 / 预览**，并非正式产品。
* 预编译 APK / HAP 的早期版本难免会有瑕疵，我们会持续更新。发现问题或有改进建议？欢迎到 [Issues](https://github.com/tc-mb/MiniCPM-V-edge-demo/issues) 提交，或通过 TestFlight（iOS）反馈，我们会尽快跟进。

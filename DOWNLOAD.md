# Install MiniCPM-V Apps

**English** | [中文](DOWNLOAD_zh.md)

Pre-built apps for **iOS**, **Android**, and **HarmonyOS NEXT** are listed below. All three apps run the MiniCPM-V multimodal model fully **on-device** via `llama.cpp` — no remote server, no data leaves your phone.

> Looking to build from source instead? See the main [README](README.md).

---

## iOS — TestFlight

**Public link:** [https://testflight.apple.com/join/yNKyFZwW](https://testflight.apple.com/join/yNKyFZwW)

### Requirements

* iPhone or iPad running **iOS / iPadOS 16 or later**
* Recommended: a device with ≥ 6 GB RAM (e.g. iPhone 15 Pro / iPad with M-series chip) for smooth on-device inference
* The TestFlight app installed from the App Store

### How to install

1. Install **TestFlight** from the App Store on your iPhone or iPad.
2. Open the public link above on the same device, then tap **Accept** → **Install**.
3. Launch **MiniCPM-V Demo** from the Home Screen and follow the in-app prompts to download the model files.

> Each TestFlight build is valid for up to 90 days. When a new build is published, TestFlight will notify you.

---

## Android — APK (Coming Soon)

The pre-built **APK is not released yet.** All Android demo videos and screenshots you may have seen are recorded directly from the source code in this repository, so the behaviour is exactly what you would build locally today.

The public APK is still being polished and will be published shortly. Early builds may have rough edges; we plan to iterate frequently and **welcome issues and feedback**.

In the meantime you can:

* Build and run the Android demo from source — see the [Android Demo section in the README](README.md#2-android-demo).
* Watch the [GitHub Releases](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases) page (or **Watch → Custom → Releases** on the repo) to be notified when the first APK is published.
* File any problems or suggestions in [Issues](https://github.com/tc-mb/MiniCPM-V-edge-demo/issues).

---

## HarmonyOS NEXT — HAP (Coming Soon)

The pre-built **HAP is not released yet.** All HarmonyOS demo videos and screenshots come from the source code in this repository, exactly the same code you can build today.

The public HAP is still being polished and will be published shortly. Early builds may have rough edges; we will iterate quickly — please **open issues** so we can prioritise fixes.

In the meantime you can:

* Build and run the HarmonyOS demo from source — see the [HarmonyOS Demo section in the README](README.md#3-harmonyos-demo).
* Subscribe to [GitHub Releases](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases) for the first HAP drop.
* File any problems or suggestions in [Issues](https://github.com/tc-mb/MiniCPM-V-edge-demo/issues).

---

## Notes

* All demo videos / screenshots across the three platforms are recorded from this repository's source code; the upcoming pre-built APK / HAP packages will be built straight from the same code.
* The first launch of any of the three apps will download the GGUF model files (a few GB). Use Wi-Fi for the initial download.
* These demos are intended for **research / preview** only and are not optimised products.
* Early pre-built APK / HAP releases may have rough edges — we will keep updating them. Please file an [issue](https://github.com/tc-mb/MiniCPM-V-edge-demo/issues) or send feedback through TestFlight (iOS) so we can improve quickly.

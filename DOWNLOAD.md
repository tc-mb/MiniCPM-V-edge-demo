# Install MiniCPM-V Apps

**English** | [中文](DOWNLOAD_zh.md)

Pre-built apps for **iOS**, **Android**, and **HarmonyOS NEXT** are listed below. All three apps run the MiniCPM-V multimodal model fully **on-device** via `llama.cpp` — no remote server, no data leaves your phone.

> Looking to build from source instead? See the main [README](README.md).

---

## iOS — TestFlight

**Public link:** [https://testflight.apple.com/join/yNKyFZwW](https://testflight.apple.com/join/yNKyFZwW)

> **Heads up — iOS ships slower than Android / HarmonyOS.**
> Every iOS build has to clear Apple's TestFlight review before it reaches users, so new features and bug fixes on iOS typically land **several days to a couple of weeks behind** the Android APK and HarmonyOS HAP releases. If you need the latest fix immediately, please use the Android or HarmonyOS package on this page.

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

## Android — APK

**Latest:** **v1.7** &nbsp;·&nbsp; [Download `MiniCPM-V-demo-Android-v1.7.apk`](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases/download/android-v1.7/MiniCPM-V-demo-Android-v1.7.apk) &nbsp;·&nbsp; [Release notes](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases/tag/android-v1.7) &nbsp;·&nbsp; [All versions](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases?q=tag%3Aandroid)

* MD5: `9d16d89205cc6c43b68886a42b560600`
* Size: ~16 MB

### Requirements

* Android device with a **64-bit ARM SoC** (`arm64-v8a`)
* **Android 8.0 (API 26) or later**
* ≥ 6 GB RAM recommended

### How to install

1. Download the latest `.apk` from the link above onto your phone.
2. If you see a security prompt, allow installation from this source in **Settings → Apps → Install unknown apps**.
3. Open the installed **MiniCPM-V Demo** app and tap **Download** in the in-app **Model Manager** to fetch the GGUF model files.

---

## HarmonyOS NEXT — HAP

**Latest:** **v1.1** &nbsp;·&nbsp; [Download `MiniCPM-V-demo-HarmonyOS-v1.1.hap`](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases/download/harmonyos-v1.1/MiniCPM-V-demo-HarmonyOS-v1.1.hap) &nbsp;·&nbsp; [Release notes](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases/tag/harmonyos-v1.1) &nbsp;·&nbsp; [All versions](https://github.com/tc-mb/MiniCPM-V-edge-demo/releases?q=tag%3Aharmonyos)

* MD5: `f3824e4b85940fcd8fbfe8f9a566519b`
* Size: ~29 MB

### Requirements

* HarmonyOS device on **API 12 or later** (e.g. nova 14 Vitality / Mate 60 / Pura 70)
* 64-bit ARM (`arm64-v8a`)
* ≥ 6 GB RAM recommended

### How to install

1. Enable **Developer Mode** and **USB debugging** on the device.
2. Connect to a PC with `hdc` installed, then run:

   ```bash
   hdc install MiniCPM-V-demo-HarmonyOS-v1.1.hap
   ```
3. Open the installed app and tap **Download** in the in-app **Model Manager** to fetch the model files.

> The HarmonyOS distribution channel inside Huawei AppGallery is being prepared; for now please use the HAP package above.

---

## Notes

* The first launch of any of the three apps will download the GGUF model files (a few GB). Use Wi-Fi for the initial download.
* These demos are intended for **research / preview** only and are not optimised products.
* Found a bug or have a suggestion? Please file an [issue](https://github.com/tc-mb/MiniCPM-V-edge-demo/issues) or send feedback through TestFlight (iOS).

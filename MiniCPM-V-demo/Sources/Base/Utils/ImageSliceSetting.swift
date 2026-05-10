//
//  ImageSliceSetting.swift
//  MiniCPM-V-demo
//
//  Persists the user-chosen "max image slices" value (1..9) used by
//  MiniCPM-V's llava-uhd style pre-processing.  Mirrors LlamaEngine.kt
//  (Android) and LlamaEngine.ets (HarmonyOS) bounds so the three demos
//  expose the same chat-page slider semantics.
//
//  Read on every model (re)load to seed mtmd_init_from_file via
//  MTMDParams.imageMaxSliceNums; written by the chat-page settings popup.
//  Live updates additionally call mtmd_ios_set_image_max_slice_nums to
//  patch the in-flight clip context without reloading mmproj.
//

import Foundation

enum ImageSliceSetting {
    /// MiniCPM-V hard upper bound; clip.cpp::get_best_grid clamps higher
    /// values anyway.  Keep in sync with LlamaEngine.kt::MAX_IMAGE_SLICE.
    static let maxSlice: Int = 9
    /// 1 = no slicing (single overview image, ~9× fewer tokens, fastest).
    static let minSlice: Int = 1
    /// First-launch default = MiniCPM-V's full slice budget, so image
    /// quality matches the model card out of the box.  Users who care
    /// about prefill latency drop the chat-page slider down to 1.
    /// Mirrors LlamaEngine.kt::DEFAULT_IMAGE_SLICE on Android.
    static let defaultSlice: Int = 9

    private static let userDefaultsKey = "mtmd_image_max_slice_nums"

    /// Current persisted value, clamped to [minSlice, maxSlice].
    static var current: Int {
        let raw = UserDefaults.standard.object(forKey: userDefaultsKey) as? Int ?? defaultSlice
        return max(minSlice, min(maxSlice, raw))
    }

    /// Persist a new value (clamped).  Call site is responsible for also
    /// pushing the value to a live MTMD context via
    /// `MTMDWrapper.setImageMaxSliceNums(_:)` if one is loaded.
    static func update(_ n: Int) {
        let clamped = max(minSlice, min(maxSlice, n))
        UserDefaults.standard.set(clamped, forKey: userDefaultsKey)
    }
}

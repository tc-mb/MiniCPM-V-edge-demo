//
//  MBVideoFrameExtractor.swift
//  MiniCPM-V-demo
//
//  Created by Alex on 2024/7/15.
//

import Foundation
import AVFoundation
import UIKit

/// 视频（mp4 / mov / heic-live）抽帧器。
///
/// 视频理解的抽帧策略（与 MiniCPM-V 4.6 视频帧推理约定对齐）：
/// - 时长 ≤ `maxSupportedFrames` 秒：每秒抽 1 帧（标准 1fps）；
/// - 时长 >  `maxSupportedFrames` 秒：均匀抽 `maxSupportedFrames` 帧；
///   均匀抽帧使用浮点 / 600 时基，避免老逻辑用整数除法带来的"最后 N 秒丢帧"。
///
/// 抽出的帧按时间顺序进入回调，调用方应保证顺序送入 mtmd prefill_frame。
@MainActor
class MBVideoFrameExtractor: Sendable {
    let videoURL: URL

    /// 采样率（仅在 totalSeconds ≤ maxSupportedFrames 的"1fps 分支"使用）。
    /// 超出上限走均匀抽帧时不再使用，保留只是为了让外部 debug 输出有信息。
    var framesPerSecond = 1

    /// 最多抽多少帧。MiniCPM-V 4.6 demo 推荐 64，旧 V2.6/V4.0 走 16。
    var maxSupportedFrames = 16

    // 抽取的视频帧
    var frameImages = [UIImage]()

    init(videoURL: URL, fps: Int, supportTotalFrames: Int = 16) {
        self.videoURL = videoURL
        self.framesPerSecond = fps
        if supportTotalFrames > 0 {
            self.maxSupportedFrames = supportTotalFrames
        }
    }

    /// 抽取视频帧，按时间顺序回调一组 UIImage。
    func extractFrames(handler: (([UIImage]?)->Void)?) async {

        frameImages.removeAll()

        let asset = AVAsset(url: videoURL)

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        var duration: CMTime?

        do {
            duration = try await asset.load(.duration)
        } catch let err {
            debugLog("extractFrames.err = \(err)")
        }

        guard let duration = duration else {
            handler?(nil)
            return
        }

        if framesPerSecond <= 0 {
            framesPerSecond = 1
        }

        let totalSeconds = CMTimeGetSeconds(duration)
        if !totalSeconds.isFinite || totalSeconds <= 0 {
            handler?(nil)
            return
        }

        // 决定本次抽帧的"目标帧数"与时间戳列表。
        // 用 600 时基保证 30/29.97/24fps 视频都能整数化的同时不丢精度。
        let timescale: CMTimeScale = 600
        var times: [NSValue] = []
        let isUniformMode: Bool

        let secondsCeil = Int(ceil(totalSeconds))
        if secondsCeil <= maxSupportedFrames {
            // 1fps 分支：抽 `secondsCeil` 帧。每帧落在第 i 秒末尾附近（i + 0.5s），
            // 避免取到第 0 秒的黑/灰封面帧。
            isUniformMode = false
            framesPerSecond = 1
            let frames = max(1, secondsCeil)
            for i in 0..<frames {
                let t = min(totalSeconds - 0.01, Double(i) + 0.5)
                times.append(NSValue(time: CMTime(seconds: max(0, t),
                                                  preferredTimescale: timescale)))
            }
        } else {
            // 均匀抽帧分支：在 [0, totalSeconds) 等分 `maxSupportedFrames` 段，
            // 取每段中点。这样首尾两帧不会贴边、不会越界。
            isUniformMode = true
            let frames = maxSupportedFrames
            let step = totalSeconds / Double(frames)
            for i in 0..<frames {
                let t = Double(i) * step + step / 2.0
                times.append(NSValue(time: CMTime(seconds: t,
                                                  preferredTimescale: timescale)))
            }
            // framesPerSecond 在 UI 日志里仅作展示
            framesPerSecond = max(1, Int(round(1.0 / step)))
        }

        let totalFrames = times.count

        debugLog("-->> 视频时长 \(String(format: "%.2f", totalSeconds))s，maxFrames=\(maxSupportedFrames)，模式=\(isUniformMode ? "uniform" : "1fps")，预计 \(totalFrames) 帧。")
        debugLog("begin generate.")

        // 用 [Int : UIImage] 先按"请求时间索引"缓存，确保最终顺序与 times 一致，
        // 因为 AVAssetImageGenerator 的回调顺序在某些设备上并不严格按请求顺序。
        let timesSeconds: [Double] = times.map { CMTimeGetSeconds($0.timeValue) }
        var indexedFrames: [Int: UIImage] = [:]
        var doneCount = 0

        imageGenerator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, cgImage, actualTime, result, error in

            // 不论 success/failed 都要计数，否则一帧失败会卡住 handler
            defer {
                doneCount += 1
                if doneCount == totalFrames {
                    // 按时间顺序展开
                    let ordered: [UIImage] = (0..<totalFrames).compactMap { indexedFrames[$0] }
                    Task { @MainActor in
                        self.frameImages = ordered
                        debugLog("-->> 视频抽帧完成，请求 \(totalFrames) 帧，成功 \(ordered.count) 帧。")
                        handler?(self.frameImages)
                    }
                }
            }

            guard error == nil else {
                debugLog("Frame error @\(CMTimeGetSeconds(requestedTime))s: \(String(describing: error))")
                return
            }
            guard let cgImage = cgImage else {
                debugLog("Frame missing @\(CMTimeGetSeconds(requestedTime))s")
                return
            }

            // 找到 requestedTime 在 times 数组中的下标，作为最终顺序键
            let reqSec = CMTimeGetSeconds(requestedTime)
            var matchedIndex = 0
            var bestDelta = Double.infinity
            for (idx, ts) in timesSeconds.enumerated() {
                let d = Swift.abs(ts - reqSec)
                if d < bestDelta {
                    bestDelta = d
                    matchedIndex = idx
                }
            }

            indexedFrames[matchedIndex] = UIImage(cgImage: cgImage)
            debugLog("Generated frame[\(matchedIndex)] @\(String(format: "%.2f", reqSec))s")
        }
    }
}

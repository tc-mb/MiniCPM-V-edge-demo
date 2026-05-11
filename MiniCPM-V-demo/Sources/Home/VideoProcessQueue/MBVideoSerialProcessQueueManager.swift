//
//  MBVideoSerialProcessQueueManager.swift
//  MiniCPM-V-demo
//
//  Created by Alex on 2024/7/19.
//

import Foundation
import UIKit
import llama

/// 串行处理 vidoe frame embed + input 的 queue
class MBVideoSerialProcessQueueManager: NSObject {
    
    // Singleton
    static let shared = MBVideoSerialProcessQueueManager()

    private var taskCount: Int = 0
    
    // 创建一个全局的串行队列
    private let serialQueue = DispatchQueue(label: "com.tianchi.minicpmv.video.serial.process.queue")
    
    func serialProcessVideoFrame(image: UIImage?, index: Int, mtmdWrapperExample: MTMDWrapperExample?, embedType: ImageEmbeddingTypeV2) async -> Bool {
        
        incrementTaskCount()

        defer {
            decrementTaskCount()
        }
        
        guard let img = image, let mtmdWrapperExample = mtmdWrapperExample else {
            return false
        }

        // 抽帧之后，依次把截图给到模型
        // step.1 save 到本地磁盘的 cache folder 里，然后去 embed 和 input 到模型里
        debugLog("-->> selected.video.image = \(img)")

        // 把视频帧以 jpeg 格式，90% 质量，保存到 cache 中
        let timestamp = Int(Date().timeIntervalSince1970)
        let randomNumber = Int.random(in: 1000...9999)
        let filename = "myvfs_\(timestamp)_\(randomNumber).jpeg"
        
        if let imgURL = self.saveImageToCache(image: img, fileName: filename, compressionQuality: 0.5) {
            debugLog("-->> index = \(index), begin.embed.video.frame = \(imgURL.pathComponents.last ?? "")")
            // 量整帧 prefill 的墙钟耗时（包含 JPEG decode + clip preprocess + ViT
            // 推理 + KV insert）。配合 NSLog 里 [MTMD_CoreML] predictWith call#N
            // 的 CoreML 单次耗时，可以判断：
            //   - frame#0 远大于 frame#1+        → ANE 编译耗时落在首帧（生效）
            //   - 每帧耗时平稳且偏大（~500ms+）→ ANE 没生效，跑 GPU/CPU 回退
            //   - frame ms ≈ CoreML ms          → 几乎全部时间在视觉编码上
            //   - frame ms >> CoreML ms         → KV insert / IO 也占大头
            let frameStart = Date()
            let ret = await mtmdWrapperExample.addFrameInBackground(imgURL.path)
            let frameMs = Int(Date().timeIntervalSince(frameStart) * 1000)
            debugLog("-->> [video] frame#\(index) prefill 耗时 \(frameMs) ms, ret=\(ret)")
            return ret
        }
        
        return false
    }
    
    private func incrementTaskCount() {
        taskCount += 1
    }
    
    private func decrementTaskCount() {
        taskCount -= 1
    }
    
    public var isQueueEmpty: Bool {
        return taskCount == 0
    }

    public var runningTaskCount: Int {
        return taskCount
    }
    
    /// 保存 UIImage 到 沙箱 cache folder 里
    private func saveImageToCache(image: UIImage,
                                  fileName: String,
                                  asJPEGFormat: Bool = true,
                                  compressionQuality: CGFloat = 1) -> URL? {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let fileUrl = cacheDirectory?.appendingPathComponent(fileName)
        
        var data: Data?
        
        if asJPEGFormat {
            data = image.jpegData(compressionQuality: compressionQuality)
        } else {
            data = image.pngData()
        }
        
        guard let imageData = data, let url = fileUrl else { return nil }

        do {
            try imageData.write(to: url)
        } catch {
            debugLog("saveImageToCache(:) error.")
            return nil
        }

        return url
    }
}

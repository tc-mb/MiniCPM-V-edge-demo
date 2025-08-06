//
//  MBModelDownloadHelperV2.swift
//  MiniCPM-V-demo
//
//  Created by Alex on 2027/07/18.
//

import Foundation

import llama

/// 大模型下载管理器，可以同时下载 主模型 和 图像识别模型
class MBModelDownloadHelperV2: NSObject {
    
    /// 外部（调用方）传入的引用
    private var mtmdWrapperExample: MTMDWrapperExample

    /// 模型文件名
    private var modelName: String
    
    /// 模型对应服务器下载地址
    public var modelUrl: String

    /// 模型备用下载地址
    public var backupModelUrl: String?
    
    /// 文件名（有扩展名）
    private var filename: String
    
    /// 当前模型的下载状态【没有下载前需要下载】
    public var status: String
    
    private var downloadTask: URLSessionDownloadTask?
    
    /// 下载进度
    private var progress = 0.0
    
    public var observation: NSKeyValueObservation?
    
    // 定义一个闭包类型的属性
    public var completionHandler: ((CGFloat) -> Void)?
    
    /// 当前选中的模型
    private var loadedStatus: Bool
    
    /// 获取模型对应的本地路径
    private static func getFileURL(filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    }
    
    /// 模型下载管理器初始化方法
    /// - Parameters:
    ///   - wrapper: 外部传入的 MTMDWrapperExample 结构体的引用
    ///   - modelName: 模型名字
    ///   - modelUrl: 模型下载 url 地址
    ///   - filename: 本地文件名
    init(wrapper: MTMDWrapperExample, modelName: String, modelUrl: String, filename: String, backupModelUrl: String? = nil) {
        self.mtmdWrapperExample = wrapper
        self.modelName = modelName
        self.modelUrl = modelUrl
        self.backupModelUrl = backupModelUrl
        self.filename = filename
        
        // 获取模型本地 url
        let fileURL = MBModelDownloadHelperV2.getFileURL(filename: filename)
        
        // 模型是否存在
        status = FileManager.default.fileExists(atPath: fileURL.path) ? "downloaded" : "download"
        
        // 模型选中的模型
        loadedStatus = false
    }
}

extension MBModelDownloadHelperV2 {
    
    /// 断点续传下载器，支持主/备用链接
    public func downloadV2(completionBlock: @escaping (String, CGFloat) -> Void) {
        
        if status == "downloaded" {
            return
        }
        
        func tryDownload(from url: String, isBackup: Bool = false) {

            FDownLoaderManager.shareInstance().downLoader(URL(string: url)) { totalSize in
                debugLog("-->> totalsize = \(totalSize)")
            } progress: { [weak self] progress in
                self?.progress = Double(progress)
                completionBlock(self?.status ?? "", CGFloat(progress))
            } success: { [weak self] cachePath in
                guard let cachePath = cachePath else {
                    return
                }
                debugLog("-->> cachePath = \(cachePath)")
                do {
                    let fileURL = MBModelDownloadHelperV2.getFileURL(filename: self?.filename ?? "")
                    let temporaryURLString = String(format: "file://%@", cachePath)
                    if let cacheURL = URL(string: temporaryURLString) {
                        try FileManager.default.moveItem(at: cacheURL, to: fileURL)
                        debugLog("Writing to \(self?.filename ?? "") completed")
                        DispatchQueue.main.async {
                            let model = ModelV2(name: self?.modelName ?? "", url: self?.modelUrl ?? "", filename: self?.filename ?? "", status: "downloaded")
                            self?.mtmdWrapperExample.downloadedModels.append(model)
                            self?.status = "downloaded"
                            if let s = self?.status {
                                completionBlock(s, 1.0)
                            }
                        }
                    }
                } catch let err {
                    debugLog("Error: \(err.localizedDescription)")
                }
            } failed: { [weak self] in
                FDownLoaderManager.shareInstance().downLoaderInfo.removeAllObjects()
                debugLog("-->> 下载失败.")
                if !isBackup, let backupUrl = self?.backupModelUrl {
                    debugLog("-->> 尝试备用下载链接: \(backupUrl)")
                    tryDownload(from: backupUrl, isBackup: true)
                } else {
                    completionBlock("failed", -1)
                }
            }
        }
        
        // 首先尝试主链接
        tryDownload(from: modelUrl)
    }
}

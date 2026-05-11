//
//  MBHomeViewController+ImageProcess.swift
//  MiniCPM-V-demo
//
//  Created by Alex on 2024/6/27.
//

import Foundation
import UIKit
import HXPhotoPicker

/// 图片 prefill 阶段的最终 UI 状态。
///
/// 用来在 prepareLoadModelAddImageToCell 的兜底分支里区分"成功 / 超时 /
/// 失败 / 跳过"，分别在 cell 的 performLog 里写不同文案。把这个 enum 抽到
/// extension 外面，避免和 MBHomeViewController 类体里的其它 nested type 冲突。
enum ImagePrefillUIStatus {
    case succeeded
    case timeout
    case failed(String)
    case skipped
}

extension MBHomeViewController {

    // MARK: - 图片 embed & clip
    
    /// 异步更新当前选中的（应用）模型的类型（例如语言模型 还是 多模态模型）
    func updateCurrentUsingModelType(_ type: CurrentUsingModelTypeV2) async {
        self.currentUsingModelType = type
    }
    
    /// 使用 用户选择的模型 和 image 初始化模型
    public func prepareLoadModelAddImageToCell() {
        Task.detached(priority: .userInitiated) {
            // 一次只加载一张图片并让模型 embedding 完成后，才能再加载另一张图片。
            // uploadSingleImageToModel 在 prefill 期间被置为 true，把
            // processImageAndTextMixModeSendLogic / 重复选图都阻断掉，防止两个
            // mtmd 操作并发跑同一个 ctx（n_past 状态会乱、生成会"没回复"）。
            if await !self.uploadSingleImageToModel {

                await self.updateSingleImageUploadAndProcessStatus(true)

                await self.startLogTimer()

                // 真实耗时用墙钟单独计量，比从 main RunLoop 上 logTimer
                // 0.1s tick 累加更稳：prefill 期间 main runloop 上可能
                // 跑了 cell.bindImageWith / 加载动画等，Timer fire 会少计 tick，
                // 之前 cell 上显示"预处理耗时：0.0s"就是这个原因。
                let processStart = Date()

                // 用枚举把 prefill 的最终状态记下来，由 finalize 兜底统一刷 UI。
                // 这样无论 await 抛错（ANE 加载失败）还是超时（CoreML hang），
                // cell 上一定会被更新成可读的状态，不会停在"图片有但没耗时"。
                var status: ImagePrefillUIStatus = .skipped

                if let imgPath = await self.outputImageURL?.path {
                    do {
                        if let example = await self.mtmdWrapperExample {
                            try await example.addImageInBackgroundThrowing(imgPath)
                            status = .succeeded
                            print("[UI]addImage: \(imgPath) ok")
                        } else {
                            status = .failed("MTMD wrapper not ready")
                        }
                    } catch let MTMDError.timeout(msg) {
                        status = .timeout
                        print("[UI]addImage timeout: \(msg)")
                    } catch {
                        status = .failed(error.localizedDescription)
                        print("[UI]addImage error: \(error)")
                    }
                }

                let elapsed = Date().timeIntervalSince(processStart)
                await self.finalizeImagePrefillUI(status: status, elapsed: elapsed)
                await self.updateSingleImageUploadAndProcessStatus(false)
            }
        }
    }

    /// 统一把 prefill 结束后的 UI 兜底刷新出来：
    /// - stopLogTimer
    /// - 写 cell 的 performLog（成功展示耗时；失败 / 超时显式提示用户）
    /// - 清掉 outputImageView 的预览图
    ///
    /// `elapsed` 由调用方用墙钟（Date()）量出来传进来。早期版本是从
    /// `logTimeSecond` 读，但那个值依赖 main RunLoop 上的 0.1s Timer fire，
    /// 在 prefill 期间 main 被 cell 渲染挡住时会少 tick 甚至 0 tick，UI 上
    /// 就显示成"预处理耗时：0.0s"。墙钟值永远正确。
    ///
    /// 这是一个 @MainActor 函数，所有 UI 操作都在 main 上跑。
    @MainActor
    func finalizeImagePrefillUI(status: ImagePrefillUIStatus, elapsed: TimeInterval) {
        self.stopLogTimer()

        if self.dataArray.count > 0,
           let latestCell = self.tableView.cellForRow(at: IndexPath(row: self.dataArray.count - 1, section: 0)) as? MBImageTableViewCell {
            if latestCell.model?.role == "user",
               latestCell.model?.contentImage != nil {

                let size = MBHomeViewController.formatBytesAsKBMB(self.outputImageFileSize)

                // 不同状态下渲染不同的 perfLog 文案。timeout / failed 用更显眼
                // 的文案让用户直观感知到 ANE / CoreML 出问题了，而不是"卡住没反应"。
                let perfLog: String
                switch status {
                case .succeeded:
                    let timeInSeconds = String(format: "%.1f", elapsed)
                    perfLog = "\t\t预处理耗时：\(timeInSeconds)s"
                case .timeout:
                    perfLog = "\t\t预处理超时（>\(Int(MTMDWrapper.defaultPrefillTimeoutSeconds))s）"
                case .failed(let reason):
                    let trimmed = reason.count > 24 ? String(reason.prefix(24)) + "…" : reason
                    perfLog = "\t\t预处理失败：\(trimmed)"
                case .skipped:
                    perfLog = "\t\t预处理已跳过"
                }

                // 处理完成后，这个值总是 -1（让进度条收尾到 100%）
                latestCell.model?.processProgress = -1

                latestCell.model?.performLog = "\(Int(self.outputImageView.image?.size.width ?? 0))x\(Int(self.outputImageView.image?.size.height ?? 0)) (\(size)) \(perfLog)"
                latestCell.bindImageWith(data: latestCell.model)
            }
        }

        // 使用过一次就清除
        self.outputImageView.image = nil
    }
    
    /// 更新多图模型加载状态
    func updateImageLoadedStatus(_ status: Bool) async {
        self.imageLoaded = status
    }
    
    /// 用户在 toolbar 选择单张图上传时 上传状态
    func updateSingleImageUploadAndProcessStatus(_ status: Bool) async {
        self.uploadSingleImageToModel = status
    }
}

extension MBHomeViewController {
    
    public func selectedImagePreprocess(result: PickerResult?, urls: [URL], iv: UIImage) {
        
        guard let result else {
            return
        }
        
        // 选中的图片大小（KB，MB）
        self.outputImageFileSize = UInt64(result.photoAssets.first?.fileSize ?? 0)
        
        // 重置这个变量
        self.hasImageAndTextConversation = false
        
        // 最近一次选中的图片
        self.outputImageView.image = iv
        
        // 加一个处理 heic 格式的逻辑
        let tmpURL = urls.first
        
        if tmpURL?.absoluteString.lowercased().contains(".heic") == true {
            if let url = self.saveImageToCache(image: iv,
                                               fileName: "myImage_heic_\(self.outputImageFileSize)_\(arc4random()).jpeg", compressionQuality: 0.5) {
                self.outputImageURL = url
                debugLog("选择了 .heic 格式图片。")
            }
        } else if let tmpURL = tmpURL {
            if let imageData = try? Data(contentsOf: tmpURL) {
                if imageData.isWebP {
                    if let url = self.saveImageToCache(image: iv,
                                                       fileName: "myImage_webp_\(self.outputImageFileSize)_\(arc4random()).png") {
                        self.outputImageURL = url
                        debugLog("选择了 .webp 格式图片。")
                    }
                } else {
                    self.outputImageURL = tmpURL
                }
            } else {
                self.outputImageURL = tmpURL
            }
        } else {
            self.outputImageURL = urls.first
        }
    }
    
    /// 输入栏「选择图片」按钮点击事件
    @objc public func handleChooseImage(_ sender: UIButton) {

        if thinking {
            self.showErrorTips("处理中，请稍等")
            return
        }

        // 上一张图还在 mtmd_ios_prefill_image 中，禁止并发选第二张：
        // 不然两次 prefill_image 在 DispatchQueue.global 上并发跑同一个
        // mtmd_context，n_past 与图像 token KV 会全部错位。
        if self.uploadSingleImageToModel {
            self.showErrorTips("上一张图片预处理中，请稍等")
            return
        }
        
        // 单选 + 只能单选图片 or 视频（v2.6 的功能）
        var config = PickerConfiguration.default
        config.selectMode = .single
        
        // 不允许选择 photo 和 video
        if self.fullscreenEditor {
            // 全屏只允许选图片
            config.selectOptions = [.photo]
        } else {
            // 收起态时，可以选图片或视频
            config.selectOptions = [.photo, .video]
        }
        
        config.maximumSelectedCount = 1
        config.maximumSelectedPhotoCount = 1
        config.isSelectedOriginal = true
        
        // 方法三：
        Photo.picker(
            config
        ) { result, pickerController in
            
            // 选择完图片后的回调
            Task {
                let images: [UIImage] = try await result.objects()
                let urls: [URL] = try await result.objects()
                DispatchQueue.main.async {
                    let image = images.first
                    if let iv = image {
                        // 预先处理一下从相册中选中的图片（附带转换不支持的 .webp 格式）
                        self.selectedImagePreprocess(result: result, urls: urls, iv: iv)
                        
                        // step.1 UI 更新：先把图片显示到 UITableview 列表里
                        if (self.outputImageURL != nil) && self.outputImageView.image != nil {
                            
                            var videoURL: String? = nil
                            
                            if let photoAsset = result.photoAssets.first,
                               photoAsset.mediaType == .video {
                                // 只有 video 才加这个 url
                                videoURL = self.outputImageURL?.absoluteString
                            }
                            
                            self.appendImageDataToCellWith(image: self.outputImageView.image, imageURL: videoURL)
                            
                            // 滚动到底部
                            self.tableViewScrollToBottom()
                            
                            self.mtmdWrapperExample?.performanceLog = ""
                            
                            // 为了将来能预览视频，需要在这儿把 photoAsset 先 cache 起来
                            if let keyStr = self.outputImageURL?.absoluteString,
                               !keyStr.isEmpty,
                               let photoAsset = result.photoAssets.first,
                               photoAsset.mediaType == .video {
                                
                                self.cachedPhotoAssets[keyStr] = photoAsset
                                
                                debugLog("-->> selected.video = \(photoAsset)")
                                
                                Task {

                                    // 因为在 outputImageURL 放着是 video 的 path
                                    // 进行 video 抽帧处理
                                    if let path = self.outputImageURL?.path() {
                                        let videoURL = URL(fileURLWithPath: path)

                                        // 视频抽帧上限：MiniCPM-V 4.6 走 64 帧（1fps，超长则均匀抽帧），
                                        // 老的 V2.6 / V4.0 维持 16 帧上限避免回归（旧 demo 时代的视频路径）。
                                        let maxFrames = (self.mtmdWrapperExample?.currentUsingModelType == .V46MultiModel)
                                            ? 64
                                            : 16
                                        let extractor = MBVideoFrameExtractor(videoURL: videoURL,
                                                                              fps: 1,
                                                                              supportTotalFrames: maxFrames)

                                        // 异步视频抽帧算法
                                        await extractor.extractFrames { [weak self] images in
                                            if let images = images {
                                                Task {
                                                    await self?.processVideoFrame(images: images)
                                                }
                                                // end if let images
                                            }
                                            // end extractFrames
                                        }
                                    }
                                }
                            } else {
                                // 从图片选择器选中的是普通图片，不是视频，直接到 else 里
                                if self.outputImageURL?.absoluteString.contains(".mp4") == false ||
                                    self.outputImageURL?.absoluteString.contains(".mov") == false {
                                    self.prepareLoadModelAddImageToCell()
                                }
                                
                            }
                        }
                    }
                }
            }
            
        } cancel: { pickerController in
            // image picker 取消的回调
            debugLog("-->> \(pickerController)")
        }
    }
}

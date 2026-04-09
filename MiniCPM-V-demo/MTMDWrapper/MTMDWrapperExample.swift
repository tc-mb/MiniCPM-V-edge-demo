//
//  MTMDWrapperExample.swift
//  MiniCPM-V-demo
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation
import Combine
import llama

struct ModelV2: Identifiable {
    var id = UUID()
    var name: String
    var url: String
    var filename: String
    var status: String?
}

/// 当前使用的模型
enum CurrentUsingModelTypeV2 {
    /// 未知
    case Unknown
    /// V26 多模态模型
    case V26MultiModel
    /// V4 多模态模型
    case V4MultiModel
    /// V4.6 多模态模型
    case V46MultiModel
}

/// 将要 embedding 的图片的来源
enum ImageEmbeddingTypeV2: Int {
    /// 照片或纯图片
    case Picture = 0
    /// 视频帧
    case VideoFrame = 1
    /// 实时视频帧
    case LiveVideoFrame = 2
}

/// MTMDWrapper 使用示例
@MainActor
public class MTMDWrapperExample: ObservableObject {
    
    /// MTMD 包装器实例
    internal let mtmdWrapper = MTMDWrapper()
    
    /// 取消令牌集合
    private var cancellables = Set<AnyCancellable>()
    
    /// 当前输出文本
    @Published var outputText: String = ""
    
    /// 是否正在生成
    @Published var isGenerating: Bool = false
    
    /// 错误信息
    @Published var errorMessage: String = ""
    
    /// 参数配置
    private var params: MTMDParams?
    
    /// 配置相关-begin
    
    /// 保存着所有已经下载（生效）的模型
    @Published var downloadedModels: [ModelV2] = []
    /// 未下载的模型
    @Published var undownloadedModels: [ModelV2] = []
    
    /// 如果是加载多模态模型，是否加载完成
    public var multiModelLoadingSuccess = false
    
    /// 当前生效的模型，预计会支持 V-2.6 8B 以及 V-4.0 4B 两个多模态模型
    var currentUsingModelType: CurrentUsingModelTypeV2 = .Unknown

    /// 性能日志的输出
    @Published var performanceLog = ""
    
    // 配置相关-end
    
    /// 初始化
    public init() {
        setupBindings()
    }
    
    /// 设置绑定
    private func setupBindings() {
        // 监听生成状态
        mtmdWrapper.$generationState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                    case .generating:
                        self?.isGenerating = true
                        self?.errorMessage = ""
                    case .completed, .cancelled:
                        self?.isGenerating = false
                        self?.performanceLog = "Done"
                    case .failed(let error):
                        self?.isGenerating = false
                        self?.errorMessage = error.localizedDescription
                    default:
                        self?.isGenerating = false
                }
            }
            .store(in: &cancellables)
        
        // 监听完整输出
        mtmdWrapper.$fullOutput
            .receive(on: DispatchQueue.main)
            .sink { [weak self] output in
                self?.outputText = output
            }
            .store(in: &cancellables)
    }
    
    /// 初始化模型
    /// - Parameters:
    ///   - modelPath: 模型路径（可选，默认使用文档目录中的模型）
    ///   - mmprojPath: 多模态投影模型路径（可选，默认使用文档目录中的模型）
    ///   - coremlPath: CoreML 模型路径（可选，用于 ANE 加速）
    public func initialize(modelPath: String? = nil, mmprojPath: String? = nil, coremlPath: String? = nil) async {
        do {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let defaultModelPath = documentsDir.appendingPathComponent("ggml-model-Q4_0.gguf").path
            let defaultMmprojPath = documentsDir.appendingPathComponent(MiniCPMModelConst.mmprojv4_FileName).path
            
            let finalModelPath = modelPath ?? defaultModelPath
            let finalMmprojPath = mmprojPath ?? defaultMmprojPath
            
            // 仅当当前加载的是 V4.0 mmproj 时，才自动使用文档目录下的 V4.0 CoreML。
            // 若对 V4.6 / 2.6 等误用此处回退，会把 V4.0 ANE 与 V4.6 merger 混用，视觉 embedding 完全错误。
            var finalCoremlPath = coremlPath ?? ""
            if finalCoremlPath.isEmpty {
                let mmprojName = URL(fileURLWithPath: finalMmprojPath).lastPathComponent
                if mmprojName == MiniCPMModelConst.mmprojv4_FileName {
                    let defaultCoremlDir = documentsDir.appendingPathComponent("coreml_minicpmv40_vit_f16.mlmodelc").path
                    if FileManager.default.fileExists(atPath: defaultCoremlDir) {
                        finalCoremlPath = defaultCoremlDir
                    }
                }
            }
            
            let params = MTMDParams.default(modelPath: finalModelPath, mmprojPath: finalMmprojPath, coremlPath: finalCoremlPath)
            self.params = params
            try await mtmdWrapper.initialize(with: params)
            print("初始化成功, CoreML: \(finalCoremlPath.isEmpty ? "未启用" : "已启用")")
            self.multiModelLoadingSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            print("初始化失败: \(error)")
            self.multiModelLoadingSuccess = false
        }
    }
    
    /// 在后台线程中添加图片
    /// - Parameter imagePath: 图片路径
    public func addImageInBackground(_ imagePath: String) async -> Bool {
        do {
            try await mtmdWrapper.addImageInBackground(imagePath)
            return true
        } catch {
            await MainActor.run {
                errorMessage = "图片添加失败: \(error.localizedDescription)"
            }
            return false
        }
    }

    public func addFrameInBackground(_ imagePath: String) async -> Bool {
        do {
            try await mtmdWrapper.addFrameInBackground(imagePath)
            return true
        } catch {
            await MainActor.run {
                errorMessage = "帧添加失败: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// 在后台线程中添加文本
    /// - Parameter text: 文本内容
    public func addTextInBackground(_ text: String, role: String = "user") async -> Bool {
        do {
            try await mtmdWrapper.addTextInBackground(text, role: role)
            print("文本添加成功（后台线程）: \(text)")
            return true
        } catch {
            await MainActor.run {
                errorMessage = "文本添加失败: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// 开始生成
    public func startGeneration() async {
        do {
            guard params != nil else {
                errorMessage = "请先初始化"
                return
            }
            
            // 添加调试信息
            print("开始生成 - 当前状态: \(mtmdWrapper.generationState)")
            try await mtmdWrapper.startGeneration()
        } catch {
            errorMessage = error.localizedDescription
            print("生成失败: \(error)")
            print("失败时的状态: \(mtmdWrapper.generationState)")
        }
    }
    
    /// 停止生成
    public func stopGeneration() {
        mtmdWrapper.stopGeneration()
        print("停止生成")
    }
    
    /// 重置
    public func reset() async {
        await mtmdWrapper.reset()
        multiModelLoadingSuccess = false
        outputText = ""
        errorMessage = ""
        print("已重置")
    }
}

// MARK: - 扩展 MTMDWrapper 以便在示例中访问

extension MTMDWrapper {
    /// 获取包装器实例（用于示例）
    public var wrapper: MTMDWrapper {
        return self
    }
}

//
//  MBHomeViewController+LoadModel.swift
//  MiniCPM-V-demo
//
//  Created by Alex on 2024/7/12.
//

import Foundation
import UIKit

extension MBHomeViewController {
    
    /// 尝试重新加载多模态模型
    func checkMultiModelLoadStatusAndLoadIt() {
    
        if self.mtmdWrapperExample?.multiModelLoadingSuccess == true {
            return
        }
        
        // 显示加载 HUD。
        // 第二行用最朴素的换行文案告诉用户"首次启动 ANE 较慢，请耐心等候"。
        // 之所以不走 attributedText / Timer 心跳那种花哨方案：在多次切换模型
        // 反复 reset + init 的场景里，跨 main actor 写 attributedText / 长生命
        // 周期 Timer 持有 hud 会跟 vc dealloc 路径竞争，触发
        // `Cannot form weak reference to MBHomeViewController` 崩溃 + 白屏。
        // 简单的多行 UILabel 文案在 vc 完全 attach 之后再被 alpha 动画显示出
        // 来，没有任何额外引用链，最稳。
        let hud = MBHUD.showAdded(to: self.view, animated: true)
        hud.mode = .indeterminate
        hud.label.text = "正在加载多模态模型...\n首次启动 ANE 较慢，请耐心等候"
        
        Task.detached(priority: .userInitiated) {

            var modelURL: URL?
            var mmprojURL: URL?
            var selectedModelType: CurrentUsingModelTypeV2 = .Unknown
            
            // 判断用户在设置页选中的模型
            let lastSelectedModelString = UserDefaults.standard.value(forKey: "current_selected_model") as? String ?? ""
            if lastSelectedModelString == "V26MultiModel" {
                // V-2.6 8B 多模态模型
                modelURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(MiniCPMModelConst.modelQ4_K_MFileName)
                mmprojURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(MiniCPMModelConst.mmprojFileName)
                selectedModelType = .V26MultiModel
            } else if lastSelectedModelString == "V4MultiModel" {
                // V-4.0 4B 多模态模型
                modelURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(MiniCPMModelConst.modelv4_Q4_K_M_FileName)
                mmprojURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(MiniCPMModelConst.mmprojv4_FileName)
                selectedModelType = .V4MultiModel
            } else if lastSelectedModelString == "V46MultiModel" {
                // V-4.6 多模态模型
                modelURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(MiniCPMModelConst.modelv46_FileName)
                mmprojURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(MiniCPMModelConst.mmprojv46_FileName)
                selectedModelType = .V46MultiModel
            }
            
            guard let modelURL = modelURL,
                  let mmprojURL = mmprojURL else {
                DispatchQueue.main.async {
                    hud.mode = .text
                    hud.label.text = "初始化失败，请先下载模型"
                    hud.hide(animated: true, afterDelay: 3)
                }
                return
            }

            DispatchQueue.main.async {
                self.currentUsingModelType = selectedModelType
                self.mtmdWrapperExample?.currentUsingModelType = selectedModelType
            }
            
            // 加载模型
            if await self.mtmdWrapperExample?.multiModelLoadingSuccess == false {
                if selectedModelType == .V26MultiModel {
                    // V2.6 不走 CoreML / ANE，没有冷启动文案。
                    await self.mtmdWrapperExample?.initialize(modelPath: modelURL.path, mmprojPath: mmprojURL.path)
                } else if selectedModelType == .V4MultiModel {

                    await self.mtmdWrapperExample?.initialize()

                    // warm-up：注入一张全白图触发 mmproj 首次 forward。
                    // 注意 V4.0 的 ANE 编译其实在 mtmd_init_from_file 内部的 warmup
                    // 一帧时就已经发生，下面这次 warmup 是为了让 KV cache 处于已暖
                    // 的状态，给用户第一张真实图片节省 ~1s 的首次 prefill 开销。
                    let whiteImage = UIImage(named: "white")
                    let whiteImageData = whiteImage?.pngData()
                    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                    let whiteImagePath = documentsPath.appending("/white.png")
                    try? whiteImageData?.write(to: URL(fileURLWithPath: whiteImagePath))
                    _ = await self.mtmdWrapperExample?.addImageInBackground(whiteImagePath)
                } else if selectedModelType == .V46MultiModel {
                    let coremlPath = MiniCPMV46CoreMLBootstrap.resolvedCoreMLPathInDocuments()
                    // V4.6 视频路径专属：64 帧 × slice=1 × 64 visual token = 4096，
                    // 4096 ctx 会被顶死并溢出 KV。8192 给 system prompt / 多轮
                    // 追问留足余量；v46 max_pos ≥ 32K，模型侧没问题。
                    // 老的 V2.6 / V4.0 保持 4096 默认以避免低内存设备压力。
                    await self.mtmdWrapperExample?.initialize(
                        modelPath: modelURL.path,
                        mmprojPath: mmprojURL.path,
                        coremlPath: coremlPath,
                        nCtx: 8192
                    )
                }

                // 更新模型加载状态为：加载成功，maybe 不需要，因为直接选择一张图提问时，也可能要重新 load model。
                await self.updateImageLoadedStatus(true)
            }
            
            // 检查模型加载状态
            DispatchQueue.main.async {
                if let mtmdWrapper = self.mtmdWrapperExample,
                   mtmdWrapper.multiModelLoadingSuccess == false {
                    // 模型加载失败，显示错误提示
                    hud.mode = .text
                    hud.label.text = "初始化失败，请先下载模型"
                    hud.hide(animated: true, afterDelay: 3)
                } else {
                    // 模型加载成功，隐藏 HUD
                    hud.mode = .text
                    hud.label.text = "初始化完成"
                    hud.hide(animated: true, afterDelay: 2)
                }
            }
        }
    }

}

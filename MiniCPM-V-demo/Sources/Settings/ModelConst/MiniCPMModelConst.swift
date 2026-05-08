//
//  MiniCPMModelConst.swift
//  MiniCPM-V-demo
//
//  Created by Alex on 2024/6/17.
//

import Foundation

/// 定义 MiniCPM 模型常量
struct MiniCPMModelConst {
    
    // MARK: - Q4_K_M 2.6 多模态主模型
    
    /// MiniCPM 多模态-主模型 Q4_K_M 文件名
    static let modelQ4_K_MFileName = "ggml-model-Q4_0.gguf"
    
    /// MiniCPM 多模态-主模型 Q4_K_M oss 下载地址
    static let modelQ4_K_MURLString = "https://huggingface.co/openbmb/MiniCPM-V-2_6-gguf/resolve/main/ggml-model-Q4_0.gguf"
    
    /// 显示在 UI 上名字-Q4_K_M
    static let modelQ4_K_MDisplayedName = "MiniCPM-V 2.6 8B LLM INT4"
    
    /// Q4_K_M gguf 文件 md5 值
    static let modelQ4_K_MMD5 = "2d6497c0ef0957af80a5d6b69e0de89b"
    
    
    // MARK: - 2.6 mmproj VIT 模型
    
    /// MiniCPM 多模态-mmproj 模型 文件名
    static let mmprojFileName = "mmproj-model-f16.gguf"
    
    /// MiniCPM 多模态-mmproj 模型 NAS 下载地址
    static let mmprojURLString = "https://huggingface.co/openbmb/MiniCPM-V-2_6-gguf/resolve/main/mmproj-model-f16.gguf"
    
    /// 显示在 UI 上名字-mmproj
    static let modelMMProjDisplayedName = "MiniCPM-V 2.6 8B VPM"
    
    /// mmproj gguf 文件 md5 值
    static let modelMMProjMD5 = "b539e887cc2b598f560465be65802b1b"
    
    
    // MARK: - 2.6 ANE 利用模块
    
    /// ANE 利用压缩包 文件名
    static let mlmodelcZipFileName = "ane_minicpmv26_f32.mlmodelc.zip"
    
    /// ANE 模型压缩包下载地址
    static let mlmodelcZipFileURLString = "https://huggingface.co/openbmb/MiniCPM-V-2_6-gguf/resolve/main/ane_minicpmv26_f32.mlmodelc.zip"
    
    /// ANE 利用显示在设置页的名称
    static let mlmodelcZipFileDisplayedName = "MiniCPM-V 2.6 8B ANE"
    
    /// ANE 利用压缩包 md5
    static let mlmodelcZipFileMD5 = "ddf77e6d274259dbcb35cd9e5ca26d1a"
    
    
    
    // MARK: - mbv4 多模态语言模型
    
    /// MiniCPM 多模态-主模型 Q4_K_M 文件名
    static let modelv4_Q4_K_M_FileName = "ggml-model-Q4_0.gguf"
    
    /// MiniCPM 多模态-主模型 Q4_K_M oss 下载地址
    static let modelv4_Q4_K_M_URLString = "https://huggingface.co/openbmb/MiniCPM-V-4-gguf/resolve/main/ggml-model-Q4_0.gguf"

    static let modelv4_Q4_K_M_BackUpURLString = "https://modelscope.cn/api/v1/models/OpenBMB/MiniCPM-V-4-gguf/repo?Revision=master&FilePath=ggml-model-Q4_0.gguf"
    
    /// 显示在 UI 上名字-Q4_K_M
    static let modelv4_Q4_K_M_DisplayedName = "MiniCPM-V 4.0 4B LLM INT4"
    
    /// Q4_K_M gguf 文件 md5 值
    static let modelv4_Q4_K_M_MD5 = "8fc4cc88e5ea73472ae795b57a0e7fdd"
    
    
    // MARK: - mbv4 mmproj VIT 模型
    
    /// MiniCPM 多模态-mmproj 模型 文件名
    static let mmprojv4_FileName = "mmproj-model-f16-iOS.gguf"
    
    /// MiniCPM 多模态-mmproj 模型 NAS 下载地址
    static let mmprojv4_URLString = "https://huggingface.co/openbmb/MiniCPM-V-4-gguf/resolve/main/mmproj-model-f16.gguf"

    static let mmprojv4_BackUpURLString = "https://modelscope.cn/api/v1/models/OpenBMB/MiniCPM-V-4-gguf/repo?Revision=master&FilePath=mmproj-model-f16.gguf"
    
    /// 显示在 UI 上名字-mmproj
    static let modelMMProjv4_DisplayedName = "MiniCPM-V 4.0 4B VPM"
    
    /// mmproj gguf 文件 md5 值
    static let modelMMProjv4_MD5 = "fe15375bb4c579858df6054d2a8b639d"
    
    // MARK: - mbv4 ANE 利用模块
    
    /// ANE 利用压缩包 文件名
    static let mlmodelcv4_ZipFileName = "coreml_minicpmv40_vit_f16.mlmodelc.zip"
    
    /// ANE 模型压缩包下载地址
    static let mlmodelcv4_ZipFileURLString = "https://huggingface.co/openbmb/MiniCPM-V-4-gguf/resolve/main/coreml_minicpmv40_vit_f16.mlmodelc.zip"
    
    static let mlmodelcv4_ZipFileBackUpURLString = "https://modelscope.cn/api/v1/models/OpenBMB/MiniCPM-V-4-gguf/repo?Revision=master&FilePath=coreml_minicpmv40_vit_f16.mlmodelc.zip"
    
    /// ANE 利用显示在设置页的名称
    static let mlmodelcv4_ZipFileDisplayedName = "MiniCPM-V 4.0 4B ANE"
    
    /// ANE 利用压缩包 md5
    static let mlmodelcv4_ZipFileMD5 = "150a316e49dee3da04d72039ee2ca390"
    
    
    // MARK: - MiniCPM-V 4.6 多模态语言模型

    /// V4.6 主模型文件名（落盘到 Documents/，命名带 v4.6 前缀以避免与 v2.6 / v4.0 同目录平铺时撞名）
    static let modelv46_FileName = "MiniCPM-V-4_6-Q4_K_M.gguf"

    /// V4.6 显示名
    static let modelv46_DisplayedName = "MiniCPM-V 4.6 LLM INT4"

    /// V4.6 主模型下载地址（华为云中转 OSS）
    static let modelv46_Q4_K_M_URLString = "https://data-transfer-huawei.obs.cn-north-4.myhuaweicloud.com/minicpmv46-instruct/MiniCPM-V-4_6-Q4_K_M.gguf"

    /// V4.6 主模型 md5
    static let modelv46_Q4_K_M_MD5 = "fd778481dd56b6036dd8f9cf7c1519cf"


    // MARK: - MiniCPM-V 4.6 mmproj VIT 模型

    /// V4.6 mmproj 文件名（落盘到 Documents/，命名带 v4.6 前缀以避免与 v2.6 同名 mmproj-model-f16.gguf 撞名）
    static let mmprojv46_FileName = "MiniCPM-V-4_6-mmproj-f16.gguf"

    /// V4.6 mmproj 显示名
    static let modelMMProjv46_DisplayedName = "MiniCPM-V 4.6 VPM"

    /// V4.6 mmproj 下载地址（华为云中转 OSS，objectKey 与上游 HF 一致）
    static let mmprojv46_URLString = "https://data-transfer-huawei.obs.cn-north-4.myhuaweicloud.com/minicpmv46-instruct/mmproj-model-f16.gguf"

    /// V4.6 mmproj md5（demo 分支转出版本：clip.projector_type=merger，与封板 HF 权重一致）
    static let modelMMProjv46_MD5 = "aad0d36e43a35412d72ed27a1248c7ef"
    
    
    // MARK: - MiniCPM-V 4.6 ANE 模块
    
    /// V4.6 ANE CoreML 目录名（编译后的 .mlmodelc，或 Xcode 可直接加载的 .mlpackage 包）
    static let mlmodelcv46_DirName = "coreml_minicpmv46_vit_all_f32.mlmodelc"
    
    /// 在 Documents 中依次尝试的文件名（任一路径存在即作为 CoreML 路径）
    static let mlmodelcv46_CandidateFileNames: [String] = [
        "coreml_minicpmv46_vit_all_f32.mlmodelc",
        "coreml_minicpmv46_vit_all_f32.mlpackage",
        "coreml_minicpmv46_vit_all_f16.mlpackage",
    ]
    
    /// V4.6 ANE 显示名
    static let mlmodelcv46_DisplayedName = "MiniCPM-V 4.6 ANE"

    /// V4.6 ANE zip 文件名（下载到 Documents 后解压得到 .mlmodelc 目录）
    static let mlmodelcv46_ZipFileName = "coreml_minicpmv46_vit_all_f32.mlmodelc.zip"

    /// V4.6 ANE zip 下载地址
    static let mlmodelcv46_ZipFileURLString = "https://data-transfer-huawei.obs.cn-north-4.myhuaweicloud.com/minicpmv46-instruct/coreml_minicpmv46_vit_all_f32.mlmodelc.zip"

    /// V4.6 ANE zip md5（demo 分支重转：基于 ckpt/MiniCPM-V-4_6 封板权重 + HF 命名映射）
    static let mlmodelcv46_ZipFileMD5 = "4ea0fbdb9b975e411b0faf478beb1d84"
    
}

//
//  MiniCPMV46CoreMLBootstrap.swift
//  MiniCPM-V-demo
//
//  将工程内 BundledV46ANE 目录下的 CoreML（.mlpackage / .mlmodelc）首次复制到 Documents，
//  与 MiniCPMModelConst.mlmodelcv46_CandidateFileNames 命名一致，便于运行时加载。
//

import Foundation

enum MiniCPMV46CoreMLBootstrap {

    /// App 包内放置 ANE 的子目录（把模型拖进 Xcode 时选「Create folder references」使该目录进 Bundle）
    private static let bundleSubdirectory = "BundledV46ANE"

    /// 启动时调用：若 Documents 尚无任一候选文件，且 Bundle 内存在，则复制到 Documents。
    static func installBundledModelIntoDocumentsIfNeeded() {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        if firstExistingCandidate(in: docs, fm: fm) != nil {
            return
        }

        guard let bundledURL = bundleDirectoryURL() else {
            return
        }

        for name in MiniCPMModelConst.mlmodelcv46_CandidateFileNames {
            let src = bundledURL.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = docs.appendingPathComponent(name)
            do {
                if fm.fileExists(atPath: dst.path) {
                    try fm.removeItem(at: dst)
                }
                try fm.copyItem(at: src, to: dst)
                #if DEBUG
                print("[V4.6 ANE] 已从 Bundle 复制到 Documents: \(name)")
                #endif
                return
            } catch {
                print("[V4.6 ANE] 复制失败: \(error.localizedDescription)")
            }
        }
    }

    /// 解析当前应使用的 CoreML 路径（Documents 中第一个存在的候选）。
    static func resolvedCoreMLPathInDocuments() -> String? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return firstExistingCandidate(in: docs, fm: fm)
    }

    private static func firstExistingCandidate(in documents: URL, fm: FileManager) -> String? {
        for name in MiniCPMModelConst.mlmodelcv46_CandidateFileNames {
            let p = documents.appendingPathComponent(name).path
            if fm.fileExists(atPath: p) {
                return p
            }
        }
        return nil
    }

    /// `.../App.app/BundledV46ANE`（需将目录加入 Target → Copy Bundle Resources）
    private static func bundleDirectoryURL() -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent(bundleSubdirectory, isDirectory: true)
    }
}

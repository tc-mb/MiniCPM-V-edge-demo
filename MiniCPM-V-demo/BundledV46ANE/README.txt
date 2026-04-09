V4.6 ANE（CoreML）放置说明
========================

将导出得到的下列任一名称放到本目录，并在 Xcode 中：

1. 把「BundledV46ANE」文件夹拖入工程左侧（建议选 Create folder references，蓝色文件夹）。
2. 在 Target → Build Phases → Copy Bundle Resources 中确认包含该文件夹。

文件名须与 MiniCPMModelConst.mlmodelcv46_CandidateFileNames 中一致，例如：
  - coreml_minicpmv46_vit_all_f32.mlpackage
  - coreml_minicpmv46_vit_all_f32.mlmodelc

应用首次启动会把包内模型复制到 App Documents，运行时从 Documents 加载。

若不放 Bundle，也可直接把同名文件拷入设备「文件」App 所见的应用 Documents 目录。

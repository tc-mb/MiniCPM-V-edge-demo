# MiniCPM-V iOS Demo · UI 自动化测试

> 让你以后再也不用手点 5 个按钮验证「这版没把首页打挂吧」。
> 一条命令，模拟器或真机跑一遍，截图全留好。

## 这是啥

新增的 `MiniCPM-V-demoUITests` 是一个 **XCUITest UI 测试 target**，附属在主工程
`MiniCPM-V-demo.xcodeproj` 上。它会启动 app、依次模拟点击、把每一步截屏存到 xcresult
里，最后用 `xcrun xcresulttool` 把截图导出成 PNG，再生成一份 `REPORT_*.md`。

## 一条命令跑完

```bash
# 模拟器（推荐回归用，跑完 < 1 分钟，不依赖物理设备）
bash scripts/run_uitest.sh sim

# 真机（推荐发版前用，跑完 < 2 分钟，会触发模型推理）
# 注意：真机要解锁屏幕，否则 Xcode 拒绝启动测试
bash scripts/run_uitest.sh device
```

跑完会输出：

```
[run_uitest] DONE.
  report:   build/REPORT_sim.md          ← 测试报告（含截图列表）
  shots:    build/screenshots_sim/       ← 全部 PNG 截图（命名按步骤排序）
  exit:     0
```

## 都覆盖了哪些功能

按现在的 `test01_endToEndFlow` 顺序：

| 步骤 | 截图 prefix | 操作 | 校验目标 |
|------|-------------|------|----------|
| 0 | `00_app_launched_*` | 启动 | App 进程能起来 |
| 1 | `01_first_screen` | 等首屏 | NavBar / 输入框出现 |
| 1b | `01b_after_system_alerts_handled` | 关掉系统权限 alert | (无的话跳过) |
| 2 | `02_tutorial_page` | 点顶导问号 | 教程页能打开 |
| 3 | `03_back_from_tutorial` | 返回 | 教程页能返回 |
| 4 | `04_image_slice_alert` | 点切图 slider | 切图弹窗能弹出 |
| 5 | `05_after_dismiss_slice_alert` | 点取消 | 切图弹窗能关 |
| 6 | `06_settings_page` | 点齿轮 | 设置页能打开 |
| 7 | `07_settings_page_scrolled` | 上滑 | 设置页可滚动 |
| 8 | `08_back_from_settings` | 返回 | 设置页能返回 |
| 9 | `09_after_delete_tapped_dialog` | 点垃圾桶 | 「是否清除」确认弹窗能弹 |
| 10 | `10_after_confirm_clear` | 点删除 | 对话能清空 |
| 11 | `11_after_choose_image_tapped` | 点图片 picker | HXPhotoPicker 能拉起 |
| 12 | `12_after_handle_system_alert` | 关掉权限 alert | 系统权限 alert 能关 |
| 13 | `13_after_dismiss_picker` | 关掉 picker | picker 能 dismiss |
| 20 | `20_textview_focused` (sim) / `20_after_send_text` (真机) | 点输入框 / 发文本 | 模拟器：仅聚焦；真机：发文本 |
| 21 | `21_welcome_section_visible` (sim) / `21_after_llm_reply_done` (真机) | 等回复 | 真机模型能输出 |
| 30 | `30_final_state` | 收尾 | / |

> **真机 vs 模拟器**：
> - 模拟器没下模型 + 没 ANE，所以推理跑不起来；测试用 `targetEnvironment(simulator)`
>   分支跳过发送文本部分，仅验证 UI 按钮 / 弹窗 / 导航。
> - 真机如果模型已就绪（`Documents/MiniCPM-V-4_6-*.gguf` + `coreml_*` 都在），
>   会发一段「你好，请用一句话介绍一下你自己」，然后等 90s 收 LLM 输出。

## 失败了怎么排查

1. 先看 `build/REPORT_<mode>.md` 里有没有截图（如果没有，说明 build 阶段就挂了，
   去看 `build/uitest_<sim|>/build.log`）。
2. 看 `build/uitest_<sim|>/run.log`：里面有所有 XCUITest 的 step 以及 a11y 树。
3. 用 Xcode 打开 `build/uitest_*_result.xcresult`，能可视化看每一步。

## 常见坑

- **真机锁屏**：Xcode 必须解锁手机才能启动 UI 测试；锁屏时会卡在
  `Run Destination Preflight: The destination is not ready` + `Unlock <DeviceName>
  to Continue`。处理：解锁手机后重跑。
- **模拟器硬件键盘**：模拟器默认 `Connect Hardware Keyboard` 是开的，软键盘不弹，
  导致 `typeText` 报 `Neither element nor any descendant has keyboard focus`。
  当前测试在模拟器分支已经跳过 `typeText`，所以不影响。如果你以后要在模拟器上测
  「真的输入文字」，需要：菜单 IO → Keyboard → Connect Hardware Keyboard 关掉。
- **a11y label 不直观**：iOS 把 image asset 名 `delete_icon` 转成 `'delete icon'`
  作为 a11y label；SF Symbol `slider.horizontal.3` 系统给的 a11y label 是
  `'edit'`。当前 helper `findNavButton` 已经把这些都列进候选，未来加按钮要同步
  补上。

## 目录速览

```
MiniCPM-V-demoUITests/
├── MiniCPMVDemoUITests.swift   全部测试逻辑（单文件）
├── Info.plist
└── README.md                   本文档

scripts/
├── add_uitest_target.rb        把 UI Test target 加到 .xcodeproj 的脚本（一次性）
└── run_uitest.sh               一键跑测试 + 导截图 + 出报告

build/
├── uitest_sim_result.xcresult  模拟器结果 bundle（可用 Xcode 打开）
├── screenshots_sim/            模拟器跑完导出来的 PNG
├── REPORT_sim.md               模拟器测试报告
├── uitest_result.xcresult      真机结果 bundle
├── screenshots_device/         真机截图
└── REPORT_device.md            真机报告
```

## 重新搭一遍（没装 xcodeproj gem 的环境）

```bash
gem install --user-install xcodeproj            # 一次性
ruby scripts/add_uitest_target.rb                # 重新加 UI Test target（已有则跳过）
bash scripts/run_uitest.sh sim                   # 跑模拟器
```

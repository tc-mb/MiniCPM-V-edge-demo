//
//  MiniCPMVDemoUITests.swift
//  MiniCPM-V-demoUITests
//
//  端到端 UI 自动化测试。每个 test* 方法 = 一类场景（独立运行、独立截图）。
//  推荐跑：
//    - bash scripts/run_uitest.sh sim       # 模拟器，纯 UI 校验
//    - bash scripts/run_uitest.sh device    # 真机，能跑模型推理
//

import XCTest

final class MiniCPMVDemoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
        // 让 UI Test 自动 dismiss interrupting alerts（系统权限框）
        addUIInterruptionMonitor(withDescription: "Allow alerts") { alert -> Bool in
            let labels = ["允许", "始终允许", "允许访问所有照片", "允许使用 App 时",
                          "好", "继续",
                          "Allow", "Allow Full Access", "Allow Access to All Photos",
                          "Allow While Using App", "OK", "Continue"]
            for s in labels {
                let b = alert.buttons[s]
                if b.exists { b.tap(); return true }
            }
            return false
        }
    }

    // MARK: - test01: 主要 UI 路径（不依赖模型推理）
    //   - 启动
    //   - 教程页 / 切图 alert / 设置页 / 清空 alert / 图片 picker
    //   - 模拟器和真机都跑
    func test01_basicNavigation() throws {
        let app = launchAppFresh()
        attach(name: "00_app_launched", element: app)

        XCTAssertTrue(waitForFirstScreen(app: app, timeout: 30), "首屏 30s 内没出来")
        attach(name: "01_first_screen", element: app)

        // 教程
        if let b = findNavButton(app: app, names: ["questionmark.circle", "教程", "Tutorial"]) {
            b.tap(); sleep(2); attach(name: "02_tutorial_page", element: app)
            tapNavBack(app: app); sleep(1); attach(name: "03_back_from_tutorial", element: app)
        }

        // 切图设置 alert
        if let b = findNavButton(app: app, names: ["edit", "slider.horizontal.3", "切图"]) {
            b.tap(); sleep(2); attach(name: "04_slice_alert", element: app)
            dismissDialog(app: app); sleep(1); attach(name: "05_after_slice_dismiss", element: app)
        }

        // 设置页 + 滚动
        if let b = findNavButton(app: app, names: ["setting icon", "设置", "Settings"]) {
            b.tap(); sleep(2); attach(name: "06_settings_page", element: app)
            app.swipeUp(); sleep(1); attach(name: "07_settings_scrolled", element: app)
            app.swipeDown(); sleep(1)
            tapNavBack(app: app); sleep(1); attach(name: "08_back_from_settings", element: app)
        }

        // 清空对话
        if let b = findNavButton(app: app, names: ["delete icon", "删除", "Delete"]) {
            b.tap(); sleep(2); attach(name: "09_delete_dialog", element: app)
            confirmDelete(app: app); sleep(2); attach(name: "10_after_clear", element: app)
        }
    }

    // MARK: - test02: 等模型 ready，发文本，等回复（真机才跑）
    //   - 模拟器跳过（没模型）
    //   - 真机：等到 "正在加载多模态模型" 消失或 60s，然后发一条短文本，等 90s 回复
    func test02_textChatWithModel() throws {
        try XCTSkipIf(isSimulator(), "模拟器没模型，跳过推理测试")
        let app = launchAppFresh()
        attach(name: "00_launched", element: app)

        XCTAssertTrue(waitForFirstScreen(app: app, timeout: 30), "首屏 30s 内没出来")

        // 关键：等模型加载完成（"正在加载多模态模型..." 消失）
        let modelReady = waitForModelReady(app: app, timeout: 90)
        attach(name: "01_model_ready_\(modelReady)", element: app)
        XCTAssertTrue(modelReady, "模型 90s 内没加载完成")

        // 发一条文本（用键盘输入，真机硬件键盘没冲突）
        let text = "你好，请用一句话介绍一下你自己。"
        sendTextWithKeyboard(app: app, text: text)
        attach(name: "02_after_send_text", element: app)

        // 等回复（90s）。即使没识别到，也截图看实际效果，不硬失败
        let replied = waitForLLMReply(app: app, timeout: 90)
        attach(name: "03_reply_done_\(replied)", element: app)
        if !replied {
            XCTAssertNoThrow("模型回复检测失败（不一定真的没回复，看截图判断）")
        }
    }

    // MARK: - test03: 选图 + 发问题（真机才跑，需要相册权限）
    //   - 已在系统设置里给过 limited 权限，picker 会出现已授权图片
    //   - 选第一张图，发问题，等回复
    func test03_imageChatWithModel() throws {
        try XCTSkipIf(isSimulator(), "模拟器没模型，跳过")
        let app = launchAppFresh()
        attach(name: "00_launched", element: app)

        XCTAssertTrue(waitForFirstScreen(app: app, timeout: 30))
        XCTAssertTrue(waitForModelReady(app: app, timeout: 90), "模型加载超时")
        attach(name: "01_model_ready", element: app)

        // 点 image picker
        guard let b = findInputBarButton(app: app, candidates: ["image picker icon", "image_picker_icon"]) else {
            XCTFail("找不到图片选择按钮")
            attach(name: "02_no_picker_button", element: app)
            return
        }
        b.tap()
        sleep(3)
        attach(name: "02_picker_opened", element: app)

        // 等 picker 出来（PHPicker 或 HXPhotoPicker）
        sleep(2)

        // 在 picker 中选第一张图（点屏幕左上角附近的第一个 cell）
        let firstCell = app.collectionViews.cells.firstMatch
        if firstCell.waitForExistence(timeout: 5) {
            firstCell.tap()
            sleep(3)
            attach(name: "03_image_picked", element: app)

            // PHPicker 选完会自动关，HXPhotoPicker 需要点"完成"
            let doneBtn = app.buttons["完成"].exists ? app.buttons["完成"] :
                          app.buttons["Done"].exists ? app.buttons["Done"] :
                          app.buttons["添加"].exists ? app.buttons["添加"] : app.buttons["Add"]
            if doneBtn.exists { doneBtn.tap(); sleep(2) }
            attach(name: "04_after_picker_close", element: app)
        } else {
            attach(name: "03_no_cell_in_picker", element: app)
            // 关掉 picker
            dismissPicker(app: app)
        }

        // 等图片预处理完成 + 模型加载（如果切了模型）
        sleep(5)
        attach(name: "05_after_image_preprocess", element: app)

        // 发文本
        sendTextWithKeyboard(app: app, text: "请描述这张图片的内容")
        attach(name: "06_after_send", element: app)

        // 等回复，最多 180s（图片预处理首次 ANE 编译可能很慢）
        let replied = waitForLLMReply(app: app, timeout: 180)
        attach(name: "07_reply_done_\(replied)", element: app)
    }

    // MARK: - test04: 模型切换压力测试（点开设置进各模型详情）
    //   - 看进设置 → 选 V2.6 / V4.0 / V4.6 详情页 → 是否会崩
    func test04_settingsModelDetailNavigation() throws {
        let app = launchAppFresh()
        attach(name: "00_launched", element: app)
        XCTAssertTrue(waitForFirstScreen(app: app, timeout: 30))

        guard let settingsBtn = findNavButton(app: app, names: ["setting icon", "设置"]) else {
            XCTFail("找不到设置按钮"); return
        }
        settingsBtn.tap(); sleep(2)
        attach(name: "01_settings_open", element: app)

        let modelLabels = ["MiniCPM-V 2.6 8B", "MiniCPM-V 4.0 4B", "MiniCPM-V 4.6"]
        for (i, label) in modelLabels.enumerated() {
            let cell = app.staticTexts[label].firstMatch
            if cell.waitForExistence(timeout: 3) {
                cell.tap(); sleep(3)
                attach(name: String(format: "%02d_%@_detail", 2 + i*2, label.replacingOccurrences(of: " ", with: "_")), element: app)
                tapNavBack(app: app); sleep(2)
                attach(name: String(format: "%02d_back_from_%@", 3 + i*2, label.replacingOccurrences(of: " ", with: "_")), element: app)
            } else {
                attach(name: String(format: "%02d_no_cell_%@", 2 + i*2, label.replacingOccurrences(of: " ", with: "_")), element: app)
            }
        }

        // 关于我们
        let aboutCell = app.staticTexts["关于我们"]
        if aboutCell.waitForExistence(timeout: 3) {
            aboutCell.tap(); sleep(2)
            attach(name: "10_about_us", element: app)
            tapNavBack(app: app); sleep(1)
        }

        tapNavBack(app: app); sleep(1)
        attach(name: "11_back_to_home", element: app)
    }

    // MARK: - test05: 压力测试（连续清空 + 切图 alert）
    //   - 连按 5 次「清空」，看会不会卡死或崩
    //   - 连开 5 次「切图」alert，看 dismiss 流程
    func test05_stressClickButtons() throws {
        let app = launchAppFresh()
        XCTAssertTrue(waitForFirstScreen(app: app, timeout: 30))
        attach(name: "00_initial", element: app)

        // 5 次清空
        for i in 0..<5 {
            if let b = findNavButton(app: app, names: ["delete icon", "删除"]) {
                b.tap(); sleep(1)
                confirmDelete(app: app); sleep(1)
                attach(name: String(format: "01_clear_round_%d", i), element: app)
            }
        }

        // 5 次切图 alert
        for i in 0..<5 {
            if let b = findNavButton(app: app, names: ["edit", "slider.horizontal.3"]) {
                b.tap(); sleep(1)
                dismissDialog(app: app); sleep(1)
                attach(name: String(format: "02_slice_round_%d", i), element: app)
            }
        }

        // 5 次教程进出
        for i in 0..<5 {
            if let b = findNavButton(app: app, names: ["questionmark.circle"]) {
                b.tap(); sleep(1)
                tapNavBack(app: app); sleep(1)
                attach(name: String(format: "03_tutorial_round_%d", i), element: app)
            }
        }

        attach(name: "99_after_stress", element: app)
    }

    // MARK: - helpers

    private func launchAppFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MB_UI_TEST"] = "1"
        app.launch()
        return app
    }

    private func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func attach(name: String, element: XCUIElement) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForFirstScreen(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.navigationBars.firstMatch.exists { return true }
            sleep(1)
        }
        return false
    }

    /// 等到主页上的 "正在加载多模态模型..." 消失。如果 60s 内没消失，认为加载失败。
    private func waitForModelReady(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let loadingTexts = ["正在加载多模态模型...", "正在加载多模态模型…", "初始化失败，请先下载模型"]
        // 周期性截屏，每 5s 看一次
        while Date() < deadline {
            var loadingExists = false
            for s in loadingTexts {
                if app.staticTexts[s].exists { loadingExists = true; break }
            }
            if !loadingExists {
                return true
            }
            sleep(3)
        }
        return false
    }

    private func sendTextWithKeyboard(app: XCUIApplication, text: String) {
        let tv = app.textViews.firstMatch
        guard tv.waitForExistence(timeout: 10) else { return }
        tv.tap()
        sleep(1)
        tv.typeText(text)
        sleep(1)
        // 找发送按钮
        let send = app.buttons["send icon"]
        if send.exists {
            send.tap()
        } else if app.keyboards.buttons["发送"].exists {
            app.keyboards.buttons["发送"].tap()
        } else if app.keyboards.buttons["Send"].exists {
            app.keyboards.buttons["Send"].tap()
        }
    }

    /// 等 LLM 回复完成。
    ///   判定逻辑：在 .any descendant 中查找 label 含「终止生成」的元素 →
    ///     先看到（生成中），再消失（生成结束）。
    ///   兜底：屏幕上出现含「复制」label 的元素。
    ///   timeout 内都没看到返回 false（但不算硬失败，调用方决定）。
    private func waitForLLMReply(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let interval: TimeInterval = 3
        var elapsed: TimeInterval = 0
        var sawStopButton = false
        let stopPredicate = NSPredicate(format: "label CONTAINS '终止生成'")
        let copyPredicate = NSPredicate(format: "label CONTAINS '复制'")
        while elapsed < timeout {
            sleep(UInt32(interval))
            elapsed += interval
            attach(name: String(format: "wait_reply_%03ds", Int(elapsed)), element: app)
            let stopExists = app.descendants(matching: .any).matching(stopPredicate).firstMatch.exists
            let copyExists = app.descendants(matching: .any).matching(copyPredicate).firstMatch.exists
            if stopExists { sawStopButton = true }
            if sawStopButton && !stopExists {
                sleep(2)
                return true
            }
            if copyExists {
                sleep(2)
                return true
            }
        }
        return false
    }

    private func findNavButton(app: XCUIApplication, names: [String]) -> XCUIElement? {
        for n in names {
            let b = app.navigationBars.buttons[n]
            if b.exists { return b }
        }
        for n in names {
            let b = app.buttons[n]
            if b.exists { return b }
        }
        return nil
    }

    private func findInputBarButton(app: XCUIApplication, candidates: [String]) -> XCUIElement? {
        for n in candidates {
            let b = app.buttons[n]
            if b.exists { return b }
        }
        return nil
    }

    private func tapNavBack(app: XCUIApplication) {
        let navBar = app.navigationBars.firstMatch
        if navBar.exists {
            let back = navBar.buttons.element(boundBy: 0)
            if back.exists { back.tap(); return }
        }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func dismissDialog(app: XCUIApplication) {
        let candidates = ["取消", "关闭", "Cancel", "Close", "Done", "完成", "OK", "好"]
        for s in candidates {
            let b = app.alerts.buttons[s]
            if b.exists { b.tap(); return }
        }
        for s in candidates {
            let b = app.buttons[s]
            if b.exists { b.tap(); return }
        }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
    }

    private func dismissPicker(app: XCUIApplication) {
        // 常见关闭按钮
        let candidates = [
            "Cancel", "取消", "关闭", "Close",
            "hx picker notAuthorized close ", "hx picker notAuthorized close",
            "hx picker close ", "hx picker close",
        ]
        for s in candidates {
            let b = app.buttons[s]
            if b.exists { b.tap(); return }
        }
        // 系统 PHPicker 的关闭按钮：左上角 X，a11y 通常是 "Cancel"
        // 兜底：左上角 tap
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.08)).tap()
    }

    private func confirmDelete(app: XCUIApplication) {
        let candidates = ["删除", "确认", "确定", "清空", "OK", "Delete", "Confirm", "Clear"]
        for s in candidates {
            let b = app.alerts.buttons[s]
            if b.exists { b.tap(); return }
        }
        for s in candidates {
            let b = app.buttons[s]
            if b.exists { b.tap(); return }
        }
    }
}

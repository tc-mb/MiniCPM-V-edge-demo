//
//  MBV46ModelDetailViewController.swift
//  MiniCPM-V-demo
//

import Foundation
import UIKit
import SnapKit
import llama

/// V4.6 模型详情页面 VC（本地文件模式）
@objc public class MBV46ModelDetailViewController: UIViewController, UIGestureRecognizerDelegate {
    
    var modelName: String = "MiniCPM-V 4.6"
    
    private var mtmdWrapperExample: MTMDWrapperExample?
    
    lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .grouped)
        tv.register(MBSettingsTableViewCell.self, forCellReuseIdentifier: "MBSettingsTableViewCell")
        tv.estimatedRowHeight = 48
        tv.separatorStyle = .none
        tv.separatorColor = .clear
        tv.dataSource = self
        tv.delegate = self
        return tv
    }()
    
    var dataArray = [MBSettingsModel]()
    
    lazy var useModelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("使用该模型", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.mb_color(with: "#007AFF")
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.addTarget(self, action: #selector(useModelButtonTapped), for: .touchUpInside)
        return button
    }()
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    init(with wrapper: MTMDWrapperExample) {
        self.mtmdWrapperExample = wrapper
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupSubViews()
        loadTableViewData()
        updateUseModelButtonState()
        UIApplication.shared.isIdleTimerDisabled = true
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.navigationController?.viewControllers.count ?? 0 > 1
    }
    
    func setupSubViews() {
        self.title = modelName
        
        let titleDict: [NSAttributedString.Key : Any] = [NSAttributedString.Key.foregroundColor: UIColor.black]
        self.navigationController?.navigationBar.titleTextAttributes = titleDict
        self.view.backgroundColor = UIColor.mb_color(with: "#F9FAFC")
        
        let img = UIImage(systemName: "chevron.left")
        let leftNavIcon = UIBarButtonItem(image: img, style: .plain, target: self, action: #selector(handleLeftNavIcon))
        leftNavIcon.tintColor = .black
        self.navigationItem.leftBarButtonItem = leftNavIcon
        self.navigationController?.setNavigationBackgroundColor(UIColor.mb_color(with: "#F9FAFC") ?? .white)
        
        tableView.sectionHeaderTopPadding = 0
        tableView.backgroundColor = UIColor.mb_color(with: "#F6F6F6")
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        
        view.addSubview(tableView)
        view.addSubview(useModelButton)
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.left.right.equalTo(self.view)
            make.bottom.equalTo(useModelButton.snp.top).offset(-20)
        }
        
        useModelButton.snp.makeConstraints { make in
            make.left.equalTo(self.view).offset(20)
            make.right.equalTo(self.view).offset(-20)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.height.equalTo(50)
        }
    }
    
    @objc public func handleLeftNavIcon() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc public func useModelButtonTapped() {
        guard checkAllFilesExist() else {
            let alert = UIAlertController(title: "提示", message: "请先将模型文件放入 Documents 目录", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        setAsCurrentModel()
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        self.tableView.reloadData()
    }
    
    // MARK: - 文件检查
    
    private func fileExists(_ fileName: String) -> Bool {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return FileManager.default.fileExists(atPath: documentsDir.appendingPathComponent(fileName).path)
    }
    
    private func checkAllFilesExist() -> Bool {
        let llmExists = fileExists(MiniCPMModelConst.modelv46_FileName)
        let vitExists = fileExists(MiniCPMModelConst.mmprojv46_FileName)
        return llmExists && vitExists
    }
    
    private func updateUseModelButtonState() {
        if checkAllFilesExist() {
            useModelButton.isEnabled = true
            useModelButton.backgroundColor = UIColor.mb_color(with: "#007AFF")
            useModelButton.setTitleColor(.white, for: .normal)
        } else {
            useModelButton.isEnabled = false
            useModelButton.backgroundColor = UIColor.mb_color(with: "#CCCCCC")
            useModelButton.setTitleColor(.gray, for: .normal)
        }
    }
    
    private func setAsCurrentModel() {
        mtmdWrapperExample?.currentUsingModelType = .V46MultiModel
        UserDefaults.standard.setValue("V46MultiModel", forKey: "current_selected_model")
        
        let hud = MBHUD.showAdded(to: self.view, animated: true)
        hud.mode = .text
        hud.label.text = "已设置 \(modelName) 为当前模型"
        hud.hide(animated: true, afterDelay: 2.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.navigationController?.popViewController(animated: true)
        }
    }
}

// MARK: - UITableViewDataSource
extension MBV46ModelDetailViewController: UITableViewDataSource {
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray.count
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 48
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MBSettingsTableViewCell", for: indexPath) as! MBSettingsTableViewCell
        let model = dataArray[indexPath.row]
        cell.configure(with: model)
        return cell
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }
}

// MARK: - UITableViewDelegate
extension MBV46ModelDetailViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - 数据配置
extension MBV46ModelDetailViewController {
    
    public func loadTableViewData() {
        dataArray.removeAll()
        
        let languageModel = MBSettingsModel()
        languageModel.title = MiniCPMModelConst.modelv46_DisplayedName
        languageModel.icon = UIImage(systemName: "cpu")
        languageModel.statusString = fileExists(MiniCPMModelConst.modelv46_FileName) ? "已就绪" : "未找到"
        languageModel.shouldShowStatusText = true
        dataArray.append(languageModel)
        
        let multimodalModel = MBSettingsModel()
        multimodalModel.title = MiniCPMModelConst.modelMMProjv46_DisplayedName
        multimodalModel.icon = UIImage(systemName: "cpu")
        multimodalModel.statusString = fileExists(MiniCPMModelConst.mmprojv46_FileName) ? "已就绪" : "未找到"
        multimodalModel.shouldShowStatusText = true
        dataArray.append(multimodalModel)
        
        let aneModel = MBSettingsModel()
        aneModel.title = MiniCPMModelConst.mlmodelcv46_DisplayedName
        aneModel.icon = UIImage(systemName: "cpu")
        let aneReady = MiniCPMModelConst.mlmodelcv46_CandidateFileNames.contains { fileExists($0) }
        aneModel.statusString = aneReady ? "已就绪" : "未找到（可选）"
        aneModel.shouldShowStatusText = true
        dataArray.append(aneModel)
        
        tableView.reloadData()
    }
}

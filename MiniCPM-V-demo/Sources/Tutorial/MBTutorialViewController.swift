//
//  MBTutorialViewController.swift
//  MiniCPM-V-demo
//
//  使用教程页：以卡片形式介绍下载模型、加载、对话等步骤
//

import Foundation
import UIKit
import SnapKit

@objc public class MBTutorialViewController: UIViewController {

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .grouped)
        tv.backgroundColor = UIColor.mb_color(with: "#F2F2F7") ?? .systemGroupedBackground
        tv.separatorStyle = .none
        tv.estimatedRowHeight = 320
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedSectionHeaderHeight = 120
        tv.sectionHeaderHeight = UITableView.automaticDimension
        if #available(iOS 15.0, *) {
            tv.sectionHeaderTopPadding = 0
        }
        tv.register(MBTutorialCell.self, forCellReuseIdentifier: MBTutorialCell.reuseId)
        return tv
    }()

    private var steps: [MBTutorialStep] = []

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.mb_color(with: "#F2F2F7") ?? .systemGroupedBackground
        title = "使用教程"

        steps = MBTutorialContent.steps()

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        tableView.dataSource = self
        tableView.delegate = self

        navigationItem.largeTitleDisplayMode = .never
    }

    private func makeHeaderView() -> UIView {
        let header = UIView()
        header.backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.text = "MiniCPM-V 4.6 快速入门"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "按下面的步骤即可在手机上离线运行多模态大模型，无需联网即可对话和识图。"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = UIColor.mb_color(with: "#3C3C43") ?? .darkGray
        subtitleLabel.numberOfLines = 0

        header.addSubview(titleLabel)
        header.addSubview(subtitleLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-12)
        }
        return header
    }

    private func makeFooterView() -> UIView {
        let footer = UIView()
        footer.backgroundColor = .clear

        let label = UILabel()
        label.text = "提示：模型回答由 AI 生成，不代表开发者立场，请自行甄别。"
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor.mb_color(with: "#8E8E93") ?? .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0

        footer.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-24)
        }
        return footer
    }
}

// MARK: - DataSource / Delegate

extension MBTutorialViewController: UITableViewDataSource, UITableViewDelegate {

    public func numberOfSections(in tableView: UITableView) -> Int { 1 }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return steps.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MBTutorialCell.reuseId, for: indexPath) as! MBTutorialCell
        cell.configure(steps[indexPath.row])
        return cell
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return makeHeaderView()
    }

    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return makeFooterView()
    }
}

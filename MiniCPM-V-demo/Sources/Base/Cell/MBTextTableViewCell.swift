//
//  MBTextTableViewCell.swift
//  MiniCPM-V-demo
//
//  Created by Alex on 2024/6/6.
//

import Foundation
import UIKit
import SnapKit

/// 文本 cell
class MBTextTableViewCell: UITableViewCell {
    
    /// 对应的 model
    var model: MBChatModel?
    
    /// cell 距离屏幕左、右的边距
    var cellMargin = 24
    
    // 浅蓝色 或者 白色 的背景
    lazy var containerBGView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 16
        return v
    }()
    
    /// 自定义输出的结果（文字）视图
    lazy var customLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    // MARK: - 底部 toolbar 区域
    
    /// 按钮 点击事件, model 和 点击的按钮的名字
    public var onTap: ((MBChatModel?, String?) -> Void)?

    /// [复制、重新生成、👍、🦶] toolbar 容器
    lazy var toolBarContainerView: UIView = {
        let v = UIView()
        v.clipsToBounds = true
        return v
    }()
    
    /// 工具条：复制 icon
    lazy var toolbarCopyIcon : UIImageView = {
        let icon = UIImageView.init(image: UIImage(named: "toolbar_copy"))
        return icon
    }()
    
    /// 工具条：复制 Label
    lazy var toolbarCopyLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "复制"
        lbl.textColor = UIColor.mb_color(with: "#666666")
        lbl.font = UIFont.systemFont(ofSize: 14)
        return lbl
    }()

    /// 工具条：重新生成 icon
    lazy var toolbarRegenerateIcon : UIImageView = {
        let icon = UIImageView.init(image: UIImage(named: "toolbar_regenerate"))
        icon.isHidden = true
        return icon
    }()
    
    /// 工具条：重新生成 Label
    lazy var toolbarRegenerateLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "重新生成"
        lbl.textColor = UIColor.mb_color(with: "#666666")
        lbl.font = UIFont.systemFont(ofSize: 14)
        lbl.isHidden = true
        return lbl
    }()

    /// 工具条：赞同 icon
    lazy var toolbarVoteupIcon : UIImageView = {
        let icon = UIImageView.init(image: UIImage(named: "toolbar_voteup"))
        icon.isHidden = true
        return icon
    }()

    /// 工具条：反对 icon
    lazy var toolbarVotedownIcon : UIImageView = {
        let icon = UIImageView.init(image: UIImage(named: "toolbar_votedown"))
        icon.isHidden = true
        return icon
    }()

    /// 输出的调试日志信息
    lazy var logLabel: UILabel = {
        let lb = UILabel()
        lb.textColor = UIColor.mb_color(with: "#10B601")
        lb.backgroundColor = .clear
        lb.font = .systemFont(ofSize: 12, weight: .regular)
        return lb
    }()

    // MARK: - 再次点击 cell 时弹出的 popup area
    
    /// 再次点击 cell 时弹出的 popup area，注意：这个 区域必须是 toolbar 不显示的时候才能弹出来，并且滚动 or reload 就要隐藏
    lazy var actionPopupContainerView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 8
        v.backgroundColor = UIColor.mb_color(with: "#EFF4FF")
        v.clipsToBounds = true
        return v
    }()

    /// 悬浮条：复制 icon
    lazy var floatingCopyIcon : UIImageView = {
        let icon = UIImageView.init(image: UIImage(named: "toolbar_copy"))
        return icon
    }()

    /// 悬浮条：赞同 icon
    lazy var floatingVoteupIcon : UIImageView = {
        let icon = UIImageView.init(image: UIImage(named: "toolbar_voteup"))
        return icon
    }()

    /// 悬浮条：反对 icon
    lazy var floatingVotedownIcon : UIImageView = {
        let icon = UIImageView.init(image: UIImage(named: "toolbar_votedown"))
        return icon
    }()
    
    // MARK: - 初始化方法
    
    // 初始化方法
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = .clear
        
        if MBUtils.isDeviceIPad() {
            cellMargin = 120
        }
        
        contentView.addSubview(containerBGView)
        containerBGView.snp.makeConstraints { make in
            make.left.equalTo(cellMargin)
            make.right.equalTo(-cellMargin)
            make.top.equalTo(5)
            make.bottom.equalTo(-5 - 16 /* PM 要求 log 要放在 bg 外边*/)
        }
        
        // 添加自定义视图到 cell 的内容视图（contentView）中
        containerBGView.addSubview(customLabel)
        customLabel.snp.makeConstraints { make in
            make.left.equalTo(15)
            make.top.equalTo(10)
            make.right.equalTo(-15)
            make.height.equalTo(0)
        }
        
        // 显示日志用的
        contentView.addSubview(logLabel)
        logLabel.snp.makeConstraints { make in
            make.left.equalTo(cellMargin + 6)
            make.right.equalTo(-15)
            make.height.equalTo(16)
            make.bottom.equalToSuperview().offset(-4)
        }

        // 底部工具条
        containerBGView.addSubview(toolBarContainerView)
        toolBarContainerView.snp.makeConstraints { make in
            make.left.equalTo(15)
            make.right.equalTo(-15)
            make.top.equalTo(customLabel.snp.bottom).offset(10)
            make.height.equalTo(0)
        }
        
        // toolbar-copy 按钮
        toolBarContainerView.addSubview(toolbarCopyIcon)
        toolbarCopyIcon.snp.makeConstraints { make in
            make.left.equalTo(0)
            make.centerY.equalTo(toolBarContainerView)
            make.height.width.equalTo(20)
        }
        let copyIconTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapCopyButton))
        toolbarCopyIcon.isUserInteractionEnabled = true
        toolbarCopyIcon.addGestureRecognizer(copyIconTapGesture)

        // toolbar-copy-label
        toolBarContainerView.addSubview(toolbarCopyLabel)
        toolbarCopyLabel.snp.makeConstraints { make in
            make.left.equalTo(toolbarCopyIcon.snp.right).offset(6)
            make.height.equalTo(24)
            make.centerY.equalTo(toolbarCopyIcon)
        }
        toolbarCopyLabel.isUserInteractionEnabled = true
        let copyTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapCopyButton))
        toolbarCopyLabel.addGestureRecognizer(copyTapGesture)

        // toolbar-regenerate 按钮
        toolBarContainerView.addSubview(toolbarRegenerateIcon)
        toolbarRegenerateIcon.snp.makeConstraints { make in
            make.left.equalTo(toolbarCopyLabel.snp.right).offset(16)
            make.centerY.equalTo(toolBarContainerView)
            make.height.width.equalTo(20)
        }
        toolbarRegenerateIcon.isUserInteractionEnabled = true
        let regenerateIconTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapRegenerateButton))
        toolbarRegenerateIcon.addGestureRecognizer(regenerateIconTapGesture)

        // toolbar-regenerate-label
        toolBarContainerView.addSubview(toolbarRegenerateLabel)
        toolbarRegenerateLabel.snp.makeConstraints { make in
            make.left.equalTo(toolbarRegenerateIcon.snp.right).offset(6)
            make.height.equalTo(24)
            make.centerY.equalTo(toolbarRegenerateIcon)
        }
        toolbarRegenerateLabel.isUserInteractionEnabled = true
        let regenerateLabelTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapRegenerateButton))
        toolbarRegenerateLabel.addGestureRecognizer(regenerateLabelTapGesture)

        // toolbar-voteup 按钮
        toolBarContainerView.addSubview(toolbarVoteupIcon)
        toolbarVoteupIcon.snp.makeConstraints { make in
            make.right.equalTo(-36)
            make.centerY.equalTo(toolBarContainerView)
            make.height.width.equalTo(20)
        }
        toolbarVoteupIcon.isUserInteractionEnabled = true
        let voteupTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapVoteupButton))
        toolbarVoteupIcon.addGestureRecognizer(voteupTapGesture)

        // toolbar-votedown 按钮
        toolBarContainerView.addSubview(toolbarVotedownIcon)
        toolbarVotedownIcon.snp.makeConstraints { make in
            make.right.equalTo(0)
            make.centerY.equalTo(toolBarContainerView)
            make.height.width.equalTo(20)
        }
        toolbarVotedownIcon.isUserInteractionEnabled = true
        let votedownTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapVotedownButton))
        toolbarVotedownIcon.addGestureRecognizer(votedownTapGesture)

        // 点击 cell 后弹出的 action popup area
        contentView.addSubview(actionPopupContainerView)
        actionPopupContainerView.snp.makeConstraints { make in
            make.right.equalTo(containerBGView.snp.right)
            make.top.equalTo(containerBGView.snp.bottom).offset(4)
            make.height.equalTo(0)
            make.width.equalTo(128)
        }
        
        // 把 floating 专用的 复制、赞同 和 反对 这 3 个 icon 加到 popup action 里
        actionPopupContainerView.addSubview(floatingCopyIcon)
        floatingCopyIcon.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.centerY.equalTo(actionPopupContainerView)
            make.height.width.equalTo(20)
        }
        let floatingCopyIconTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapCopyButton))
        floatingCopyIcon.isUserInteractionEnabled = true
        floatingCopyIcon.addGestureRecognizer(floatingCopyIconTapGesture)

        actionPopupContainerView.addSubview(floatingVoteupIcon)
        floatingVoteupIcon.snp.makeConstraints { make in
            make.centerX.equalTo(actionPopupContainerView)
            make.centerY.equalTo(actionPopupContainerView)
            make.height.width.equalTo(20)
        }
        let floatingVoteupIconTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapVoteupButton))
        floatingVoteupIcon.isUserInteractionEnabled = true
        floatingVoteupIcon.addGestureRecognizer(floatingVoteupIconTapGesture)

        actionPopupContainerView.addSubview(floatingVotedownIcon)
        floatingVotedownIcon.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.centerY.equalTo(actionPopupContainerView)
            make.height.width.equalTo(20)
        }
        let floatingVotedownIconTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapVotedownButton))
        floatingVotedownIcon.isUserInteractionEnabled = true
        floatingVotedownIcon.addGestureRecognizer(floatingVotedownIconTapGesture)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func bindTextWith(data: MBChatModel?) {
        model = data
        
        if let rawText = model?.contentText {
            // v4.6 sometimes emits Markdown break sequences as the literal
            // two-character escape `\n` instead of real newlines. Normalize
            // for *display only* here (model?.contentText keeps the raw
            // bytes so multi-turn / regenerate / copy-from-context paths see
            // exactly what the model produced). See MarkdownEscape.swift.
            let text = MarkdownEscape.normalizeResponseText(rawText)
            
            let para = NSMutableParagraphStyle()
            para.maximumLineHeight = 22
            para.minimumLineHeight = 22
            para.lineSpacing = 2
            para.lineBreakMode = .byWordWrapping
            
            let font: UIFont = UIFont.systemFont(ofSize: 16, weight: .regular)
            
            let textColor = UIColor.mb_color(with: "#1C1C23")
            
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: textColor ?? .gray,
                .font: font,
                .paragraphStyle: para
            ]
            
            customLabel.attributedText = NSAttributedString(string: text, attributes: attributes)
            
            // cellMargin means cell left, right margin, 15 inner text margin
            let frameWidth: CGFloat = self.contentView.frame.size.width - CGFloat((cellMargin*2 + 48/*错落有致*/)) - 30
            let size = customLabel.attributedText?.boundingRect(with: CGSize(width: frameWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).size ?? .zero

            let textWidth = ceil(size.width)

            var containerBGWidth = 15 + textWidth + 15

            if model?.role == "user" {

                self.containerBGView.backgroundColor = UIColor.mb_color(with: "#FFFFFF")
                containerBGView.snp.remakeConstraints { make in
                    make.right.equalTo(-cellMargin)
                    make.width.equalTo(containerBGWidth)
                    make.top.equalTo(5)
                    make.bottom.equalTo(-10 - 16/* floating popup area */)
                }
                
                // user 不显示 toolbar
                toolBarContainerView.snp.updateConstraints { make in
                    make.height.equalTo(0)
                }

                // self.contentView.backgroundColor = .orange

            } else if model?.role == "llm" {
                
                self.containerBGView.backgroundColor = UIColor.mb_color(with: "#EFF4FF")

                // self.contentView.backgroundColor = .yellow
                // self.containerBGView.backgroundColor = .red
                // self.customLabel.backgroundColor = .green

                if containerBGWidth < 280 {
                    // 保证可以放得下 toolbar
                    containerBGWidth = 280
                }

                containerBGView.snp.remakeConstraints { make in
                    make.left.equalTo(cellMargin)
                    make.width.equalTo(containerBGWidth)
                    make.top.equalTo(5)
                    make.bottom.equalTo(-5 - 16 /* PM 要求 log 要放在 bg 外边*/ - 24/* flaoting popup area*/)
                }
                
                // llm 底部的【复制、重新生成、👍、🦶】toolbar
                if !text.isEmpty {
                    if model?.hasBottomToolbar == true {
                        
                        if model?.voteStatus == .neutral {
                            toolbarVoteupIcon.image = UIImage(named: "toolbar_voteup")
                            toolbarVotedownIcon.image = UIImage(named: "toolbar_votedown")
                        }
                        
                        toolBarContainerView.snp.updateConstraints { make in
                            make.height.equalTo(24)
                        }
                    } else {
                        // 不显示 toolbar
                        toolBarContainerView.snp.updateConstraints { make in
                            make.height.equalTo(0)
                        }
                        
                        // 注意：floating action 只有不显示 toolbar 的情况下才能显示，要不然就会冲突
                        if model?.hasFloatingActionButton == true {
                            // 具体这个 popop 要怎么显示，由外部 click 事件触发
                            actionPopupContainerView.snp.updateConstraints { make in
                                make.height.equalTo(36)
                            }
                        } else {
                            actionPopupContainerView.snp.updateConstraints { make in
                                make.height.equalTo(0)
                            }
                        }
                        
                    }
                } else {
                    // 没有文字
                    // 不显示 toolbar
                    toolBarContainerView.snp.updateConstraints { make in
                        make.height.equalTo(0)
                    }

                    // 不显示悬浮的 popup area
                    actionPopupContainerView.snp.updateConstraints { make in
                        make.height.equalTo(0)
                    }
                }
                
            }

            // calc label height
            customLabel.snp.updateConstraints { make in
                make.height.equalTo(size.height)
            }
        } else {
            // 不显示 toolbar
            toolBarContainerView.snp.updateConstraints { make in
                make.height.equalTo(0)
            }
            
            // 不显示 action popup
            actionPopupContainerView.snp.updateConstraints { make in
                make.height.equalTo(0)
            }
        }
        
        // 显示日志
        if model?.role != "llm" {
            logLabel.textAlignment = .right
            logLabel.snp.remakeConstraints { make in
                make.right.equalTo(-cellMargin)
                make.height.equalTo(16)
                make.top.equalTo(self.containerBGView.snp.bottom).offset(4)
            }
            
        } else {
            logLabel.textAlignment = .left
            logLabel.snp.remakeConstraints { make in
                make.left.equalTo(cellMargin + 6)
                make.right.equalTo(-15)
                make.height.equalTo(16)
                make.top.equalTo(self.containerBGView.snp.bottom).offset(4)
            }
        }
        
        if let log = model?.performLog, !log.isEmpty {
            let attachment = NSTextAttachment()
            attachment.image = UIImage(named: "log_icon")?.withTintColor(UIColor.mb_color(with: "#10B601") ?? .gray)
            attachment.bounds = CGRect(x: 0, y: -1, width: 10, height: 10)
            let attachmentString = NSAttributedString(attachment: attachment)
            let firstString = NSAttributedString(string: " \(log)", attributes: [NSAttributedString.Key.foregroundColor: UIColor.mb_color(with: "#10B601") ?? .gray, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12, weight: .regular)])
            let finalString = NSMutableAttributedString()
            finalString.append(attachmentString)
            finalString.append(firstString)
            logLabel.attributedText = finalString
        } else {
            logLabel.attributedText = nil
        }

        // 不显示性能日志
        if let str = UserDefaults.standard.string(forKey: "show_statistic_log") {
            if str == "0" {
                logLabel.attributedText = nil
            }
        }
    }
    
    /// 计算 cell 高度
    public static func calcCellHeight(data: MBChatModel?, viewWidth: CGFloat) -> CGFloat {
        if let rawText = data?.contentText {
            // Mirror the display-side normalization in bindTextWith so the
            // measured height matches the rendered glyph layout (otherwise
            // v4.6 outputs with literal `\n` would measure as one short
            // line and clip when the text actually expands across many).
            let text = MarkdownEscape.normalizeResponseText(rawText)
            
            let para = NSMutableParagraphStyle()
            para.maximumLineHeight = 22
            para.minimumLineHeight = 22
            para.lineSpacing = 2
            para.lineBreakMode = .byWordWrapping
            
            let font: UIFont = UIFont.systemFont(ofSize: 16, weight: .regular)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.black,
                .font: font,
                .paragraphStyle: para
            ]
            
            let customLabel = UILabel()
            customLabel.attributedText = NSAttributedString(string: text, attributes: attributes)
            
            // 适配 iPhone + iPad
            var cellMargin: CGFloat = 32
            
            if MBUtils.isDeviceIPad() {
                cellMargin = 64 * 2
            }
            
            // cellMargin means cell left, right margin, 15 inner text margin
            let frameWidth: CGFloat = viewWidth - CGFloat((cellMargin*2 + 48/* 为了错落有致 */)) - 15/* 15 * 2 UILabel 内边距 */

            let pureContentTextframe = customLabel.attributedText?.boundingRect(with: CGSize(width: frameWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).size ?? .zero
            
            /*
             
             cell-2-cell space 8pt
             
             top space 10pt
             
             text area
             
             text bottom space 10pt
             
             toolbar area 24pt
             
             toolbar space 10pt
             
             background view space 5pt
             
             debug output area 20pt
             
             floating popup area 24pt
             */
            
            var toolbarAreaHeight = 0
            if data?.hasBottomToolbar == true {
                toolbarAreaHeight = 24 + 10
            }
            
            let cellTop = 8.0 + 10.0/* text inner top*/
            
            // 用户输入的 文本内容 不需要 log
            var logHeight = 20
            if data?.role == "user", data?.type == "TEXT" {
                logHeight = 0
            }
            
            // 10 = text inner bottom, 20 = log 的高度, 5
            let cellBottom = toolbarAreaHeight + logHeight + 34/* floating popup area */
            
            // return cell height
            return cellTop + pureContentTextframe.height + Double(cellBottom)
        }
        
        return 0
    }
}

extension MBTextTableViewCell {
    
    /// 显示 or 隐藏悬浮的 action popup area
    public func showPopupActionWith(show: Bool) {

        if model?.hasBottomToolbar == true {
            return
        }

        // 同步状态
        model?.hasFloatingActionButton = show

        if show {
            
            if model?.voteStatus == .neutral {
                floatingVoteupIcon.image = UIImage(named: "toolbar_voteup")
                floatingVotedownIcon.image = UIImage(named: "toolbar_votedown")
            } else if model?.voteStatus == .voteup {
                floatingVoteupIcon.image = UIImage(named: "toolbar_voteup_selected")
                floatingVotedownIcon.image = UIImage(named: "toolbar_votedown")
            } else if model?.voteStatus == .votedown {
                floatingVoteupIcon.image = UIImage(named: "toolbar_voteup")
                floatingVotedownIcon.image = UIImage(named: "toolbar_votedown_selected")
            }
            
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseInOut, animations: {
                self.actionPopupContainerView.alpha = 1
                self.actionPopupContainerView.snp.updateConstraints { make in
                    make.height.equalTo(36)
                }
            })
            
            // 5 秒后自动隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.showPopupActionWith(show: false)
            }
            
        } else {
            UIView.animate(withDuration: 0.15) {
                self.actionPopupContainerView.alpha = 0
            } completion: { finish in
                // 不显示 action popup
                self.actionPopupContainerView.snp.updateConstraints { make in
                    make.height.equalTo(0)
                }
            }
        }
    }
    
}

extension MBTextTableViewCell {
    
    /// copy 点击事件
    @objc public func handleTapCopyButton(_ id: UITapGestureRecognizer?) {
        onTap?(model, "copy")
    }
    
    /// regenerate 点击事件
    @objc public func handleTapRegenerateButton(_ id: UITapGestureRecognizer?) {
        onTap?(model, "regenerate")
    }

    /// vote-up 点击事件
    @objc public func handleTapVoteupButton(_ id: UITapGestureRecognizer?) {
        onTap?(model, "voteup")
        
        if model?.voteStatus != .voteup {
            model?.voteStatus = .voteup
            self.toolbarVoteupIcon.image = UIImage(named: "toolbar_voteup_selected")
            self.floatingVoteupIcon.image = UIImage(named: "toolbar_voteup_selected")
            
            // 让 down 变变 neutral
            self.toolbarVotedownIcon.image = UIImage(named: "toolbar_votedown")
            self.floatingVotedownIcon.image = UIImage(named: "toolbar_votedown")

        } else {
            model?.voteStatus = .neutral
            
            self.toolbarVoteupIcon.image = UIImage(named: "toolbar_voteup")
            self.floatingVoteupIcon.image = UIImage(named: "toolbar_voteup")
            
            // 让 down 变变 neutral
            self.toolbarVotedownIcon.image = UIImage(named: "toolbar_votedown")
            self.floatingVotedownIcon.image = UIImage(named: "toolbar_votedown")
        }
    }

    /// vote-down 点击事件
    @objc public func handleTapVotedownButton(_ id: UITapGestureRecognizer?) {
        onTap?(model, "votedown")
        
        if model?.voteStatus != .votedown {
            model?.voteStatus = .votedown
            self.toolbarVotedownIcon.image = UIImage(named: "toolbar_votedown_selected")
            self.floatingVotedownIcon.image = UIImage(named: "toolbar_votedown_selected")
            
            // 让 up 变变 neutral
            self.toolbarVoteupIcon.image = UIImage(named: "toolbar_voteup")
            self.floatingVoteupIcon.image = UIImage(named: "toolbar_voteup")

        } else {
            model?.voteStatus = .neutral
            self.toolbarVotedownIcon.image = UIImage(named: "toolbar_votedown")
            self.floatingVotedownIcon.image = UIImage(named: "toolbar_votedown")
            
            // 让 up 变变 neutral
            self.toolbarVoteupIcon.image = UIImage(named: "toolbar_voteup")
            self.floatingVoteupIcon.image = UIImage(named: "toolbar_voteup")
        }

    }

}

//
//  MarkdownEscape.swift
//  MiniCPM-V-demo
//
//  Display-only normalization for assistant text that contains literal `\n`
//  (two-character escape sequence, not real newlines).
//
//  Background: MiniCPM-V 4.6 occasionally emits Markdown-shaped output where
//  paragraph / heading / list separators are written as the *literal* two
//  characters `\` + `n` instead of actual U+000A. With the literal form
//  UILabel renders everything on a single visual line and any Markdown
//  structure collapses into a wall of text. Mirrors v46/app.py
//  `normalize_response_text`.
//
//  Trigger heuristic (matches v46/app.py exactly so we don't accidentally
//  touch user content that legitimately contains a literal `\n`):
//    * `\n\n` (paragraph break), OR
//    * `\n` followed by optional whitespace and a Markdown block opener:
//        `#..######` + space     (ATX heading)
//        `-` / `*` / `+` + space  (unordered bullet)
//        digits + `.`/`)` + space (ordered bullet)
//        `>`                      (blockquote)
//  When neither pattern is present we leave the text untouched.
//
//  Scope: invoked from MBTextTableViewCell only (text label rendering and
//  the matching cell-height calc).  The raw assistant text on
//  `MBChatModel.contentText` and the native KV-cache backed conversation
//  context are not modified - keeping multi-turn faithfulness as required
//  by the on-device demo's principle of "don't rewrite what gets fed back
//  to the conversation context".
//

import Foundation

enum MarkdownEscape {

    private static let escapedMarkdownBreak: NSRegularExpression? = {
        return try? NSRegularExpression(
            pattern: #"\\n\s*(#{1,6}\s|[-*+]\s|\d+[.)]\s|>)"#
        )
    }()

    static func normalizeResponseText(_ text: String) -> String {
        guard text.contains("\\n") else { return text }
        let hasBreak: Bool = {
            if text.contains("\\n\\n") { return true }
            if let regex = escapedMarkdownBreak {
                let range = NSRange(text.startIndex..., in: text)
                return regex.firstMatch(in: text, options: [], range: range) != nil
            }
            return false
        }()
        guard hasBreak else { return text }
        return text
            .replacingOccurrences(of: "\\r\\n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\n")
    }
}

package com.example.minicpm_v_demo

// Display-only normalization for assistant text that contains literal `\n`
// (two-character escape sequence, not real newlines).
//
// Background: MiniCPM-V 4.6 occasionally emits Markdown-shaped output where
// paragraph / heading / list separators are written as the *literal* two
// characters `\` + `n` instead of actual U+000A. With the literal form the
// Markdown renderer treats everything as one line and Markdown structure
// collapses into a wall of text. Mirrors v46/app.py `normalize_response_text`.
//
// Trigger heuristic (matches v46/app.py exactly so we don't accidentally
// touch user content that legitimately contains a literal `\n`):
//   * `\n\n` (paragraph break), OR
//   * `\n` followed by optional whitespace and a Markdown block opener:
//       `#..######` + space     (ATX heading)
//       `-` / `*` / `+` + space  (unordered bullet)
//       digits + `.`/`)` + space (ordered bullet)
//       `>`                      (blockquote)
// When neither pattern is present we leave the text untouched.
//
// Scope: this is invoked from the chat bubble renderer only. The raw
// assistant text in `ChatMessage.AiMessage.text` and the `StringBuilder`
// passed back to `LlamaEngine`/native side stays unchanged - keeping
// multi-turn faithfulness as required by the on-device demo's principle of
// "don't rewrite what gets fed back to the conversation context".
object MarkdownEscape {

    private val ESCAPED_MARKDOWN_BREAK = Regex("""\\n\s*(#{1,6}\s|[-*+]\s|\d+[.)]\s|>)""")

    fun normalizeResponseText(text: String): String {
        if (!text.contains("\\n")) return text
        val hasBreak = text.contains("\\n\\n") || ESCAPED_MARKDOWN_BREAK.containsMatchIn(text)
        if (!hasBreak) return text
        return text
            .replace("\\r\\n", "\n")
            .replace("\\n", "\n")
            .replace("\\r", "\n")
    }
}

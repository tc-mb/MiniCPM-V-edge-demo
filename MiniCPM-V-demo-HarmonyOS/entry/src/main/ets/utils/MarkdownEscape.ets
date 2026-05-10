// Display-only normalization for assistant text that contains literal `\n`
// (two-character escape sequence, not real newlines).
//
// Background: MiniCPM-V 4.6 occasionally emits Markdown-shaped output where
// paragraph / heading / list separators are written as the *literal* two
// characters `\` + `n` instead of actual U+000A. With the literal form the
// MarkdownParser treats everything as one line and the rendered bubble
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
// Scope: this is invoked from the AiMessageItem builder only.  The raw
// assistant text in `ChatMessage.text` (and anything that might later get
// fed back to `LlamaEngine.processUserPrompt`) stays unchanged - keeping
// multi-turn faithfulness as required by the on-device demo's principle of
// "don't rewrite what gets fed back to the conversation context".

const ESCAPED_MARKDOWN_BREAK: RegExp = /\\n\s*(#{1,6}\s|[-*+]\s|\d+[.)]\s|>)/;

export function normalizeResponseText(text: string): string {
  if (text.length === 0 || text.indexOf('\\n') === -1) return text;
  const hasBreak: boolean =
    text.indexOf('\\n\\n') !== -1 || ESCAPED_MARKDOWN_BREAK.test(text);
  if (!hasBreak) return text;
  return text
    .replace(/\\r\\n/g, '\n')
    .replace(/\\n/g, '\n')
    .replace(/\\r/g, '\n');
}

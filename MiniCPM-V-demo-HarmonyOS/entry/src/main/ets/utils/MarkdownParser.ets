// Lightweight Markdown -> Block list parser for streaming AI responses.
//
// Why hand-roll instead of pulling a library: ArkTS has no official Markdown
// component, marked.js would require a per-bubble WebView (heavy + clunky for
// streaming token updates). We only need enough fidelity to make code blocks,
// headings, lists, and inline emphasis look right; full CommonMark compliance
// is overkill.
//
// Supported syntax:
//   block-level:
//     # / ## / ### / #### / ##### / ######  headings
//     ```lang ... ```                       fenced code blocks
//     - item / * item / + item             unordered list
//     1. item / 2. item                    ordered list (only renders the bullet)
//     blank line                           paragraph break
//   inline (within paragraphs / lists / headings):
//     **bold**
//     *italic* / _italic_
//     `inline code`
//
// Streaming-friendly: re-parse the whole text on every token update. Partial
// syntax (e.g. an unclosed `**bo`) renders as literal characters until it
// completes, which is the same behavior as Markwon on Android.

export enum BlockType {
  PARAGRAPH = 'paragraph',
  HEADING = 'heading',
  LIST_ITEM = 'list_item',
  CODE_BLOCK = 'code_block',
}

export enum InlineType {
  TEXT = 'text',
  BOLD = 'bold',
  ITALIC = 'italic',
  CODE = 'code',
}

export interface InlineSpan {
  type: InlineType;
  text: string;
}

export interface MdBlock {
  type: BlockType;
  // For headings: 1..6. For list_item: 0 = unordered, otherwise the ordered
  // index. For code_block: the optional language string. Unused for paragraphs.
  level: number;
  language: string;
  // Empty for code blocks, which carry their raw content in `raw` instead.
  spans: InlineSpan[];
  raw: string;
}

export function parseMarkdown(text: string): MdBlock[] {
  const blocks: MdBlock[] = [];
  const lines: string[] = text.split('\n');

  let i = 0;
  while (i < lines.length) {
    const line: string = lines[i];

    // Fenced code block
    if (line.startsWith('```')) {
      const lang: string = line.substring(3).trim();
      const codeLines: string[] = [];
      i++;
      while (i < lines.length && !lines[i].startsWith('```')) {
        codeLines.push(lines[i]);
        i++;
      }
      // Skip the closing ```. If the stream cut off mid-block the ``` is missing
      // and we still render the partial content.
      if (i < lines.length) {
        i++;
      }
      blocks.push({
        type: BlockType.CODE_BLOCK,
        level: 0,
        language: lang,
        spans: [],
        raw: codeLines.join('\n'),
      });
      continue;
    }

    // Heading
    const headingMatch: RegExpMatchArray | null = line.match(/^(#{1,6})\s+(.*)$/);
    if (headingMatch !== null) {
      const level: number = headingMatch[1].length;
      const content: string = headingMatch[2];
      blocks.push({
        type: BlockType.HEADING,
        level: level,
        language: '',
        spans: parseInline(content),
        raw: content,
      });
      i++;
      continue;
    }

    // Unordered list item
    const ulMatch: RegExpMatchArray | null = line.match(/^\s*[-*+]\s+(.*)$/);
    if (ulMatch !== null) {
      blocks.push({
        type: BlockType.LIST_ITEM,
        level: 0,
        language: '',
        spans: parseInline(ulMatch[1]),
        raw: ulMatch[1],
      });
      i++;
      continue;
    }

    // Ordered list item
    const olMatch: RegExpMatchArray | null = line.match(/^\s*(\d+)\.\s+(.*)$/);
    if (olMatch !== null) {
      blocks.push({
        type: BlockType.LIST_ITEM,
        level: parseInt(olMatch[1], 10),
        language: '',
        spans: parseInline(olMatch[2]),
        raw: olMatch[2],
      });
      i++;
      continue;
    }

    // Blank line: only emit a paragraph break if we're not already at one.
    if (line.trim().length === 0) {
      i++;
      continue;
    }

    // Paragraph: gather contiguous non-blank, non-special lines
    const paraLines: string[] = [line];
    i++;
    while (i < lines.length) {
      const peek: string = lines[i];
      if (peek.trim().length === 0) {
        break;
      }
      if (peek.startsWith('```') || peek.match(/^#{1,6}\s+/) !== null
          || peek.match(/^\s*[-*+]\s+/) !== null
          || peek.match(/^\s*\d+\.\s+/) !== null) {
        break;
      }
      paraLines.push(peek);
      i++;
    }
    const paragraph: string = paraLines.join('\n');
    blocks.push({
      type: BlockType.PARAGRAPH,
      level: 0,
      language: '',
      spans: parseInline(paragraph),
      raw: paragraph,
    });
  }

  return blocks;
}

// Parse inline emphasis. Token-by-token scan; we accept `**bold**`,
// `*italic*` / `_italic_`, and `` `code` ``. Anything that doesn't match
// (including unclosed markers in streaming content) becomes literal text.
export function parseInline(text: string): InlineSpan[] {
  const spans: InlineSpan[] = [];
  let buf: string = '';
  let i = 0;
  const len: number = text.length;

  const flushBuf = (): void => {
    if (buf.length > 0) {
      spans.push({ type: InlineType.TEXT, text: buf });
      buf = '';
    }
  };

  while (i < len) {
    const ch: string = text.charAt(i);

    // **bold**
    if (ch === '*' && i + 1 < len && text.charAt(i + 1) === '*') {
      const closeIdx: number = text.indexOf('**', i + 2);
      if (closeIdx > i + 2) {
        flushBuf();
        spans.push({ type: InlineType.BOLD, text: text.substring(i + 2, closeIdx) });
        i = closeIdx + 2;
        continue;
      }
    }

    // *italic* / _italic_
    if ((ch === '*' || ch === '_') && i + 1 < len) {
      const next: string = text.charAt(i + 1);
      // skip stray markers like "* " (likely already a list bullet handled
      // upstream) or "**" (handled above)
      if (next !== ch && next !== ' ') {
        const closeIdx: number = text.indexOf(ch, i + 1);
        if (closeIdx > i + 1) {
          const inner: string = text.substring(i + 1, closeIdx);
          // disallow newlines inside emphasis to avoid eating multi-paragraph chunks
          if (inner.indexOf('\n') === -1) {
            flushBuf();
            spans.push({ type: InlineType.ITALIC, text: inner });
            i = closeIdx + 1;
            continue;
          }
        }
      }
    }

    // `inline code`
    if (ch === '`') {
      const closeIdx: number = text.indexOf('`', i + 1);
      if (closeIdx > i + 1) {
        flushBuf();
        spans.push({ type: InlineType.CODE, text: text.substring(i + 1, closeIdx) });
        i = closeIdx + 1;
        continue;
      }
    }

    buf += ch;
    i++;
  }

  flushBuf();
  return spans;
}

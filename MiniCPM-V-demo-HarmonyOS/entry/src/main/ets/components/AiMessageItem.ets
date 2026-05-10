// Left-aligned assistant bubble with an inline "stop generating" button while
// `isGenerating` is true. Mirrors item_ai_message.xml + ChatAdapter
// AiMessageViewHolder from the Android demo.
//
// Renders the text through MarkdownParser so headings, lists, **bold**,
// *italic*, `code`, and ``` fenced ``` blocks come out with proper visual
// styling instead of as literal characters.

import { ChatMessage } from '../data/ChatMessage';
import { parseMarkdown, BlockType, InlineType, MdBlock, InlineSpan } from '../utils/MarkdownParser';
import { normalizeResponseText } from '../utils/MarkdownEscape';

@Component
export struct AiMessageItem {
  @ObjectLink message: ChatMessage;
  onStop: () => void = () => undefined;

  // Map heading levels 1..6 to font sizes (in fp).
  private headingFontSize(level: number): number {
    if (level <= 1) return 22;
    if (level === 2) return 19;
    if (level === 3) return 17;
    return 16;
  }

  // Render a sequence of inline spans inside a single Text container.
  // Using a builder keeps the @Component happy with conditional Span children.
  @Builder
  inlineRow(spans: InlineSpan[], baseFontSize: number, baseWeight: FontWeight) {
    Text() {
      ForEach(spans, (span: InlineSpan, _idx: number) => {
        if (span.type === InlineType.BOLD) {
          Span(span.text)
            .fontSize(baseFontSize)
            .fontWeight(FontWeight.Bold);
        } else if (span.type === InlineType.ITALIC) {
          Span(span.text)
            .fontSize(baseFontSize)
            .fontStyle(FontStyle.Italic)
            .fontWeight(baseWeight);
        } else if (span.type === InlineType.CODE) {
          Span(' ' + span.text + ' ')
            .fontSize(baseFontSize - 1)
            .fontFamily('HarmonyOS Sans Condensed')
            .fontColor('#C7254E')
            .backgroundColor('#33FF6680')
            .fontWeight(baseWeight);
        } else {
          Span(span.text)
            .fontSize(baseFontSize)
            .fontWeight(baseWeight);
        }
      })
    }
    .fontColor($r('app.color.on_surface'))
    .lineHeight(baseFontSize + 7);
  }

  @Builder
  block(b: MdBlock) {
    if (b.type === BlockType.HEADING) {
      this.inlineRow(b.spans, this.headingFontSize(b.level), FontWeight.Bold);
    } else if (b.type === BlockType.LIST_ITEM) {
      Row({ space: 6 }) {
        Text(b.level === 0 ? '•' : `${b.level}.`)
          .fontSize(15)
          .fontColor($r('app.color.on_surface'))
          .width(b.level === 0 ? 12 : 24);
        Column() {
          this.inlineRow(b.spans, 15, FontWeight.Normal);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .alignItems(VerticalAlign.Top)
      .width('100%');
    } else if (b.type === BlockType.CODE_BLOCK) {
      Text(b.raw)
        .fontSize(13)
        .fontFamily('HarmonyOS Sans Condensed')
        .fontColor('#1F2328')
        .backgroundColor('#33000000')
        .padding(10)
        .borderRadius(6)
        .width('100%');
    } else {
      this.inlineRow(b.spans, 15, FontWeight.Normal);
    }
  }

  build() {
    Row() {
      Column({ space: 6 }) {
        Column({ space: 6 }) {
          // Re-parse on every render. Cost is sub-millisecond for a few KB of
          // streaming content, and re-parsing each token keeps partial syntax
          // visible-as-literal until it completes (matches Markwon behavior).
          //
          // [normalizeResponseText] is the only place where assistant output
          // is touched for v4.6's literal `\n` artefact.  It runs at the
          // rendering boundary so the canonical text on `ChatMessage.text`
          // (and any future re-feed into the model) remains byte-identical
          // to what native produced.
          ForEach(parseMarkdown(normalizeResponseText(this.message.text.length > 0 ? this.message.text : ' ')),
            (b: MdBlock, idx: number) => {
              this.block(b);
            });
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.ai_bubble'))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start);

        if (this.message.isGenerating) {
          Button($r('app.string.btn_stop'))
            .fontSize(13)
            .height(28)
            .backgroundColor($r('app.color.surface_variant'))
            .fontColor($r('app.color.on_surface'))
            .onClick(() => this.onStop());
        }
      }
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: '78%' });

      // right spacer keeps the bubble pinned to the left
      Blank().layoutWeight(1);
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Top);
  }
}

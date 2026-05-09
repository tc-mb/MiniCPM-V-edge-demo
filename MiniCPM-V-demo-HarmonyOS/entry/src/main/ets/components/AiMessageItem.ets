// Left-aligned assistant bubble with an inline "stop generating" button while
// `isGenerating` is true. Mirrors item_ai_message.xml + ChatAdapter
// AiMessageViewHolder from the Android demo.

import { ChatMessage } from '../data/ChatMessage';

@Component
export struct AiMessageItem {
  @ObjectLink message: ChatMessage;
  onStop: () => void = () => undefined;

  build() {
    Row() {
      Column({ space: 6 }) {
        Text(this.message.text.length > 0 ? this.message.text : ' ')
          .fontSize(15)
          .fontColor($r('app.color.on_surface'))
          .lineHeight(22)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor($r('app.color.ai_bubble'))
          .borderRadius(12);

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

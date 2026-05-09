// Renders the first ListItem in the chat. Mirrors item_welcome_card.xml from
// the Android demo: a heading, a short description, and two suggestion chips
// the user can tap to seed the input field.

@Component
export struct WelcomeCard {
  onSuggestion: (s: string) => void = () => undefined;

  build() {
    // Outer wrapper supplies the side / vertical spacing.  The inner Column
    // is the actual card (rounded background + content padding).  Splitting
    // the two avoids the classic ArkUI pitfall of `width('100%') + margin`
    // overflowing the parent (100% + 32 > screen width).
    Column() {
      Column() {
        Text($r('app.string.welcome_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.on_surface'))
          .margin({ bottom: 8 });

        Text($r('app.string.welcome_desc'))
          .fontSize(14)
          .fontColor($r('app.color.on_surface_variant'))
          .lineHeight(20)
          .margin({ bottom: 16 });

        Row({ space: 12 }) {
          Button($r('app.string.suggestion_1'))
            .fontSize(14)
            .height(36)
            .layoutWeight(1)
            .backgroundColor($r('app.color.primary_container'))
            .fontColor($r('app.color.primary'))
            .onClick(() => this.onSuggestion(getContext(this).resourceManager.getStringSync($r('app.string.suggestion_1').id)));
          Button($r('app.string.suggestion_2'))
            .fontSize(14)
            .height(36)
            .layoutWeight(1)
            .backgroundColor($r('app.color.primary_container'))
            .fontColor($r('app.color.primary'))
            .onClick(() => this.onSuggestion(getContext(this).resourceManager.getStringSync($r('app.string.suggestion_2').id)));
        }
        .width('100%');
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.surface_variant'))
      .borderRadius(12);
    }
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 16, right: 16 });
  }
}

import { AISettingsUiTokens } from '../AISettingsUiTokens';

@Component
export struct AISettingsSection {
  title: string | Resource = '';
  @BuilderParam content: () => void = this.defaultContent;

  @Builder
  defaultContent() {
  }

  build() {
    Column() {
      Text(this.title)
        .fontSize(AISettingsUiTokens.titleSection)
        .fontColor(AISettingsUiTokens.textSecondary)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 8, left: 4 })

      Column() {
        this.content()
      }
      .width('100%')
      .backgroundColor(AISettingsUiTokens.cardBackground)
      .borderRadius(AISettingsUiTokens.cardRadius)
      .clip(true)
      .padding({
        top: AISettingsUiTokens.cardPadding,
        bottom: AISettingsUiTokens.cardPadding
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

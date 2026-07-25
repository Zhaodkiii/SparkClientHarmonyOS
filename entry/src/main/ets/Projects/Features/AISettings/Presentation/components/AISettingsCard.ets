import { AISettingsUiTokens } from '../AISettingsUiTokens';

/** 白色圆角内容卡片容器 */
@Component
export struct AISettingsCard {
  @BuilderParam content: () => void = this.defaultContent;

  @Builder
  defaultContent() {
  }

  build() {
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
}

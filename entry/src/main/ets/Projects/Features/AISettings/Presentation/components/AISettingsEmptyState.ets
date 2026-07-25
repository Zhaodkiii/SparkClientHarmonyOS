import { AISettingsUiTokens } from '../AISettingsUiTokens';

@Component
export struct AISettingsEmptyState {
  message: string | Resource = '';
  actionTitle: string = '';
  onAction: () => void = () => {
  };

  build() {
    Column() {
      Text(this.message)
        .fontSize(15)
        .fontColor(AISettingsUiTokens.textSecondary)
        .textAlign(TextAlign.Center)
      if (this.actionTitle.length > 0) {
        Button(this.actionTitle)
          .margin({ top: 16 })
          .fontColor(AISettingsUiTokens.accent)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .padding(24)
    .alignItems(HorizontalAlign.Center)
  }
}

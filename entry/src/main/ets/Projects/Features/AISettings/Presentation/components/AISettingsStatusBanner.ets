import { AISettingsUiTokens } from '../AISettingsUiTokens';

@Component
export struct AISettingsStatusBanner {
  syncText: string = '';
  errorMessage: string = '';
  loading: boolean = false;
  hasUnsaved: boolean = false;
  onRetry: () => void = () => {
  };

  build() {
    Column() {
      Row() {
        Column() {
          Text($r('app.string.ai_settings_sync_state'))
            .fontSize(12)
            .fontColor(AISettingsUiTokens.textSecondary)
          Text(this.syncText.length > 0 ? this.syncText : '—')
            .fontSize(15)
            .fontColor(AISettingsUiTokens.textPrimary)
            .margin({ top: 4 })
          if (this.hasUnsaved) {
            Text($r('app.string.ai_settings_unsaved'))
              .fontSize(12)
              .fontColor(AISettingsUiTokens.warning)
              .margin({ top: 4 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.loading) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(AISettingsUiTokens.accent)
        }
      }
      .width('100%')

      if (this.errorMessage.length > 0) {
        Row() {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor(AISettingsUiTokens.error)
            .layoutWeight(1)
            .maxLines(3)
          Button($r('app.string.ai_settings_retry'))
            .fontSize(13)
            .height(32)
            .backgroundColor(Color.Transparent)
            .fontColor(AISettingsUiTokens.accent)
            .onClick(() => {
              this.onRetry();
            })
        }
        .width('100%')
        .margin({ top: 10 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AISettingsUiTokens.cardBackground)
    .borderRadius(16)
  }
}

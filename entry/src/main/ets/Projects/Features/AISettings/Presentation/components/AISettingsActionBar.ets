import { AISettingsUiTokens } from '../AISettingsUiTokens';

@Component
export struct AISettingsActionBar {
  saving: boolean = false;
  hasUnsaved: boolean = false;
  loading: boolean = false;
  onRefresh: () => void = () => {
  };
  onDiscard: () => void = () => {
  };
  onSave: () => void = () => {
  };

  build() {
    Row() {
      Button($r('app.string.ai_settings_refresh'))
        .fontSize(14)
        .height(36)
        .enabled(!this.loading && !this.saving)
        .backgroundColor('#E5E5EA')
        .fontColor(AISettingsUiTokens.textPrimary)
        .onClick(() => {
          this.onRefresh();
        })
      Blank()
      Button($r('app.string.ai_settings_discard'))
        .fontSize(14)
        .height(36)
        .enabled(this.hasUnsaved && !this.saving)
        .backgroundColor(Color.Transparent)
        .fontColor(AISettingsUiTokens.accent)
        .onClick(() => {
          this.onDiscard();
        })
      Button($r('app.string.ai_settings_save'))
        .fontSize(14)
        .height(36)
        .margin({ left: 8 })
        .enabled(this.hasUnsaved && !this.saving)
        .backgroundColor(this.hasUnsaved ? AISettingsUiTokens.accent : '#C7C7CC')
        .fontColor(Color.White)
        .onClick(() => {
          this.onSave();
        })
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }
}

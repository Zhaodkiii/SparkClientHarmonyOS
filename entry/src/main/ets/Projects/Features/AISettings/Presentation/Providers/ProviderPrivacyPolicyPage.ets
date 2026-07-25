import { webview } from '@kit.ArkWeb';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsUiTokens } from '../AISettingsUiTokens';

@Component
export struct ProviderPrivacyPolicyPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  url: string = '';
  @State private loadFailed: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();

  private doBack(): void {
    if (this.onBack) {
      this.onBack();
    } else {
      this.stack.pop();
    }
  }

  build() {
    Column() {
      AISettingsNavHeader({
        title: $r('app.string.ai_settings_provider_privacy'),
        onBack: () => {
          this.doBack();
        }
      })

      if (this.url.length === 0) {
        Text('隐私政策地址不可用')
          .fontSize(14)
          .fontColor(AISettingsUiTokens.textSecondary)
          .padding(24)
          .width('100%')
      } else if (this.loadFailed) {
        Column() {
          Text('页面加载失败')
            .fontSize(15)
            .fontColor(AISettingsUiTokens.error)
          Button($r('app.string.ai_settings_retry'))
            .margin({ top: 12 })
            .fontColor(AISettingsUiTokens.accent)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.loadFailed = false;
            })
        }
        .padding(24)
        .width('100%')
      } else {
        Web({ src: this.url, controller: this.controller })
          .width('100%')
          .layoutWeight(1)
          .onErrorReceive(() => {
            this.loadFailed = true;
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }
}

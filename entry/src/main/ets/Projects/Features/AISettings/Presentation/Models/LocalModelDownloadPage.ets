import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { LocalModelPresentation } from '../../Application/ProviderModelCatalogService';
import { ProviderModelCatalogService } from '../../Application/ProviderModelCatalogService';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { AISettingsEmptyState } from '../components/AISettingsEmptyState';

@Component
export struct LocalModelDownloadPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  @State private tick: number = 0;
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
    this.vm?.setOnChanged(() => {
      this.tick++;
    });
  }

  private doBack(): void {
    if (this.onBack) {
      this.onBack();
    } else {
      this.stack.pop();
    }
  }

  private rows(): LocalModelPresentation[] {
    if (!this.vm?.draftSnapshot) {
      return [];
    }
    return ProviderModelCatalogService.localModels(this.vm.draftSnapshot);
  }

  private installLabel(state: string): string {
    if (state === 'ready') {
      return '已安装';
    }
    if (state === 'downloading') {
      return '下载中';
    }
    if (state === 'failed') {
      return '安装失败';
    }
    if (state === 'verified') {
      return '已校验';
    }
    return '未安装';
  }

  build() {
    Column() {
      AISettingsNavHeader({
        title: $r('app.string.ai_settings_model_local'),
        onBack: () => {
          this.doBack();
        }
      })

      Scroll() {
        Column() {
          Column() {
            Text($r('app.string.ai_settings_local_unavailable_title'))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(AISettingsUiTokens.textPrimary)
              .width('100%')
            Text($r('app.string.ai_settings_local_unavailable_body'))
              .fontSize(14)
              .fontColor(AISettingsUiTokens.textSecondary)
              .margin({ top: 12 })
              .width('100%')
            Text('本页只管理本地模型文件生命周期，不显示 API Key、endpoint 或隐私政策。')
              .fontSize(13)
              .fontColor(AISettingsUiTokens.textSecondary)
              .margin({ top: 12 })
              .width('100%')
          }
          .width('100%')
          .padding(20)
          .backgroundColor(AISettingsUiTokens.cardBackground)
          .borderRadius(AISettingsUiTokens.cardRadius)
          .alignItems(HorizontalAlign.Start)

          Text('本地模型')
            .fontSize(AISettingsUiTokens.titleSection)
            .fontColor(AISettingsUiTokens.textSecondary)
            .width('100%')
            .margin({ top: 20, bottom: 8, left: 4 })

          if (this.rows().length === 0) {
            Column() {
              AISettingsEmptyState({ message: '暂无本地模型元数据' })
            }
            .width('100%')
            .backgroundColor(AISettingsUiTokens.cardBackground)
            .borderRadius(AISettingsUiTokens.cardRadius)
          } else {
            Column() {
              ForEach(this.rows(), (m: LocalModelPresentation, index: number) => {
                Column() {
                  Text(m.displayName)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AISettingsUiTokens.textPrimary)
                    .width('100%')
                  Text(`${m.localizedProviderName} · ${this.installLabel(m.installState)} · ${m.enabled ? '已启用' : '已关闭'}`)
                    .fontSize(12)
                    .fontColor(AISettingsUiTokens.textSecondary)
                    .margin({ top: 4 })
                    .width('100%')
                  if (index < this.rows().length - 1) {
                    Divider()
                      .color(AISettingsUiTokens.divider)
                      .strokeWidth(0.5)
                      .margin({ top: 12 })
                  }
                }
                .width('100%')
                .padding(16)
              }, (m: LocalModelPresentation) => `${m.modelId}-${this.tick}`)
            }
            .width('100%')
            .backgroundColor(AISettingsUiTokens.cardBackground)
            .borderRadius(AISettingsUiTokens.cardRadius)
            .clip(true)
          }

          Blank().height(24)
        }
        .width('100%')
        .padding({
          left: AISettingsUiTokens.pagePaddingH,
          right: AISettingsUiTokens.pagePaddingH,
          bottom: 16
        })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }
}

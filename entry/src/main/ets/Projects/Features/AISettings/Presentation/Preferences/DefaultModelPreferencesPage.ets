import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { AISettingsRoutes } from '../AISettingsRoutes';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { AIDefaultSource } from '../../../../../Core/AI/Domain/AIConfigModels';
import { AIProviderDisplayNameResolver } from '../../../../../Core/AI/Presentation/AIProviderDisplayNameResolver';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsEmptyState } from '../components/AISettingsEmptyState';

@Component
export struct DefaultModelPreferencesPage {
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

  private sourceLabel(scenario: string): string {
    const s = this.vm?.scenarioSource(scenario) ?? 'auto';
    if (s === 'local') {
      return '本地';
    }
    if (s === 'pro') {
      return 'Pro';
    }
    return '自动';
  }

  private defaultModelLabel(scenario: string): string {
    const bindings = this.vm?.bindingsForScenario(scenario) ?? [];
    for (let i = 0; i < bindings.length; i++) {
      if (bindings[i].isDefault) {
        const mid = bindings[i].modelId;
        const models = this.vm?.models() ?? [];
        for (let j = 0; j < models.length; j++) {
          if (models[j].id === mid) {
            const providerName = AIProviderDisplayNameResolver.displayByIds(
              models[j].providerId,
              '',
              '',
              models[j].source
            );
            return `${models[j].displayName || models[j].name} · ${providerName}`;
          }
        }
        return mid;
      }
    }
    return '未配置';
  }

  build() {
    Column() {
      AISettingsNavHeader({
        title: $r('app.string.ai_settings_hub_preferences'),
        onBack: () => {
          this.doBack();
        }
      })

      Scroll() {
        Column() {
          if ((this.vm?.knownScenarios() ?? []).length === 0) {
            Column() {
              AISettingsEmptyState({
                message: '暂无场景，请先刷新 Pro 配置或检查种子数据',
                actionTitle: '刷新',
                onAction: () => {
                  this.vm?.refreshRemote();
                }
              })
            }
            .width('100%')
            .backgroundColor(AISettingsUiTokens.cardBackground)
            .borderRadius(AISettingsUiTokens.cardRadius)
          } else {
            Column() {
              ForEach(this.vm?.knownScenarios() ?? [], (scenario: string, index: number) => {
                Column() {
                  Row() {
                    Column() {
                      Text(scenario)
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(AISettingsUiTokens.textPrimary)
                      Text(`默认：${this.defaultModelLabel(scenario)} · 来源：${this.sourceLabel(scenario)}`)
                        .fontSize(12)
                        .fontColor(AISettingsUiTokens.textSecondary)
                        .margin({ top: 4 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    SymbolGlyph($r('sys.symbol.chevron_forward'))
                      .fontSize(16)
                      .fontColor([AISettingsUiTokens.textSecondary])
                  }
                  .width('100%')
                  .padding(16)
                  .onClick(() => {
                    this.stack.pushPath({ name: AISettingsRoutes.SCENARIO_BINDING, param: scenario });
                  })

                  Row() {
                    Button('本地')
                      .fontSize(11)
                      .height(28)
                      .backgroundColor(this.sourceLabel(scenario) === '本地' ? AISettingsUiTokens.accent : '#E5E5EA')
                      .fontColor(this.sourceLabel(scenario) === '本地' ? Color.White : AISettingsUiTokens.textPrimary)
                      .onClick(() => {
                        this.vm?.setScenarioSource(scenario, 'local' as AIDefaultSource);
                      })
                    Button('Pro')
                      .fontSize(11)
                      .height(28)
                      .margin({ left: 6 })
                      .backgroundColor(this.sourceLabel(scenario) === 'Pro' ? AISettingsUiTokens.accent : '#E5E5EA')
                      .fontColor(this.sourceLabel(scenario) === 'Pro' ? Color.White : AISettingsUiTokens.textPrimary)
                      .onClick(() => {
                        this.vm?.setScenarioSource(scenario, 'pro' as AIDefaultSource);
                      })
                    Button('自动')
                      .fontSize(11)
                      .height(28)
                      .margin({ left: 6 })
                      .backgroundColor(this.sourceLabel(scenario) === '自动' ? AISettingsUiTokens.accent : '#E5E5EA')
                      .fontColor(this.sourceLabel(scenario) === '自动' ? Color.White : AISettingsUiTokens.textPrimary)
                      .onClick(() => {
                        this.vm?.setScenarioSource(scenario, 'auto' as AIDefaultSource);
                      })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, bottom: 12 })

                  if (index < (this.vm?.knownScenarios().length ?? 1) - 1) {
                    Divider()
                      .color(AISettingsUiTokens.divider)
                      .strokeWidth(0.5)
                      .margin({ left: 16, right: 16 })
                  }
                }
                .width('100%')
              }, (s: string) => `${s}-${this.tick}`)
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
          right: AISettingsUiTokens.pagePaddingH
        })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }
}

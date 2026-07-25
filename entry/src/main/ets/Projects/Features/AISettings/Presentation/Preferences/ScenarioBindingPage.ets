import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { AISettingsRoutes } from '../AISettingsRoutes';
import { LocalScenarioBinding } from '../../../../../Core/AI/Domain/AIConfigModels';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsUiTokens } from '../AISettingsUiTokens';

@Component
export struct ScenarioBindingPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  scenario: string = '';
  @State private tick: number = 0;
  @State private editModelId: string = '';
  @State private temperature: string = '0.7';
  @State private maxTokens: string = '4096';
  @State private prompt: string = '';
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
    this.vm?.setOnChanged(() => {
      this.tick++;
    });
  }

  private bindings(): LocalScenarioBinding[] {
    return this.vm?.bindingsForScenario(this.scenario) ?? [];
  }

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
        title: this.scenario.length > 0 ? this.scenario : '场景绑定',
        onBack: () => {
          this.doBack();
        }
      })

      List() {
        ForEach(this.bindings(), (b: LocalScenarioBinding) => {
          ListItem() {
            Column() {
              Row() {
                Column() {
                  Text(b.modelId)
                    .fontSize(14)
                    .fontColor(AISettingsUiTokens.textPrimary)
                  Text(`temp=${b.temperature ?? '-'} · tokens=${b.maxTokens ?? '-'}`)
                    .fontSize(12)
                    .fontColor(AISettingsUiTokens.textSecondary)
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (b.isDefault) {
                  Text('默认')
                    .fontSize(12)
                    .fontColor(AISettingsUiTokens.success)
                } else {
                  Button('设为默认')
                    .fontSize(11)
                    .onClick(() => {
                      this.vm?.setScenarioDefault(this.scenario, b.modelId);
                    })
                }
              }
              .width('100%')

              Row() {
                Button('编辑参数')
                  .fontSize(11)
                  .onClick(() => {
                    this.editModelId = b.modelId;
                    this.temperature = `${b.temperature ?? 0.7}`;
                    this.maxTokens = `${b.maxTokens ?? 4096}`;
                    this.prompt = b.systemProvision ?? '';
                  })
                Button('工具')
                  .fontSize(11)
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.stack.pushPath({
                      name: AISettingsRoutes.TOOL_SELECT,
                      param: `${this.scenario}|${b.modelId}`
                    });
                  })
                Button('关联任务')
                  .fontSize(11)
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.stack.pushPath({
                      name: AISettingsRoutes.TASK_SELECT,
                      param: `${this.scenario}|${b.modelId}`
                    });
                  })
              }
              .margin({ top: 8 })
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .alignItems(HorizontalAlign.Start)
          }
        }, (b: LocalScenarioBinding) => `${b.modelId}-${this.tick}`)
      }
      .layoutWeight(1)
      .margin({ left: 24, right: 24 })
      .backgroundColor(AISettingsUiTokens.cardBackground)
      .borderRadius(AISettingsUiTokens.cardRadius)
      .divider({ strokeWidth: 0.5, color: AISettingsUiTokens.divider })

      if (this.editModelId.length > 0) {
        Column() {
          Text(`编辑 ${this.editModelId}`)
            .fontSize(14)
            .width('100%')
          TextInput({ text: this.temperature, placeholder: 'temperature' })
            .margin({ top: 6 })
            .onChange((v: string) => {
              this.temperature = v;
            })
          TextInput({ text: this.maxTokens, placeholder: 'maxTokens' })
            .margin({ top: 6 })
            .onChange((v: string) => {
              this.maxTokens = v;
            })
          TextArea({ text: this.prompt })
            .height(80)
            .margin({ top: 6 })
            .onChange((v: string) => {
              this.prompt = v;
            })
          Button('保存参数')
            .margin({ top: 8 })
            .onClick(() => {
              const list = this.bindings();
              for (let i = 0; i < list.length; i++) {
                if (list[i].modelId === this.editModelId) {
                  const b = list[i];
                  b.temperature = Number(this.temperature);
                  b.maxTokens = Number(this.maxTokens);
                  b.systemProvision = this.prompt;
                  this.vm?.upsertBinding(b);
                  this.editModelId = '';
                  break;
                }
              }
            })
        }
        .padding(16)
        .width('100%')
        .backgroundColor(AISettingsUiTokens.cardBackground)
      }

      if (this.bindings().length === 0) {
        Text('该场景暂无绑定，请先添加模型后再配置')
          .fontSize(13)
          .fontColor(AISettingsUiTokens.textSecondary)
          .padding(16)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }
}

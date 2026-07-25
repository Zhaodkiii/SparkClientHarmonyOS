import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { LocalModel } from '../../../../../Core/AI/Domain/AIConfigModels';
import { AISettingsErrorLocalizer } from '../../Application/AISettingsErrorLocalizer';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsUiTokens } from '../AISettingsUiTokens';

@Component
export struct AgentEditorPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  modelId: string = '';
  @State private displayName: string = '';
  @State private baseModelId: string = '';
  @State private systemProvision: string = '';
  @State private errorText: string = '';
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
    if (this.modelId.length > 0) {
      const list = this.vm?.models() ?? [];
      for (let i = 0; i < list.length; i++) {
        if (list[i].id === this.modelId) {
          this.displayName = list[i].displayName;
          this.systemProvision = list[i].systemProvision ?? '';
          const baseName = list[i].baseModelName ?? '';
          const bases = this.baseModels();
          for (let j = 0; j < bases.length; j++) {
            if (bases[j].name === baseName && bases[j].providerId === list[i].providerId) {
              this.baseModelId = bases[j].id;
            }
          }
        }
      }
    }
  }

  private doBack(): void {
    if (this.onBack) {
      this.onBack();
    } else {
      this.stack.pop();
    }
  }

  private baseModels(): LocalModel[] {
    return (this.vm?.models() ?? []).filter((m: LocalModel) => m.identity !== 'agent');
  }

  build() {
    Column() {
      AISettingsNavHeader({
        title: $r('app.string.ai_settings_model_agent_add'),
        onBack: () => {
          this.doBack();
        }
      })
      Scroll() {
        Column() {
          Text('智能体名称')
            .fontSize(13)
            .fontColor(AISettingsUiTokens.textSecondary)
            .width('100%')
          TextInput({ text: this.displayName })
            .margin({ top: 6 })
            .onChange((v: string) => {
              this.displayName = v;
            })

          Text('基座模型')
            .fontSize(13)
            .fontColor(AISettingsUiTokens.textSecondary)
            .margin({ top: 12 })
            .width('100%')
          ForEach(this.baseModels(), (m: LocalModel) => {
            Row() {
              Radio({ value: m.id, group: 'base' })
                .checked(this.baseModelId === m.id)
                .onChange((c: boolean) => {
                  if (c) {
                    this.baseModelId = m.id;
                  }
                })
              Text(m.displayName || m.name)
                .margin({ left: 8 })
            }
            .width('100%')
            .padding({ top: 4, bottom: 4 })
          }, (m: LocalModel) => m.id)

          Text('系统提示词')
            .fontSize(13)
            .fontColor(AISettingsUiTokens.textSecondary)
            .margin({ top: 12 })
            .width('100%')
          TextArea({ text: this.systemProvision })
            .height(120)
            .margin({ top: 6 })
            .onChange((v: string) => {
              this.systemProvision = v;
            })

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(12)
              .fontColor(AISettingsUiTokens.error)
              .margin({ top: 8 })
          }

          Button($r('app.string.common_action_confirm'))
            .margin({ top: 16 })
            .onClick(() => {
              try {
                this.vm?.upsertAgent(
                  this.displayName,
                  this.baseModelId,
                  this.systemProvision,
                  this.modelId.length > 0 ? this.modelId : undefined
                );
                this.doBack();
              } catch (err) {
                this.errorText = AISettingsErrorLocalizer.localize(err as Object);
              }
            })
        }
        .width('100%')
        .padding(AISettingsUiTokens.pagePaddingH)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }
}

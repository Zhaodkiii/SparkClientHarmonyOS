import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { LocalScenarioBinding, LocalSmallTask } from '../../../../../Core/AI/Domain/AIConfigModels';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsUiTokens } from '../AISettingsUiTokens';

@Component
export struct SmallTaskSelectionPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  bindingKey: string = '';
  @State private selected: string[] = [];
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
    const b = this.binding();
    this.selected = b?.relatedTaskCodes ? b.relatedTaskCodes.slice() : [];
  }

  private parts(): string[] {
    return this.bindingKey.split('|');
  }

  private binding(): LocalScenarioBinding | undefined {
    const parts = this.parts();
    if (parts.length < 2) {
      return undefined;
    }
    const list = this.vm?.bindingsForScenario(parts[0]) ?? [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].modelId === parts[1]) {
        return list[i];
      }
    }
    return undefined;
  }

  private toggle(code: string): void {
    if (this.selected.indexOf(code) >= 0) {
      this.selected = this.selected.filter((c: string) => c !== code);
    } else {
      this.selected = this.selected.concat([code]);
    }
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
        title: '关联小任务',
        onBack: () => {
          this.doBack();
        }
      })
      Text(`已选 ${this.selected.length} 项`)
        .fontSize(13)
        .fontColor(AISettingsUiTokens.textSecondary)
        .padding({ left: 24, right: 24, top: 8, bottom: 8 })
        .width('100%')
      List() {
        ForEach(this.vm?.smallTasks() ?? [], (t: LocalSmallTask) => {
          ListItem() {
            Row() {
              Toggle({
                type: ToggleType.Checkbox,
                isOn: this.selected.indexOf(t.code) >= 0
              })
                .onChange(() => {
                  this.toggle(t.code);
                })
              Column() {
                Text(t.name)
                  .fontSize(14)
                Text(t.code)
                  .fontSize(12)
                  .fontColor(AISettingsUiTokens.textSecondary)
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 8 })
            }
            .padding(16)
            .width('100%')
          }
        }, (t: LocalSmallTask) => t.code)
      }
      .layoutWeight(1)
      .margin({ left: 24, right: 24 })
      .backgroundColor(AISettingsUiTokens.cardBackground)
      .borderRadius(AISettingsUiTokens.cardRadius)
      Button($r('app.string.common_action_confirm'))
        .margin(16)
        .onClick(() => {
          const b = this.binding();
          if (b) {
            b.relatedTaskCodes = this.selected.slice();
            this.vm?.upsertBinding(b);
          }
          this.doBack();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }
}

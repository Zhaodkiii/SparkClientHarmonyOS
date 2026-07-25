import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { LocalScenarioBinding } from '../../../../../Core/AI/Domain/AIConfigModels';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsUiTokens } from '../AISettingsUiTokens';

const TOOL_OPTIONS: string[] = [
  'web_search',
  'code_interpreter',
  'image_gen',
  'file_reader',
  'calculator'
];

@Component
export struct ToolSelectionPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  bindingKey: string = '';
  @State private selected: string[] = [];
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
    const b = this.binding();
    this.selected = b?.aiToolScenarios ? b.aiToolScenarios.slice() : [];
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

  private toggle(tool: string): void {
    if (this.selected.indexOf(tool) >= 0) {
      this.selected = this.selected.filter((t: string) => t !== tool);
    } else {
      this.selected = this.selected.concat([tool]);
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
        title: '选择工具',
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
        ForEach(TOOL_OPTIONS, (tool: string) => {
          ListItem() {
            Row() {
              Toggle({
                type: ToggleType.Checkbox,
                isOn: this.selected.indexOf(tool) >= 0
              })
                .onChange(() => {
                  this.toggle(tool);
                })
              Text(tool)
                .margin({ left: 8 })
            }
            .padding(16)
            .width('100%')
          }
        }, (t: string) => t)
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
            b.aiToolScenarios = this.selected.slice();
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

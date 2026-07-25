import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { LocalModel } from '../../../../../Core/AI/Domain/AIConfigModels';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsUiTokens } from '../AISettingsUiTokens';

@Component
export struct ModelIconPickerPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  modelId: string = '';
  private readonly icons: string[] = ['default', 'robot', 'doctor', 'chat', 'spark'];
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
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
        title: '选择图标',
        onBack: () => {
          this.doBack();
        }
      })
      Text('选择图标（本地资源名）')
        .fontSize(14)
        .fontColor(AISettingsUiTokens.textSecondary)
        .padding({
          left: AISettingsUiTokens.pagePaddingH,
          right: AISettingsUiTokens.pagePaddingH,
          top: 8,
          bottom: 8
        })
        .width('100%')
      List() {
        ForEach(this.icons, (icon: string) => {
          ListItem() {
            Text(icon)
              .fontSize(15)
              .padding(16)
              .width('100%')
              .onClick(() => {
                const list = this.vm?.models() ?? [];
                for (let i = 0; i < list.length; i++) {
                  if (list[i].id === this.modelId) {
                    const m: LocalModel = list[i];
                    m.icon = icon;
                    this.vm?.upsertModel(m);
                    this.doBack();
                    break;
                  }
                }
              })
          }
        }, (icon: string) => icon)
      }
      .layoutWeight(1)
      .margin({
        left: AISettingsUiTokens.pagePaddingH,
        right: AISettingsUiTokens.pagePaddingH
      })
      .backgroundColor(AISettingsUiTokens.cardBackground)
      .borderRadius(AISettingsUiTokens.cardRadius)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }
}

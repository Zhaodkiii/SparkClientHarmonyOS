import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsUiTokens } from '../AISettingsUiTokens';

@Component
export struct PromptInputDrawerPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  taskCode: string = '';

  private readonly templates: string[] = [
    '请用简洁中文回答：',
    '提取以下内容的关键字段：',
    '将输入整理为结构化 JSON：'
  ];

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
        title: 'Prompt 模板',
        onBack: () => {
          this.doBack();
        }
      })
      Text('Prompt 模板（首期仅文本插入；OCR/语音即将支持）')
        .fontSize(14)
        .fontColor(AISettingsUiTokens.textSecondary)
        .padding(16)
        .width('100%')
      List() {
        ForEach(this.templates, (t: string) => {
          ListItem() {
            Text(t)
              .fontSize(15)
              .padding(16)
              .width('100%')
              .onClick(() => {
                AppStorage.setOrCreate('ai_prompt_insert', t);
                this.doBack();
              })
          }
        }, (t: string) => t)
      }
      .layoutWeight(1)
      .margin({ left: 24, right: 24 })
      .backgroundColor(AISettingsUiTokens.cardBackground)
      .borderRadius(AISettingsUiTokens.cardRadius)
      Text('OCR / 语音输入：即将支持')
        .fontSize(12)
        .fontColor(AISettingsUiTokens.textSecondary)
        .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }
}

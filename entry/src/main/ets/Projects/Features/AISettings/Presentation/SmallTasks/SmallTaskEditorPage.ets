import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { AISettingsRoutes } from '../AISettingsRoutes';
import { LocalSmallTask } from '../../../../../Core/AI/Domain/AIConfigModels';
import { SmallTaskUseCases } from '../../Application/SmallTaskUseCases';
import { AISettingsErrorLocalizer } from '../../Application/AISettingsErrorLocalizer';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsUiTokens } from '../AISettingsUiTokens';

@Component
export struct SmallTaskEditorPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  taskCode: string = '';
  @State private code: string = '';
  @State private name: string = '';
  @State private brief: string = '';
  @State private prompt: string = '';
  @State private toolsText: string = '';
  @State private errorText: string = '';
  private vm?: AISettingsViewModel;
  private isNew: boolean = true;

  onPageShow(): void {
    const inserted = AppStorage.get<string>('ai_prompt_insert');
    if (inserted && inserted.length > 0) {
      this.prompt = this.prompt.length > 0 ? `${this.prompt}\n${inserted}` : inserted;
      AppStorage.delete('ai_prompt_insert');
    }
  }

  aboutToAppear(): void {
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
    if (this.taskCode.length > 0) {
      this.isNew = false;
      const list = this.vm?.smallTasks() ?? [];
      for (let i = 0; i < list.length; i++) {
        if (list[i].code === this.taskCode) {
          this.code = list[i].code;
          this.name = list[i].name;
          this.brief = list[i].brief ?? '';
          this.prompt = list[i].prompt;
          this.toolsText = list[i].toolList.join(',');
        }
      }
    } else {
      const blank = SmallTaskUseCases.createBlank();
      this.code = blank.code;
      this.isNew = true;
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
        title: this.isNew ? '新建小任务' : '编辑小任务',
        onBack: () => {
          this.doBack();
        }
      })
      Scroll() {
        Column() {
          Text('Code')
            .fontSize(13)
            .fontColor(AISettingsUiTokens.textSecondary)
            .width('100%')
          TextInput({ text: this.code })
            .enabled(this.isNew)
            .margin({ top: 6 })
            .onChange((v: string) => {
              this.code = v;
            })

          Text('名称')
            .fontSize(13)
            .fontColor(AISettingsUiTokens.textSecondary)
            .margin({ top: 12 })
            .width('100%')
          TextInput({ text: this.name })
            .margin({ top: 6 })
            .onChange((v: string) => {
              this.name = v;
            })

          Text('简介')
            .fontSize(13)
            .fontColor(AISettingsUiTokens.textSecondary)
            .margin({ top: 12 })
            .width('100%')
          TextInput({ text: this.brief })
            .margin({ top: 6 })
            .onChange((v: string) => {
              this.brief = v;
            })

          Text('Prompt')
            .fontSize(13)
            .fontColor(AISettingsUiTokens.textSecondary)
            .margin({ top: 12 })
            .width('100%')
          TextArea({ text: this.prompt })
            .height(120)
            .margin({ top: 6 })
            .onChange((v: string) => {
              this.prompt = v;
            })
          Button('插入模板')
            .margin({ top: 8 })
            .fontColor(AISettingsUiTokens.accent)
            .backgroundColor(AISettingsUiTokens.cardBackground)
            .onClick(() => {
              this.stack.pushPath({ name: AISettingsRoutes.PROMPT_DRAWER, param: this.code });
            })

          Text('工具（逗号分隔）')
            .fontSize(13)
            .fontColor(AISettingsUiTokens.textSecondary)
            .margin({ top: 12 })
            .width('100%')
          TextInput({ text: this.toolsText })
            .margin({ top: 6 })
            .onChange((v: string) => {
              this.toolsText = v;
            })

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(12)
              .fontColor(AISettingsUiTokens.error)
              .margin({ top: 8 })
              .width('100%')
          }

          Button($r('app.string.common_action_confirm'))
            .margin({ top: 16 })
            .onClick(() => {
              try {
                const t = new LocalSmallTask();
                t.code = this.code;
                t.name = this.name;
                t.brief = this.brief;
                t.prompt = this.prompt;
                t.source = 'Local';
                t.isEnabled = true;
                const parts = this.toolsText.split(',');
                for (let i = 0; i < parts.length; i++) {
                  const p = parts[i].trim();
                  if (p.length > 0) {
                    t.toolList.push(p);
                  }
                }
                this.vm?.upsertSmallTask(t);
                this.doBack();
              } catch (err) {
                this.errorText = AISettingsErrorLocalizer.localize(err as Object);
              }
            })

          if (!this.isNew) {
            Button('删除')
              .margin({ top: 12 })
              .fontColor(AISettingsUiTokens.error)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                try {
                  this.vm?.deleteSmallTask(this.code);
                  this.doBack();
                } catch (err) {
                  this.errorText = AISettingsErrorLocalizer.localize(err as Object);
                }
              })
          }
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

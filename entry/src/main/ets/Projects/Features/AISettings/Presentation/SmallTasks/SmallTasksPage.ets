import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { AISettingsRoutes } from '../AISettingsRoutes';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { LocalSmallTask } from '../../../../../Core/AI/Domain/AIConfigModels';
import { SmallTaskUseCases } from '../../Application/SmallTaskUseCases';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsEmptyState } from '../components/AISettingsEmptyState';

@Component
export struct SmallTasksPage {
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

  build() {
    Column() {
      AISettingsNavHeader({
        title: $r('app.string.ai_settings_hub_tasks'),
        actionTitle: '+',
        onBack: () => {
          this.doBack();
        },
        onAction: () => {
          this.stack.pushPath({ name: AISettingsRoutes.SMALL_TASK_EDIT, param: '' });
        }
      })

      Scroll() {
        Column() {
          if ((this.vm?.smallTasks() ?? []).length === 0) {
            Column() {
              AISettingsEmptyState({
                message: $r('app.string.ai_settings_empty_tasks'),
                actionTitle: '新建',
                onAction: () => {
                  this.stack.pushPath({ name: AISettingsRoutes.SMALL_TASK_EDIT, param: '' });
                }
              })
            }
            .width('100%')
            .backgroundColor(AISettingsUiTokens.cardBackground)
            .borderRadius(AISettingsUiTokens.cardRadius)
          } else {
            Column() {
              ForEach(this.vm?.smallTasks() ?? [], (t: LocalSmallTask, index: number) => {
                Column() {
                  Row() {
                    Column() {
                      Text(t.name)
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(AISettingsUiTokens.textPrimary)
                      Text(`${t.code} · ${t.source}${SmallTaskUseCases.isEditable(t) ? '' : ' · 只读'}`)
                        .fontSize(12)
                        .fontColor(AISettingsUiTokens.textSecondary)
                        .margin({ top: 4 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    if (SmallTaskUseCases.isEditable(t)) {
                      SymbolGlyph($r('sys.symbol.chevron_forward'))
                        .fontSize(16)
                        .fontColor([AISettingsUiTokens.textSecondary])
                    }
                  }
                  .width('100%')
                  .padding(16)
                  .opacity(SmallTaskUseCases.isEditable(t) ? 1 : 0.7)
                  .onClick(() => {
                    if (SmallTaskUseCases.isEditable(t)) {
                      this.stack.pushPath({ name: AISettingsRoutes.SMALL_TASK_EDIT, param: t.code });
                    }
                  })
                  if (index < (this.vm?.smallTasks().length ?? 1) - 1) {
                    Divider()
                      .color(AISettingsUiTokens.divider)
                      .strokeWidth(0.5)
                      .margin({ left: 16, right: 16 })
                  }
                }
                .width('100%')
              }, (t: LocalSmallTask) => `${t.code}-${this.tick}`)
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

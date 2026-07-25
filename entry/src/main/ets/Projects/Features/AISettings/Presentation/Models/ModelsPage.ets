import { promptAction } from '@kit.ArkUI';
import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { AISettingsRoutes } from '../AISettingsRoutes';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { AIModelPresentation } from '../../Application/ProviderModelCatalogService';
import { AISettingsEmptyState } from '../components/AISettingsEmptyState';
import { ModelsMainRowComponent } from './ModelsMainRowComponent';
import { AddOnlineModelSheet } from './AddOnlineModelSheet';
import { EditModelPage } from './EditModelPage';
import { L10n } from '../../../../../Foundation/L10n/L10n';

/**
 * 对标 iOS ModelsSettingsView：分段筛选 + 搜索 + 卡片列表 + 添加菜单。
 */
@Component
export struct ModelsPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  @State private tick: number = 0;
  /** all | models | agents — 对标 ModelsSettingsIdentityFilter */
  @State private filter: string = 'all';
  @State private query: string = '';
  @State private isEditing: boolean = false;
  @State private showAddOnline: boolean = false;
  /** 对标 iOS EditSparkModelSheet */
  @State private showEditModel: boolean = false;
  @State private editModelId: string = '';
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
    this.vm?.setOnChanged(() => {
      this.tick++;
    });
    const hasRows = (this.vm?.visibleModelRows(this.filter, this.query).length ?? 0) > 0;
    if (!hasRows || (this.vm?.loading ?? false)) {
      this.vm?.load().then(() => {
        this.tick++;
      });
    }
  }

  private doBack(): void {
    if (this.onBack) {
      this.onBack();
    } else {
      this.stack.pop();
    }
  }

  private rows(): AIModelPresentation[] {
    return this.vm?.visibleModelRows(this.filter, this.query) ?? [];
  }

  private isProReadonly(row: AIModelPresentation): boolean {
    return row.source === 'pro' || row.id.indexOf('pro:') === 0 ||
      row.providerId.indexOf('pro:') === 0 || (this.vm?.isProModelRow(row.id) ?? false);
  }

  private pageTitle(): string {
    if (this.filter === 'agents') {
      return L10n.getString($r('app.string.ai_settings_models_nav_title_agents'), '智能体');
    }
    return L10n.getString($r('app.string.ai_settings_hub_models'), '模型');
  }

  private searchPrompt(): string {
    if (this.filter === 'agents') {
      return L10n.getString($r('app.string.ai_settings_models_search_agents'), '搜索智能体');
    }
    return L10n.getString($r('app.string.ai_settings_models_search_models'), '搜索模型');
  }

  private async onToggleEnabled(row: AIModelPresentation, enabled: boolean): Promise<void> {
    if (this.isProReadonly(row)) {
      return;
    }
    const ok = await this.vm?.setModelEnabledAndPersist(row.id, enabled);
    this.tick++;
    if (ok === false) {
      const msg = this.vm?.errorMessage ?? '';
      if (msg.length > 0) {
        try {
          promptAction.showToast({ message: msg, duration: 2000 });
        } catch (_e) {
          // ignore
        }
      }
    }
  }

  private openEditor(row: AIModelPresentation): void {
    if (this.isProReadonly(row)) {
      return;
    }
    if (row.availability === 'install') {
      this.stack.pushPath({ name: AISettingsRoutes.MODEL_LOCAL });
      return;
    }
    if (row.availability === 'configureKey') {
      this.stack.pushPath({ name: AISettingsRoutes.PROVIDER_EDIT, param: row.providerId });
      return;
    }
    if (row.identity === 'agent') {
      this.stack.pushPath({ name: AISettingsRoutes.MODEL_AGENT, param: row.id });
      return;
    }
    // 对标 iOS .sheet { EditSparkModelSheet }
    this.editModelId = row.id;
    this.showEditModel = true;
  }

  @Builder
  private addOnlineSheetBuilder() {
    AddOnlineModelSheet({
      showAsPage: false,
      onClose: () => {
        this.showAddOnline = false;
      },
      onSaved: () => {
        this.tick++;
      }
    })
  }

  @Builder
  private editModelSheetBuilder() {
    EditModelPage({
      stack: this.stack,
      modelId: this.editModelId,
      onBack: () => {
        this.showEditModel = false;
        this.tick++;
      }
    })
  }

  @Builder
  private circleBtn(symbol: Resource, onClick: () => void) {
    Button() {
      SymbolGlyph(symbol)
        .fontSize(20)
        .fontColor([AISettingsUiTokens.textPrimary])
    }
    .width(AISettingsUiTokens.backBtnSize)
    .height(AISettingsUiTokens.backBtnSize)
    .borderRadius(AISettingsUiTokens.backBtnSize / 2)
    .backgroundColor('#E5E5EA')
    .onClick(onClick)
  }

  @Builder
  private segmentChip(id: string, title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(this.filter === id ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.filter === id ? AISettingsUiTokens.textPrimary : AISettingsUiTokens.textSecondary)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.filter === id ? AISettingsUiTokens.cardBackground : Color.Transparent)
      .borderRadius(8)
      .onClick(() => {
        this.filter = id;
      })
  }

  /** 勿命名为 toolbar：与 CustomComponent.toolbar 冲突 */
  @Builder
  private modelsNavBar() {
    Row({ space: 8 }) {
      this.circleBtn($r('sys.symbol.chevron_backward'), () => {
        this.doBack();
      })

      if (this.isEditing) {
        this.circleBtn($r('sys.symbol.star'), () => {
          try {
            promptAction.showToast({ message: '排序重置即将支持', duration: 1500 });
          } catch (_e) {
            // ignore
          }
        })
      } else {
        Button() {
          SymbolGlyph($r('sys.symbol.plus_circle_fill'))
            .fontSize(22)
            .fontColor([AISettingsUiTokens.textPrimary])
        }
        .width(AISettingsUiTokens.backBtnSize)
        .height(AISettingsUiTokens.backBtnSize)
        .borderRadius(AISettingsUiTokens.backBtnSize / 2)
        .backgroundColor('#E5E5EA')
        .bindMenu([
          {
            value: L10n.getString($r('app.string.ai_settings_model_add'), '添加在线模型'),
            action: () => {
              this.showAddOnline = true;
            }
          },
          {
            value: L10n.getString($r('app.string.ai_settings_model_local'), '本地模型'),
            action: () => {
              this.stack.pushPath({ name: AISettingsRoutes.MODEL_LOCAL });
            }
          },
          {
            value: L10n.getString($r('app.string.ai_settings_model_agent_add'), '新建智能体'),
            action: () => {
              this.stack.pushPath({ name: AISettingsRoutes.MODEL_AGENT, param: '' });
            }
          }
        ])
      }

      Blank().layoutWeight(1)

      if (!this.isEditing) {
        Row({ space: 2 }) {
          this.segmentChip('all', L10n.getString($r('app.string.common_all'), '全部'))
          this.segmentChip('models', L10n.getString($r('app.string.ai_settings_models_filter_models'), '模型'))
          this.segmentChip('agents', L10n.getString($r('app.string.ai_settings_models_filter_agents'), '智能体'))
        }
        .padding(3)
        .backgroundColor('#E5E5EA')
        .borderRadius(10)
      }

      Blank().layoutWeight(1)

      this.circleBtn(
        this.isEditing ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.square_stack_3d'),
        () => {
          this.isEditing = !this.isEditing;
        }
      )
    }
    .width('100%')
    .height(AISettingsUiTokens.headerHeight)
    .padding({
      left: AISettingsUiTokens.pagePaddingH,
      right: AISettingsUiTokens.pagePaddingH
    })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      this.modelsNavBar()

      Text(this.pageTitle())
        .fontSize(AISettingsUiTokens.titleLarge)
        .fontWeight(FontWeight.Bold)
        .fontColor(AISettingsUiTokens.textPrimary)
        .width('100%')
        .padding({
          left: AISettingsUiTokens.pagePaddingH,
          right: AISettingsUiTokens.pagePaddingH,
          top: 4,
          bottom: 12
        })

      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.doc_text'))
          .fontSize(16)
          .fontColor([AISettingsUiTokens.textSecondary])
        TextInput({ text: this.query, placeholder: this.searchPrompt() })
          .layoutWeight(1)
          .height(36)
          .backgroundColor(Color.Transparent)
          .padding(0)
          .onChange((v: string) => {
            this.query = v;
          })
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .margin({
        left: AISettingsUiTokens.pagePaddingH,
        right: AISettingsUiTokens.pagePaddingH,
        bottom: 12
      })
      .backgroundColor(AISettingsUiTokens.cardBackground)
      .borderRadius(20)

      Scroll() {
        Column() {
          if (this.rows().length === 0) {
            Column() {
              AISettingsEmptyState({ message: $r('app.string.ai_settings_empty_models') })
            }
            .width('100%')
            .backgroundColor(AISettingsUiTokens.cardBackground)
            .borderRadius(AISettingsUiTokens.cardRadius)
            .padding({ top: 24, bottom: 24 })
          } else {
            Column() {
              ForEach(this.rows(), (m: AIModelPresentation, index: number) => {
                ModelsMainRowComponent({
                  model: m,
                  showDivider: index < this.rows().length - 1,
                  isEditing: this.isEditing,
                  isReadonly: this.isProReadonly(m),
                  onInfo: () => {
                    this.openEditor(m);
                  },
                  onToggleEnabled: (on: boolean) => {
                    this.onToggleEnabled(m, on);
                  }
                })
              }, (m: AIModelPresentation) => `${m.id}-${m.isEnabled}-${this.tick}`)
            }
            .width('100%')
            .backgroundColor(AISettingsUiTokens.cardBackground)
            .borderRadius(AISettingsUiTokens.cardRadius)
            .clip(true)
          }

          Blank().height(32)
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
    .bindSheet($$this.showAddOnline, this.addOnlineSheetBuilder(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: false,
      backgroundColor: AISettingsUiTokens.pageBackground
    })
    .bindSheet($$this.showEditModel, this.editModelSheetBuilder(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: false,
      backgroundColor: AISettingsUiTokens.pageBackground,
      onDisappear: () => {
        this.showEditModel = false;
        this.tick++;
      }
    })
  }
}

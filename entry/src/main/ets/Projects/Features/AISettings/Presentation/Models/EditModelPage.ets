import { promptAction } from '@kit.ArkUI';
import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { AISettingsRoutes } from '../AISettingsRoutes';
import {
  LocalModel,
  LocalProvider,
  LocalSmallTask,
  ModelCapabilities
} from '../../../../../Core/AI/Domain/AIConfigModels';
import { isLocalProviderId } from '../../../../../Core/AI/Domain/AILocalProviderIds';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { L10n } from '../../../../../Foundation/L10n/L10n';

/** 与 ToolSelectionPage 对齐的常用工具集合（摘要用） */
const MODEL_TOOL_OPTIONS: string[] = [
  'web_search',
  'code_interpreter',
  'image_gen',
  'file_reader',
  'calculator'
];

const MODEL_ICON_OPTIONS: string[] = [
  'sparkles',
  'cpu',
  'brain',
  'heart',
  'chat',
  'doctor'
];

/**
 * 对标 iOS EditSparkModelSheet：显示名、图标、使用场景与工具、能力开关。
 * 由 ModelsPage / ProviderEditorPage 通过 bindSheet 打开；亦保留路由全页入口。
 */
@Component
export struct EditModelPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  modelId: string = '';

  @State private displayName: string = '';
  @State private iconSymbol: string = 'sparkles';
  @State private supportsText: boolean = true;
  @State private supportsMultimodal: boolean = false;
  @State private supportsReasoning: boolean = false;
  @State private reasoningControllable: boolean = false;
  @State private supportsToolUse: boolean = false;
  @State private supportsImageGen: boolean = false;
  @State private selectedTools: string[] = MODEL_TOOL_OPTIONS.slice();
  @State private selectedTaskCodes: string[] = [];
  @State private hasSynced: boolean = false;
  @State private saving: boolean = false;
  @State private showIconPicker: boolean = false;
  @State private showToolPicker: boolean = false;
  @State private showTaskPicker: boolean = false;
  @State private tick: number = 0;
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    // sheet 每次打开都重新从模型同步，避免复用上次草稿
    this.hasSynced = false;
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
    this.vm?.setOnChanged(() => {
      this.tick++;
      this.syncFromModel();
    });
    this.syncFromModel();
  }

  private doBack(): void {
    if (this.onBack) {
      this.onBack();
    } else {
      this.stack.pop();
    }
  }

  private model(): LocalModel | undefined {
    const list = this.vm?.models() ?? [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === this.modelId) {
        return list[i];
      }
    }
    return undefined;
  }

  private provider(): LocalProvider | undefined {
    const m = this.model();
    if (!m) {
      return undefined;
    }
    const list = this.vm?.draftSnapshot?.providers ?? [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === m.providerId) {
        return list[i];
      }
    }
    return undefined;
  }

  /** 对标 iOS canEditCapabilities：非本地厂商可编辑能力 */
  private canEditCapabilities(): boolean {
    const m = this.model();
    if (!m) {
      return false;
    }
    if (m.modelType === 'gguf' || isLocalProviderId(m.providerId)) {
      return false;
    }
    const p = this.provider();
    if (p && (p.kind === 'local' || isLocalProviderId(p.id))) {
      return false;
    }
    return true;
  }

  private syncFromModel(): void {
    if (this.hasSynced) {
      return;
    }
    const m = this.model();
    if (!m) {
      return;
    }
    this.displayName = m.displayName || m.name;
    this.iconSymbol = (m.icon && m.icon.length > 0) ? m.icon : 'sparkles';
    this.supportsText = m.capabilities.supportsText;
    this.supportsMultimodal = m.capabilities.supportsMultimodal;
    this.supportsReasoning = m.capabilities.supportsReasoning;
    this.reasoningControllable = m.capabilities.reasoningControllable;
    this.supportsToolUse = m.capabilities.supportsToolUse;
    this.supportsImageGen = m.capabilities.supportsImageGen;
    this.selectedTools = (m.aiToolScenarios && m.aiToolScenarios.length > 0)
      ? m.aiToolScenarios.slice()
      : MODEL_TOOL_OPTIONS.slice();
    this.selectedTaskCodes = m.relatedTaskCodes ? m.relatedTaskCodes.slice() : [];
    this.hasSynced = true;
  }

  private scenarioBindingCount(): number {
    const list = this.vm?.draftSnapshot?.scenarioBindings ?? [];
    let n = 0;
    for (let i = 0; i < list.length; i++) {
      if (list[i].modelId === this.modelId) {
        n++;
      }
    }
    return n;
  }

  private toolsSummary(): string {
    if (this.selectedTools.length >= MODEL_TOOL_OPTIONS.length) {
      return L10n.getString($r('app.string.common_all'), '全部');
    }
    return `${this.selectedTools.length}/${MODEL_TOOL_OPTIONS.length}`;
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    const cur = this.model();
    if (!cur) {
      this.doBack();
      return;
    }
    this.saving = true;
    try {
      cur.displayName = this.displayName.trim() || cur.name;
      cur.icon = this.iconSymbol;
      if (this.canEditCapabilities()) {
        const caps = new ModelCapabilities();
        caps.supportsText = this.supportsText;
        caps.supportsSearch = cur.capabilities.supportsSearch;
        caps.supportsMultimodal = this.supportsMultimodal;
        caps.supportsReasoning = this.supportsReasoning;
        caps.supportsToolUse = this.supportsToolUse;
        caps.supportsVoiceGen = cur.capabilities.supportsVoiceGen;
        caps.supportsImageGen = this.supportsImageGen;
        caps.supportsDeepReasoning = cur.capabilities.supportsDeepReasoning;
        caps.reasoningControllable = this.reasoningControllable;
        cur.capabilities = caps;
        cur.aiToolScenarios = this.selectedTools.slice();
        cur.relatedTaskCodes = this.selectedTaskCodes.slice();
      }
      const ok = await this.vm?.replaceModelAndPersist(cur);
      if (ok) {
        this.doBack();
      } else {
        const msg = this.vm?.errorMessage ?? '';
        if (msg.length > 0) {
          try {
            promptAction.showToast({ message: msg, duration: 2000 });
          } catch (_e) {
            // ignore
          }
        }
      }
    } finally {
      this.saving = false;
    }
  }

  private toggleTool(tool: string): void {
    if (this.selectedTools.indexOf(tool) >= 0) {
      this.selectedTools = this.selectedTools.filter((t: string) => t !== tool);
    } else {
      this.selectedTools = this.selectedTools.concat([tool]);
    }
  }

  private toggleTask(code: string): void {
    if (this.selectedTaskCodes.indexOf(code) >= 0) {
      this.selectedTaskCodes = this.selectedTaskCodes.filter((c: string) => c !== code);
    } else {
      this.selectedTaskCodes = this.selectedTaskCodes.concat([code]);
    }
  }

  private taskRows(): LocalSmallTask[] {
    return this.vm?.smallTasks() ?? [];
  }

  @Builder
  private pillBtn(title: string, emphasized: boolean, onClick: () => void) {
    Text(title)
      .fontSize(16)
      .fontWeight(emphasized ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(emphasized ? AISettingsUiTokens.textPrimary : AISettingsUiTokens.textSecondary)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor('#E5E5EA')
      .borderRadius(16)
      .onClick(onClick)
  }

  @Builder
  private sectionLabel(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor(AISettingsUiTokens.textSecondary)
      .width('100%')
      .padding({ left: 4, bottom: 6, top: 16 })
  }

  @Builder
  private navRow(title: string, value: string, showDivider: boolean, onClick: () => void) {
    Column() {
      Row() {
        Text(title)
          .fontSize(16)
          .fontColor(AISettingsUiTokens.textPrimary)
          .layoutWeight(1)
        Text(value)
          .fontSize(15)
          .fontColor(AISettingsUiTokens.textSecondary)
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(14)
          .fontColor([AISettingsUiTokens.textSecondary])
          .margin({ left: 4 })
      }
      .width('100%')
      .constraintSize({ minHeight: 48 })
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .onClick(onClick)

      if (showDivider) {
        Divider()
          .color(AISettingsUiTokens.divider)
          .strokeWidth(0.5)
          .margin({ left: 16 })
      }
    }
    .width('100%')
  }

  @Builder
  private capabilityToggle(
    title: string,
    isOn: boolean,
    showDivider: boolean,
    onChange: (v: boolean) => void
  ) {
    Column() {
      Row() {
        Text(title)
          .fontSize(16)
          .fontColor(AISettingsUiTokens.textPrimary)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: isOn })
          .selectedColor(AISettingsUiTokens.success)
          .onChange((v: boolean) => {
            onChange(v);
          })
      }
      .width('100%')
      .constraintSize({ minHeight: 48 })
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      if (showDivider) {
        Divider()
          .color(AISettingsUiTokens.divider)
          .strokeWidth(0.5)
          .margin({ left: 16 })
      }
    }
    .width('100%')
  }

  @Builder
  private iconPickerSheet() {
    Column() {
      Text(L10n.getString($r('app.string.ai_settings_models_edit_section_icon'), '图标'))
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AISettingsUiTokens.textPrimary)
        .padding(16)
        .width('100%')
      List() {
        ForEach(MODEL_ICON_OPTIONS, (icon: string) => {
          ListItem() {
            Row() {
              Text(icon)
                .fontSize(16)
                .fontColor(AISettingsUiTokens.textPrimary)
                .layoutWeight(1)
              if (this.iconSymbol === icon) {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                  .fontSize(18)
                  .fontColor([AISettingsUiTokens.accent])
              }
            }
            .width('100%')
            .padding(16)
            .onClick(() => {
              this.iconSymbol = icon;
              this.showIconPicker = false;
            })
          }
        }, (icon: string) => icon)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }

  @Builder
  private toolPickerSheet() {
    Column() {
      Text(L10n.getString($r('app.string.common_tools'), '工具'))
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .padding(16)
        .width('100%')
      List() {
        ForEach(MODEL_TOOL_OPTIONS, (tool: string) => {
          ListItem() {
            Row() {
              Text(tool)
                .fontSize(15)
                .fontColor(AISettingsUiTokens.textPrimary)
                .layoutWeight(1)
              if (this.selectedTools.indexOf(tool) >= 0) {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                  .fontSize(18)
                  .fontColor([AISettingsUiTokens.accent])
              }
            }
            .width('100%')
            .padding(16)
            .onClick(() => {
              this.toggleTool(tool);
            })
          }
        }, (tool: string) => tool)
      }
      .layoutWeight(1)
      Button(L10n.getString($r('app.string.common_done'), '完成'))
        .margin(16)
        .onClick(() => {
          this.showToolPicker = false;
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }

  @Builder
  private taskPickerSheet() {
    Column() {
      Text(L10n.getString($r('app.string.ai_settings_models_agent_related_tasks'), '关联小任务'))
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .padding(16)
        .width('100%')
      List() {
        ForEach(this.taskRows(), (t: LocalSmallTask) => {
          ListItem() {
            Row() {
              Text(`${t.name} (${t.code})`)
                .fontSize(15)
                .fontColor(AISettingsUiTokens.textPrimary)
                .layoutWeight(1)
              if (this.selectedTaskCodes.indexOf(t.code) >= 0) {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                  .fontSize(18)
                  .fontColor([AISettingsUiTokens.accent])
              }
            }
            .width('100%')
            .padding(16)
            .onClick(() => {
              this.toggleTask(t.code);
            })
          }
        }, (t: LocalSmallTask) => t.code)
      }
      .layoutWeight(1)
      Button(L10n.getString($r('app.string.common_done'), '完成'))
        .margin(16)
        .onClick(() => {
          this.showTaskPicker = false;
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }

  build() {
    Column() {
      // 对标截图：取消 / 保存 胶囊按钮
      Row() {
        this.pillBtn(L10n.getString($r('app.string.common_cancel'), '取消'), false, () => {
          this.doBack();
        })
        Blank()
        this.pillBtn(L10n.getString($r('app.string.common_save'), '保存'), true, () => {
          this.save();
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      Text(L10n.getString($r('app.string.ai_settings_models_edit_nav_title'), '编辑模型'))
        .fontSize(AISettingsUiTokens.titleLarge)
        .fontWeight(FontWeight.Bold)
        .fontColor(AISettingsUiTokens.textPrimary)
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
        .opacity(this.tick >= 0 ? 1 : 1)

      Scroll() {
        Column() {
          if (!this.model()) {
            Text('模型不存在')
              .padding(16)
              .fontColor(AISettingsUiTokens.textSecondary)
          } else {
            this.sectionLabel(L10n.getString($r('app.string.common_name'), '名称'))
            TextInput({
              text: this.displayName,
              placeholder: L10n.getString(
                $r('app.string.ai_settings_models_online_field_display_name'),
                '显示名称'
              )
            })
              .height(44)
              .padding({ left: 16, right: 16 })
              .backgroundColor(AISettingsUiTokens.cardBackground)
              .borderRadius(22)
              .onChange((v: string) => {
                this.displayName = v;
              })

            this.sectionLabel(L10n.getString($r('app.string.ai_settings_models_edit_section_icon'), '图标'))
            Column() {
              SymbolGlyph($r('sys.symbol.star_fill'))
                .fontSize(48)
                .fontColor([AISettingsUiTokens.accent])
              Text(this.iconSymbol)
                .fontSize(12)
                .fontColor(AISettingsUiTokens.textSecondary)
                .margin({ top: 8 })
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .alignItems(HorizontalAlign.Center)
            .onClick(() => {
              this.showIconPicker = true;
            })

            if (this.canEditCapabilities()) {
              this.sectionLabel(
                L10n.getString($r('app.string.ai_settings_models_online_section_usage'), '使用场景与工具')
              )
              Column() {
                this.navRow(
                  L10n.getString($r('app.string.ai_settings_models_online_field_scenarios'), '使用场景'),
                  `${this.scenarioBindingCount()}`,
                  true,
                  () => {
                    this.stack.pushPath({
                      name: AISettingsRoutes.SCENARIO_BINDING,
                      param: ''
                    });
                  }
                )
                this.navRow(
                  L10n.getString($r('app.string.common_tools'), '工具'),
                  this.toolsSummary(),
                  true,
                  () => {
                    this.showToolPicker = true;
                  }
                )
                this.navRow(
                  L10n.getString($r('app.string.ai_settings_models_agent_related_tasks'), '关联小任务'),
                  `${this.selectedTaskCodes.length}`,
                  false,
                  () => {
                    this.showTaskPicker = true;
                  }
                )
              }
              .width('100%')
              .backgroundColor(AISettingsUiTokens.cardBackground)
              .borderRadius(14)
              .clip(true)

              this.sectionLabel(
                L10n.getString($r('app.string.ai_settings_models_edit_section_capabilities'), '能力')
              )
              Column() {
                this.capabilityToggle(
                  L10n.getString($r('app.string.ai_settings_models_online_toggle_supports_text'), '支持文本'),
                  this.supportsText,
                  true,
                  (v: boolean) => {
                    this.supportsText = v;
                  }
                )
                this.capabilityToggle(
                  L10n.getString($r('app.string.ai_settings_field_supports_multimodal'), '支持多模态'),
                  this.supportsMultimodal,
                  true,
                  (v: boolean) => {
                    this.supportsMultimodal = v;
                  }
                )
                this.capabilityToggle(
                  L10n.getString($r('app.string.ai_settings_field_supports_reasoning'), '支持推理'),
                  this.supportsReasoning,
                  true,
                  (v: boolean) => {
                    this.supportsReasoning = v;
                  }
                )
                this.capabilityToggle(
                  L10n.getString($r('app.string.ai_settings_field_reasoning_controllable'), '思考可控'),
                  this.reasoningControllable,
                  true,
                  (v: boolean) => {
                    this.reasoningControllable = v;
                  }
                )
                this.capabilityToggle(
                  L10n.getString($r('app.string.ai_settings_field_supports_tool_use'), '支持工具调用'),
                  this.supportsToolUse,
                  true,
                  (v: boolean) => {
                    this.supportsToolUse = v;
                  }
                )
                this.capabilityToggle(
                  L10n.getString($r('app.string.ai_settings_models_online_toggle_image_gen'), '生图'),
                  this.supportsImageGen,
                  false,
                  (v: boolean) => {
                    this.supportsImageGen = v;
                  }
                )
              }
              .width('100%')
              .backgroundColor(AISettingsUiTokens.cardBackground)
              .borderRadius(14)
              .clip(true)
            }

            Blank().height(40)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
    .bindSheet($$this.showIconPicker, this.iconPickerSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: true
    })
    .bindSheet($$this.showToolPicker, this.toolPickerSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: true
    })
    .bindSheet($$this.showTaskPicker, this.taskPickerSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: true
    })
  }
}

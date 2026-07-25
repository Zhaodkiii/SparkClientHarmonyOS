import { promptAction } from '@kit.ArkUI';
import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { LocalProvider, ModelCapabilities } from '../../../../../Core/AI/Domain/AIConfigModels';
import { AIProviderDisplayNameResolver } from '../../../../../Core/AI/Presentation/AIProviderDisplayNameResolver';
import { isLocalProviderId } from '../../../../../Core/AI/Domain/AILocalProviderIds';
import {
  AddOnlineModelDraft,
  emptyProbeItems,
  ModelCapabilityProbeProgressItem,
  ModelCapabilityProbeStatus,
  ModelCapabilityProbeStep,
  priceTierColor,
  priceTierLabel
} from '../../Application/AddOnlineModelModels';
import {
  ClientModelCapabilityProbeService,
  replaceProbeItem
} from '../../Application/ClientModelCapabilityProbeService';
import { FormInputRow, FormMenuRow, FormToggleRow } from '../components/FormRowBuilders';
import { ModelCapabilityProbeSheet } from './ModelCapabilityProbeSheet';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { L10n } from '../../../../../Foundation/L10n/L10n';

/**
 * 通用「添加在线模型」表单（对标 iOS AddOnlineModelSheet）。
 * 可作 bindSheet 内容，也可嵌在 AddOnlineModelPage 全页使用。
 */
@Component
export struct AddOnlineModelSheet {
  /** 锁定厂商（从厂商管理页传入）；为空则可切换 */
  initialProviderId: string = '';
  /** 预填草稿（远端「添加」预填） */
  initialDraft?: AddOnlineModelDraft;
  onClose: () => void = () => {
  };
  onSaved: () => void = () => {
  };
  /** 全页模式：左侧显示返回语义「取消」；半模态同样用取消 */
  showAsPage: boolean = false;

  @State private name: string = '';
  @State private displayName: string = '';
  @State private priceTier: number = 2;
  @State private isHidden: boolean = false;
  @State private supportsText: boolean = true;
  @State private supportsMultimodal: boolean = false;
  @State private supportsReasoning: boolean = false;
  @State private reasoningControllable: boolean = false;
  @State private supportsToolUse: boolean = false;
  @State private supportsImageGen: boolean = false;
  @State private selectedProviderID: string = '';
  @State private hasAppliedInitialDraft: boolean = false;
  @State private saving: boolean = false;
  @State private showProbeSheet: boolean = false;
  @State private isProbing: boolean = false;
  @State private probeItems: ModelCapabilityProbeProgressItem[] = emptyProbeItems();
  @State private tick: number = 0;
  private vm?: AISettingsViewModel;
  private probeService: ClientModelCapabilityProbeService = new ClientModelCapabilityProbeService();

  aboutToAppear(): void {
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
    this.applyInitialDraftIfNeeded();
    this.ensureSelectedProvider();
  }

  private apiKeyRows(): LocalProvider[] {
    const list = this.vm?.localCredentialProviders() ?? [];
    const out: LocalProvider[] = [];
    for (let i = 0; i < list.length; i++) {
      const p = list[i];
      if (p.kind === 'local' || isLocalProviderId(p.id)) {
        continue;
      }
      out.push(p);
    }
    return out;
  }

  private selectedProvider(): LocalProvider | undefined {
    const rows = this.apiKeyRows();
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].id === this.selectedProviderID) {
        return rows[i];
      }
    }
    return undefined;
  }

  private selectedProviderDisplayName(): string {
    const p = this.selectedProvider();
    if (!p) {
      return L10n.getString($r('app.string.ai_settings_models_online_field_vendor'), '厂商');
    }
    return AIProviderDisplayNameResolver.display(p);
  }

  private isCompanyLocked(): boolean {
    if (this.initialProviderId.trim().length === 0) {
      return false;
    }
    const rows = this.apiKeyRows();
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].id === this.initialProviderId) {
        return true;
      }
    }
    return false;
  }

  private applyInitialDraftIfNeeded(): void {
    if (this.hasAppliedInitialDraft) {
      return;
    }
    this.hasAppliedInitialDraft = true;
    const draft = this.initialDraft;
    if (draft) {
      this.name = draft.name;
      this.displayName = draft.displayName.length > 0 ? draft.displayName : draft.name;
      this.selectedProviderID = draft.providerID;
      this.priceTier = Math.min(Math.max(draft.priceTier, 0), 3);
      this.isHidden = draft.isHidden;
      this.supportsText = draft.supportsText;
      this.supportsMultimodal = draft.supportsMultimodal;
      this.supportsReasoning = draft.supportsReasoning;
      this.reasoningControllable = draft.reasoningControllable;
      this.supportsToolUse = draft.supportsToolUse;
      this.supportsImageGen = draft.supportsImageGen;
      return;
    }
    if (this.initialProviderId.length > 0) {
      this.selectedProviderID = this.initialProviderId;
    }
  }

  private ensureSelectedProvider(): void {
    if (this.selectedProviderID.length > 0) {
      const found = this.selectedProvider();
      if (found) {
        return;
      }
    }
    if (this.initialProviderId.length > 0) {
      this.selectedProviderID = this.initialProviderId;
      return;
    }
    const rows = this.apiKeyRows();
    if (rows.length > 0) {
      this.selectedProviderID = rows[0].id;
    }
  }

  private vendorSelectOptions(): SelectOption[] {
    const rows = this.apiKeyRows();
    const opts: SelectOption[] = [];
    for (let i = 0; i < rows.length; i++) {
      opts.push({ value: AIProviderDisplayNameResolver.display(rows[i]) });
    }
    return opts;
  }

  private priceSelectOptions(): SelectOption[] {
    return [
      { value: priceTierLabel(0) },
      { value: priceTierLabel(1) },
      { value: priceTierLabel(2) },
      { value: priceTierLabel(3) }
    ];
  }

  private showAlert(message: string): void {
    promptAction.showDialog({
      title: L10n.getString($r('app.string.ai_settings_models_online_error_title'), '无法添加'),
      message: message,
      buttons: [
        {
          text: L10n.getString($r('app.string.common_action_confirm'), '确定'),
          color: AISettingsUiTokens.accent
        }
      ]
    }).catch(() => {
    });
  }

  private canProbe(): boolean {
    return !this.isProbing &&
      this.name.trim().length > 0 &&
      this.selectedProvider() !== undefined;
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    const n = this.name.trim();
    const d = this.displayName.trim();
    const provider = this.selectedProvider();
    if (n.length === 0) {
      this.showAlert(L10n.getString($r('app.string.ai_settings_models_online_err_api_name'), '请填写 API 模型名'));
      return;
    }
    if (d.length === 0) {
      this.showAlert(L10n.getString($r('app.string.ai_settings_models_online_err_display_name'), '请填写显示名称'));
      return;
    }
    if (!provider) {
      this.showAlert(L10n.getString($r('app.string.ai_settings_models_online_err_vendor'), '请选择已配置密钥的厂商'));
      return;
    }
    this.saving = true;
    try {
      const caps = new ModelCapabilities();
      caps.supportsText = this.supportsText;
      caps.supportsMultimodal = this.supportsMultimodal;
      caps.supportsReasoning = this.supportsReasoning;
      caps.reasoningControllable = this.reasoningControllable;
      caps.supportsToolUse = this.supportsToolUse;
      caps.supportsImageGen = this.supportsImageGen;
      const ok = await this.vm?.addOnlineModelAndPersistFull(
        provider.id,
        n,
        d,
        caps,
        this.priceTier,
        this.isHidden
      );
      if (ok) {
        this.onSaved();
        this.onClose();
      } else {
        const msg = this.vm?.errorMessage ?? '';
        this.showAlert(msg.length > 0 ? msg : '添加失败');
      }
    } finally {
      this.saving = false;
    }
  }

  private async startProbe(): Promise<void> {
    const provider = this.selectedProvider();
    if (!provider) {
      this.showAlert(L10n.getString($r('app.string.ai_settings_models_online_err_vendor'), '请选择已配置密钥的厂商'));
      return;
    }
    const modelName = this.name.trim();
    if (modelName.length === 0) {
      this.showAlert(L10n.getString($r('app.string.ai_settings_models_online_err_api_name'), '请填写 API 模型名'));
      return;
    }
    const endpoint = (provider.requestUrl ?? '').trim();
    if (endpoint.length === 0) {
      this.showAlert('请先配置厂商请求地址');
      return;
    }
    const apiKey = await this.vm?.resolveProviderApiKey(provider.id) ?? '';
    if (apiKey.length === 0) {
      this.showAlert(L10n.getString($r('app.string.ai_settings_providers_editor_alert_need_api_key'), '请先配置有效 API Key'));
      return;
    }

    this.probeItems = emptyProbeItems();
    this.isProbing = true;
    this.showProbeSheet = true;
    try {
      const summary = await this.probeService.probe(
        modelName,
        endpoint,
        apiKey,
        (step: ModelCapabilityProbeStep, status: ModelCapabilityProbeStatus, message: string) => {
          this.probeItems = replaceProbeItem(this.probeItems, step, status, message);
        }
      );
      this.supportsText = summary.supportsText;
      this.supportsMultimodal = summary.supportsMultimodal;
      this.supportsReasoning = summary.supportsReasoning;
      this.reasoningControllable = summary.reasoningControllable;
      this.supportsToolUse = summary.supportsToolUse;
      this.supportsImageGen = summary.supportsImageGen;
      this.tick++;
    } catch (err) {
      const msg = err instanceof Error ? err.message : `${err}`;
      this.showAlert(msg.length > 0 ? msg : '探测失败');
    } finally {
      this.isProbing = false;
    }
  }

  @Builder
  private probeSheetBuilder() {
    ModelCapabilityProbeSheet({ items: this.probeItems })
  }

  @Builder
  private navigationBar() {
    Row() {
      Text(L10n.getString($r('app.string.common_cancel'), '取消'))
        .fontSize(16)
        .fontColor(AISettingsUiTokens.textSecondary)
        .padding({ left: 4, right: 12, top: 10, bottom: 10 })
        .onClick(() => {
          this.onClose();
        })

      Blank()

      // 对标截图：浅灰圆角底 + 深色字，避免系统 Button 蓝底蓝字
      Text(L10n.getString($r('app.string.ai_settings_models_online_save'), '添加'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.saving ? AISettingsUiTokens.textSecondary : AISettingsUiTokens.textPrimary)
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .backgroundColor('#E5E5EA')
        .borderRadius(8)
        .opacity(this.saving ? 0.5 : 1)
        .onClick(() => {
          if (!this.saving) {
            this.save();
          }
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
  }

  @Builder
  private basicSection() {
    Text(L10n.getString($r('app.string.ai_settings_models_online_section_basic'), '基本信息'))
      .fontSize(13)
      .fontColor(AISettingsUiTokens.textSecondary)
      .width('100%')
      .padding({ left: 4, bottom: 6 })

    Column() {
      FormInputRow({
        iconSymbol: $r('sys.symbol.doc_text'),
        title: L10n.getString($r('app.string.ai_settings_models_online_field_api_name'), 'API 模型名'),
        prompt: L10n.getString($r('app.string.ai_settings_models_online_field_api_name_prompt'), '例如 gpt-4o-mini'),
        text: this.name,
        onTextChange: (v: string) => {
          this.name = v;
        }
      })
      Divider().color(AISettingsUiTokens.divider).margin({ left: 48 })

      FormInputRow({
        iconSymbol: $r('sys.symbol.doc_text'),
        title: L10n.getString($r('app.string.ai_settings_models_online_field_display_name'), '显示名称'),
        prompt: L10n.getString($r('app.string.ai_settings_models_online_field_display_name_prompt'), '用于列表展示的名称'),
        text: this.displayName,
        onTextChange: (v: string) => {
          this.displayName = v;
        }
      })
      Divider().color(AISettingsUiTokens.divider).margin({ left: 48 })

      FormMenuRow({
        iconSymbol: $r('sys.symbol.key'),
        title: L10n.getString($r('app.string.ai_settings_models_online_field_vendor'), '厂商'),
        trailing: () => {
          this.vendorTrailing()
        }
      })
    }
    .width('100%')
    .backgroundColor(AISettingsUiTokens.cardBackground)
    .borderRadius(12)
    .clip(true)
  }

  @Builder
  private vendorTrailing() {
    if (this.isCompanyLocked()) {
      Text(this.selectedProviderDisplayName())
        .fontSize(15)
        .fontColor(AISettingsUiTokens.textPrimary)
    } else {
      Select(this.vendorSelectOptions())
        .selected(this.selectedVendorIndex())
        .value(this.selectedProviderDisplayName())
        .font({ size: 15 })
        .fontColor(AISettingsUiTokens.textPrimary)
        .selectedOptionFont({ size: 15 })
        .optionFont({ size: 15 })
        .onSelect((index: number) => {
          const rows = this.apiKeyRows();
          if (index >= 0 && index < rows.length) {
            this.selectedProviderID = rows[index].id;
          }
        })
    }
  }

  private selectedVendorIndex(): number {
    const rows = this.apiKeyRows();
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].id === this.selectedProviderID) {
        return i;
      }
    }
    return 0;
  }

  @Builder
  private priceSection() {
    Text(L10n.getString($r('app.string.ai_settings_models_online_section_price'), '价格'))
      .fontSize(13)
      .fontColor(AISettingsUiTokens.textSecondary)
      .width('100%')
      .padding({ left: 4, bottom: 6, top: 16 })

    Column() {
      FormMenuRow({
        iconSymbol: $r('sys.symbol.key'),
        title: L10n.getString($r('app.string.ai_settings_field_price_tier'), '价格档位'),
        trailing: () => {
          this.priceTrailing()
        }
      })
    }
    .width('100%')
    .backgroundColor(AISettingsUiTokens.cardBackground)
    .borderRadius(12)
    .clip(true)
  }

  @Builder
  private priceTrailing() {
    Row({ space: 6 }) {
      Circle({ width: 8, height: 8 }).fill(priceTierColor(this.priceTier))
      Text(priceTierLabel(this.priceTier))
        .fontSize(14)
        .fontColor(priceTierColor(this.priceTier))
      Select(this.priceSelectOptions())
        .selected(this.priceTier)
        .value(priceTierLabel(this.priceTier))
        .font({ size: 14 })
        .onSelect((index: number) => {
          this.priceTier = Math.min(Math.max(index, 0), 3);
        })
    }
  }

  @Builder
  private capabilitiesSection() {
    Text(L10n.getString($r('app.string.ai_settings_models_online_section_capabilities'), '能力'))
      .fontSize(13)
      .fontColor(AISettingsUiTokens.textSecondary)
      .width('100%')
      .padding({ left: 4, bottom: 6, top: 16 })

    Column() {
      FormToggleRow({
        iconSymbol: $r('sys.symbol.checkmark_circle_fill'),
        title: L10n.getString($r('app.string.ai_settings_models_online_toggle_default_hidden'), '默认隐藏'),
        isOn: this.isHidden,
        onToggleChange: (v: boolean) => {
          this.isHidden = v;
        }
      })
      Divider().color(AISettingsUiTokens.divider).margin({ left: 48 })

      this.probeActionRow()
      Text(L10n.getString(
        $r('app.string.ai_settings_models_online_probe_cost_note'),
        '注意：自动模型能力探测可能产生一定 API 费用。'
      ))
        .fontSize(12)
        .fontColor(AISettingsUiTokens.textSecondary)
        .padding({ left: 48, right: 16, top: 2, bottom: 8 })
        .width('100%')

      FormToggleRow({
        iconSymbol: $r('sys.symbol.doc_text'),
        title: L10n.getString($r('app.string.ai_settings_models_online_toggle_supports_text'), '支持文本'),
        isOn: this.supportsText,
        onToggleChange: (v: boolean) => {
          this.supportsText = v;
        }
      })
      Divider().color(AISettingsUiTokens.divider).margin({ left: 48 })
      FormToggleRow({
        iconSymbol: $r('sys.symbol.square_stack_3d'),
        title: L10n.getString($r('app.string.ai_settings_field_supports_multimodal'), '支持多模态'),
        isOn: this.supportsMultimodal,
        onToggleChange: (v: boolean) => {
          this.supportsMultimodal = v;
        }
      })
      Divider().color(AISettingsUiTokens.divider).margin({ left: 48 })
      FormToggleRow({
        iconSymbol: $r('sys.symbol.star'),
        title: L10n.getString($r('app.string.ai_settings_field_supports_reasoning'), '支持推理'),
        isOn: this.supportsReasoning,
        onToggleChange: (v: boolean) => {
          this.supportsReasoning = v;
        }
      })
      Divider().color(AISettingsUiTokens.divider).margin({ left: 48 })
      FormToggleRow({
        iconSymbol: $r('sys.symbol.star'),
        title: L10n.getString($r('app.string.ai_settings_field_reasoning_controllable'), '思考可控'),
        isOn: this.reasoningControllable,
        onToggleChange: (v: boolean) => {
          this.reasoningControllable = v;
        }
      })
      Divider().color(AISettingsUiTokens.divider).margin({ left: 48 })
      FormToggleRow({
        iconSymbol: $r('sys.symbol.square_stack_3d'),
        title: L10n.getString($r('app.string.ai_settings_field_supports_tool_use'), '支持工具调用'),
        isOn: this.supportsToolUse,
        onToggleChange: (v: boolean) => {
          this.supportsToolUse = v;
        }
      })
      Divider().color(AISettingsUiTokens.divider).margin({ left: 48 })
      FormToggleRow({
        iconSymbol: $r('sys.symbol.star_fill'),
        title: L10n.getString($r('app.string.ai_settings_models_online_toggle_image_gen'), '生图'),
        isOn: this.supportsImageGen,
        onToggleChange: (v: boolean) => {
          this.supportsImageGen = v;
        }
      })

      Text(L10n.getString(
        $r('app.string.ai_settings_models_online_capabilities_footer'),
        '部分能力将影响该模型在场景中的可选性。'
      ))
        .fontSize(12)
        .fontColor(AISettingsUiTokens.textSecondary)
        .padding({ left: 16, right: 16, top: 8, bottom: 12 })
        .width('100%')
    }
    .width('100%')
    .backgroundColor(AISettingsUiTokens.cardBackground)
    .borderRadius(12)
    .clip(true)
  }

  @Builder
  private probeActionRow() {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.star'))
        .fontSize(18)
        .fontColor([AISettingsUiTokens.accent])
      Text(L10n.getString($r('app.string.ai_settings_models_online_probe_button'), '自动模型能力探测'))
        .fontSize(16)
        .fontColor(AISettingsUiTokens.textPrimary)
        .layoutWeight(1)
      if (this.isProbing) {
        LoadingProgress().width(18).height(18)
      } else {
        Text('›')
          .fontSize(20)
          .fontColor(AISettingsUiTokens.textSecondary)
      }
    }
    .width('100%')
    .padding({ top: 10, bottom: 10, left: 16, right: 16 })
    .opacity(this.canProbe() ? 1 : 0.45)
    .onClick(() => {
      if (this.canProbe()) {
        this.startProbe();
      }
    })
  }

  build() {
    Column() {
      this.navigationBar()

      Text(L10n.getString($r('app.string.ai_settings_models_online_nav_title'), '添加在线模型'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AISettingsUiTokens.textPrimary)
        .width('100%')
        .padding({ left: 20, right: 20, top: 4, bottom: 12 })

      Scroll() {
        Column() {
          this.basicSection()
          this.priceSection()
          this.capabilitiesSection()
          Blank().height(32)
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
    .bindSheet($$this.showProbeSheet, this.probeSheetBuilder(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      // 探测结果 sheet 无自定义顶栏，保留系统关闭；主添加页已用 showClose:false
      showClose: true,
      onDisappear: () => {
        this.showProbeSheet = false;
      }
    })
  }
}

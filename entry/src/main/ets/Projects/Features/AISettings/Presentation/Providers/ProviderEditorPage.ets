import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { AISettingsRoutes } from '../AISettingsRoutes';
import { LocalModel, LocalProvider } from '../../../../../Core/AI/Domain/AIConfigModels';
import { ProviderModelCatalogService } from '../../Application/ProviderModelCatalogService';
import { ProviderPrivacyUrlResolver } from '../../Application/ProviderPrivacyUrlResolver';
import { AIProviderDisplayNameResolver } from '../../../../../Core/AI/Presentation/AIProviderDisplayNameResolver';
import { isLocalProviderId } from '../../../../../Core/AI/Domain/AILocalProviderIds';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { L10n } from '../../../../../Foundation/L10n/L10n';
import { ProviderTestResult } from '../../../../Core/Networking/API/AI/AIConfigAPI';
import { ProviderModelManagementPage } from './ProviderModelManagementPage';
import { ProviderPrivacyPolicyPage } from './ProviderPrivacyPolicyPage';
import { EditModelPage } from '../Models/EditModelPage';

/** 厂商编辑页半模态：对标 iOS presentedSheet */
enum ProviderEditorSheetKind {
  NONE = 0,
  MANAGE_MODELS = 1,
  PRIVACY_POLICY = 2,
  EDIT_MODEL = 3
}

/**
 * 厂商密钥编辑页：对标 iOS ProviderSettingsEditorView。
 * 密钥明文仅存 ViewModel pending 映射，确认保存后进 HUKS；不引入 mock APIKeys 模型。
 */
@Component
export struct ProviderEditorPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  providerId: string = '';
  @State private tick: number = 0;
  @State private urlDraft: string = '';
  @State private keyDraft: string = '';
  @State private selectedModel: string = '';
  @State private privacyUrl: string = '';
  @State private privacyAccepted: boolean = true;
  @State private isTesting: boolean = false;
  @State private testPassed: boolean | undefined = undefined;
  @State private testErrorMessage: string = '';
  @State private saving: boolean = false;
  /** 对标 iOS presentedSheet；用枚举 + 布尔 isShow 驱动 bindSheet */
  @State private presentedSheet: ProviderEditorSheetKind = ProviderEditorSheetKind.NONE;
  @State private showEditorSheet: boolean = false;
  @State private editModelId: string = '';
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
    this.vm?.setOnChanged(() => {
      this.tick++;
      this.syncSelectedTestModel();
    });
    const p = this.provider();
    this.urlDraft = p?.requestUrl ?? '';
    this.selectedModel = this.vm?.testModelByProvider.get(this.providerId) ?? '';
    this.syncSelectedTestModel();
    this.loadPrivacyUrl();
  }

  private async loadPrivacyUrl(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      await ProviderPrivacyUrlResolver.ensureLoaded(ctx);
      const company = this.provider()?.company ?? '';
      this.privacyUrl = ProviderPrivacyUrlResolver.urlForCompany(company);
      // 对标 iOS：有政策且从未记录同意时间时默认勾选
      if (this.privacyUrl.length > 0) {
        this.privacyAccepted = true;
      }
    } catch (_e) {
      this.privacyUrl = '';
    }
  }

  private provider(): LocalProvider | undefined {
    const list = this.vm?.draftSnapshot?.providers ?? [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === this.providerId) {
        return list[i];
      }
    }
    return undefined;
  }

  private isLocalBlocked(): boolean {
    const p = this.provider();
    if (!p) {
      return false;
    }
    return p.kind === 'local' || isLocalProviderId(p.id) ||
      !ProviderModelCatalogService.isEditableApiCredentialProvider(p);
  }

  private displayTitle(): string {
    const p = this.provider();
    if (!p) {
      return '';
    }
    return AIProviderDisplayNameResolver.display(p);
  }

  /** 该厂商下 identity=model 的目录行（对标 iOS providerModels） */
  private providerModels(): LocalModel[] {
    if (!this.vm?.draftSnapshot) {
      return [];
    }
    const all = ProviderModelCatalogService.modelsForProvider(this.vm.draftSnapshot, this.providerId);
    const out: LocalModel[] = [];
    for (let i = 0; i < all.length; i++) {
      if (all[i].identity === 'model') {
        out.push(all[i]);
      }
    }
    return out;
  }

  private testableModels(): LocalModel[] {
    if (!this.vm?.draftSnapshot) {
      return [];
    }
    return ProviderModelCatalogService.enabledTextModels(this.vm.draftSnapshot, this.providerId);
  }

  private resolvedTestModelName(): string {
    const list = this.testableModels();
    for (let i = 0; i < list.length; i++) {
      if (list[i].name === this.selectedModel) {
        return this.selectedModel;
      }
    }
    return list.length > 0 ? list[0].name : '';
  }

  private syncSelectedTestModel(): void {
    const name = this.resolvedTestModelName();
    if (this.selectedModel !== name) {
      this.selectedModel = name;
      if (name.length > 0) {
        this.vm?.setTestModel(this.providerId, name);
      }
    }
  }

  private canSave(): boolean {
    if (this.privacyUrl.length > 0 && !this.privacyAccepted) {
      return false;
    }
    return !this.saving;
  }

  private showNotice(message: string): void {
    promptAction.showDialog({
      title: L10n.getString(
        $r('app.string.ai_settings_providers_editor_alert_notice_title'),
        '提示'
      ),
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

  private doBack(): void {
    if (this.onBack) {
      this.onBack();
    } else {
      this.stack.pop();
    }
  }

  private openSheet(kind: ProviderEditorSheetKind): void {
    this.presentedSheet = kind;
    this.showEditorSheet = kind !== ProviderEditorSheetKind.NONE;
  }

  private closeSheet(): void {
    this.showEditorSheet = false;
    // presentedSheet 保留至下次 openSheet，避免关闭动画中 builder 闪空
  }

  @Builder
  private editorSheetBuilder() {
    if (this.presentedSheet === ProviderEditorSheetKind.MANAGE_MODELS) {
      ProviderModelManagementPage({
        providerId: this.providerId,
        requestUrlDraft: this.urlDraft,
        onClose: () => {
          this.closeSheet();
        }
      })
    } else if (this.presentedSheet === ProviderEditorSheetKind.PRIVACY_POLICY) {
      ProviderPrivacyPolicyPage({
        url: this.privacyUrl,
        onBack: () => {
          this.closeSheet();
        }
      })
    } else if (this.presentedSheet === ProviderEditorSheetKind.EDIT_MODEL) {
      EditModelPage({
        stack: this.stack,
        modelId: this.editModelId,
        onBack: () => {
          this.closeSheet();
          this.tick++;
        }
      })
    }
  }

  private async onToggleEnabled(enabled: boolean): Promise<void> {
    const ok = await this.vm?.setProviderEnabledFromEditorAndPersist(this.providerId, enabled);
    this.tick++;
    if (!ok) {
      const msg = this.vm?.errorMessage ?? '';
      if (msg.length > 0) {
        this.showNotice(msg);
      } else {
        this.showNotice(L10n.getString(
          $r('app.string.ai_settings_providers_editor_alert_need_api_key'),
          '请先配置有效 API Key'
        ));
      }
    }
  }

  private async onSave(): Promise<void> {
    if (!this.canSave()) {
      return;
    }
    const p = this.provider();
    if (p && p.isEnabled) {
      const pending = this.keyDraft.trim();
      const configured = this.vm?.isKeyConfigured(this.providerId) === true;
      if (pending.length === 0 && !configured) {
        this.showNotice(L10n.getString(
          $r('app.string.ai_settings_providers_editor_alert_need_api_key'),
          '请先配置有效 API Key'
        ));
        return;
      }
    }
    this.saving = true;
    try {
      if (this.keyDraft.trim().length > 0) {
        this.vm?.setPendingProviderKey(this.providerId, this.keyDraft.trim());
      }
      const ok = await this.vm?.saveProviderFromEditorAndPersist(this.providerId, this.urlDraft);
      if (ok) {
        this.keyDraft = '';
        this.doBack();
      } else if ((this.vm?.errorMessage ?? '').length > 0) {
        this.showNotice(this.vm?.errorMessage ?? '');
      }
    } finally {
      this.saving = false;
      this.tick++;
    }
  }

  private async onDeleteModel(modelId: string): Promise<void> {
    const ok = await this.vm?.deleteModelAndPersist(modelId);
    this.tick++;
    this.syncSelectedTestModel();
    if (!ok && (this.vm?.errorMessage ?? '').length > 0) {
      this.showNotice(this.vm?.errorMessage ?? '');
    }
  }

  private backendFailureMessage(raw?: string): string {
    const trimmed = (raw ?? '').trim();
    if (trimmed.length === 0) {
      return L10n.getString(
        $r('app.string.ai_settings_providers_editor_alert_test_failed'),
        '连接测试失败，请检查 URL 或密钥'
      );
    }
    if (trimmed.toLowerCase() === 'network_error') {
      return L10n.getString(
        $r('app.string.ai_settings_providers_editor_alert_backend_network_error'),
        '服务端连通性测试网络不可达。若仍失败，请检查网络、请求地址和模型名。'
      );
    }
    return trimmed;
  }

  private async onTestProvider(): Promise<void> {
    const pending = this.keyDraft.trim();
    const configured = this.vm?.isKeyConfigured(this.providerId) === true;
    if (pending.length === 0 && !configured) {
      this.testPassed = false;
      this.showNotice(L10n.getString(
        $r('app.string.ai_settings_providers_editor_alert_need_api_key'),
        '请先配置有效 API Key'
      ));
      return;
    }
    const modelName = this.resolvedTestModelName();
    if (modelName.length === 0) {
      const msg = L10n.getString(
        $r('app.string.ai_settings_providers_editor_alert_no_models'),
        '当前厂商无可测试模型，请先配置模型'
      );
      this.testPassed = false;
      this.testErrorMessage = msg;
      this.showNotice(msg);
      return;
    }
    if (pending.length > 0) {
      this.vm?.setPendingProviderKey(this.providerId, pending);
    }
    this.isTesting = true;
    this.testErrorMessage = '';
    this.testPassed = undefined;
    try {
      const result: ProviderTestResult | undefined =
        await this.vm?.testProviderConnectionFromEditor(this.providerId, this.urlDraft, modelName);
      if (result?.isReachable) {
        this.testPassed = true;
        this.testErrorMessage = '';
        return;
      }
      const msg = this.backendFailureMessage(result?.message);
      this.testPassed = false;
      this.testErrorMessage = msg;
      this.showNotice(msg);
    } finally {
      this.isTesting = false;
      this.tick++;
    }
  }

  @Builder
  private basicSection() {
    Column() {
      Row() {
        Column() {
          Text(this.displayTitle())
            .fontSize(AISettingsUiTokens.titleRow)
            .fontWeight(FontWeight.Medium)
            .fontColor(AISettingsUiTokens.textPrimary)
            .width('100%')
          Text(AIProviderDisplayNameResolver.sourceLabel(this.provider()!))
            .fontSize(12)
            .fontColor(AISettingsUiTokens.textSecondary)
            .margin({ top: 4 })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Toggle({ type: ToggleType.Switch, isOn: this.provider()?.isEnabled === true })
          .selectedColor(AISettingsUiTokens.accent)
          .onChange((isOn: boolean) => {
            this.onToggleEnabled(isOn);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text($r('app.string.ai_settings_provider_url'))
        .fontSize(13)
        .margin({ top: 16 })
        .fontColor(AISettingsUiTokens.textSecondary)
        .width('100%')
      TextInput({
        text: this.urlDraft,
        placeholder: L10n.getString($r('app.string.ai_settings_providers_editor_field_request_url'), '请求地址')
      })
        .margin({ top: 6 })
        .onChange((v: string) => {
          this.urlDraft = v;
        })

      Text($r('app.string.ai_settings_provider_key'))
        .fontSize(13)
        .margin({ top: 16 })
        .fontColor(AISettingsUiTokens.textSecondary)
        .width('100%')
      Text(this.vm?.isKeyConfigured(this.providerId) ? '已配置（密文存储）' : '未配置')
        .fontSize(12)
        .fontColor(AISettingsUiTokens.textSecondary)
        .margin({ top: 4 })
        .width('100%')
      TextInput({
        text: this.keyDraft,
        placeholder: L10n.getString(
          $r('app.string.ai_settings_providers_editor_key_placeholder'),
          '输入新 Key（不回显）'
        )
      })
        .type(InputType.Password)
        .margin({ top: 6 })
        .onChange((v: string) => {
          this.keyDraft = v;
          this.vm?.setPendingProviderKey(this.providerId, v);
        })

      if (this.privacyUrl.length > 0) {
        Row() {
          Text($r('app.string.ai_settings_providers_editor_privacy_view_policy'))
            .fontSize(13)
            .fontColor(AISettingsUiTokens.accent)
            .onClick(() => {
              this.openSheet(ProviderEditorSheetKind.PRIVACY_POLICY);
            })
          Blank()
          Toggle({ type: ToggleType.Checkbox, isOn: this.privacyAccepted })
            .selectedColor(AISettingsUiTokens.accent)
            .onChange((isOn: boolean) => {
              this.privacyAccepted = isOn;
            })
          Text($r('app.string.ai_settings_providers_editor_privacy_accept'))
            .fontSize(12)
            .fontColor(AISettingsUiTokens.textSecondary)
            .margin({ left: 6 })
            .maxLines(2)
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 16 })
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AISettingsUiTokens.cardBackground)
    .borderRadius(AISettingsUiTokens.cardRadius)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private modelsSection() {
    Row() {
      Text($r('app.string.ai_settings_providers_editor_section_models'))
        .fontSize(AISettingsUiTokens.titleSection)
        .fontColor(AISettingsUiTokens.textSecondary)
      Blank()
      // Text 避免系统 Button 主题底色与 accent 字色撞色
      Text('+')
        .fontSize(24)
        .fontColor(AISettingsUiTokens.accent)
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          // 对标 iOS：presentedSheet = .manageModels
          this.openSheet(ProviderEditorSheetKind.MANAGE_MODELS);
        })
    }
    .width('100%')
    .margin({ top: 20, bottom: 8, left: 4, right: 4 })

    Column() {
      if (this.providerModels().length === 0) {
        Text($r('app.string.ai_settings_providers_editor_models_empty'))
          .fontSize(13)
          .fontColor(AISettingsUiTokens.textSecondary)
          .padding(16)
          .width('100%')
      } else {
        ForEach(this.providerModels(), (m: LocalModel) => {
          Row() {
            Column() {
              Text(m.displayName || m.name)
                .fontSize(15)
                .fontColor(AISettingsUiTokens.textPrimary)
                .width('100%')
              Text(m.isEnabled ? '已启用' : '已关闭')
                .fontSize(12)
                .fontColor(AISettingsUiTokens.textSecondary)
                .margin({ top: 4 })
                .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .onClick(() => {
              this.editModelId = m.id;
              this.openSheet(ProviderEditorSheetKind.EDIT_MODEL);
            })

            Button($r('app.string.ai_settings_providers_editor_model_delete'))
              .fontSize(13)
              .fontColor(AISettingsUiTokens.error)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                this.onDeleteModel(m.id);
              })
          }
          .width('100%')
          .padding({ left: 16, right: 8, top: 10, bottom: 10 })
        }, (m: LocalModel) => `${m.id}-${this.tick}`)
      }
    }
    .width('100%')
    .backgroundColor(AISettingsUiTokens.cardBackground)
    .borderRadius(AISettingsUiTokens.cardRadius)
    .clip(true)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private testSection() {
    Text($r('app.string.ai_settings_providers_editor_section_api_test'))
      .fontSize(AISettingsUiTokens.titleSection)
      .fontColor(AISettingsUiTokens.textSecondary)
      .margin({ top: 20, bottom: 8, left: 4 })
      .width('100%')

    Column() {
      if (this.testableModels().length === 0) {
        Text($r('app.string.ai_settings_providers_editor_test_no_models'))
          .fontSize(13)
          .fontColor(AISettingsUiTokens.textSecondary)
          .padding(16)
          .width('100%')
      } else {
        Text($r('app.string.ai_settings_providers_editor_field_test_model'))
          .fontSize(13)
          .fontColor(AISettingsUiTokens.textSecondary)
          .padding({ left: 16, right: 16, top: 12 })
          .width('100%')
        ForEach(this.testableModels(), (m: LocalModel) => {
          Row() {
            Radio({ value: m.name, group: 'testModel' })
              .checked(this.selectedModel === m.name)
              .onChange((checked: boolean) => {
                if (checked) {
                  this.selectedModel = m.name;
                  this.vm?.setTestModel(this.providerId, m.name);
                }
              })
            Text(m.displayName || m.name)
              .fontSize(14)
              .margin({ left: 8 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }, (m: LocalModel) => m.id)
      }

      Row() {
        Button($r('app.string.ai_settings_providers_editor_action_test_api'))
          .enabled(!this.isTesting && this.testableModels().length > 0)
          .onClick(() => {
            this.onTestProvider();
          })
        Blank()
        if (this.isTesting) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(AISettingsUiTokens.accent)
        } else if (this.testPassed !== undefined) {
          Text(this.testPassed
            ? $r('app.string.ai_settings_providers_editor_test_passed')
            : $r('app.string.ai_settings_providers_editor_test_failed'))
            .fontSize(14)
            .fontColor(this.testPassed ? AISettingsUiTokens.success : AISettingsUiTokens.error)
        }
      }
      .width('100%')
      .padding(16)
      .alignItems(VerticalAlign.Center)

      if (this.testErrorMessage.length > 0) {
        Text(this.testErrorMessage)
          .fontSize(12)
          .fontColor(AISettingsUiTokens.warning)
          .padding({ left: 16, right: 16, bottom: 12 })
          .width('100%')
      }
    }
    .width('100%')
    .backgroundColor(AISettingsUiTokens.cardBackground)
    .borderRadius(AISettingsUiTokens.cardRadius)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      AISettingsNavHeader({
        title: $r('app.string.ai_settings_providers_editor_nav_title'),
        actionTitle: L10n.getString($r('app.string.common_save'), '保存'),
        actionEnabled: this.canSave() && !this.isLocalBlocked() && this.provider() !== undefined,
        onBack: () => {
          this.doBack();
        },
        onAction: () => {
          this.onSave();
        }
      })

      if (!this.provider()) {
        Text('Provider 不存在')
          .padding(16)
          .fontColor(AISettingsUiTokens.textSecondary)
      } else if (this.isLocalBlocked()) {
        Column() {
          Text('本地模型不在此页配置密钥')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AISettingsUiTokens.textPrimary)
            .width('100%')
          Text('请前往「本地模型」管理文件安装与启用。本地 GGUF 不需要 API Key、endpoint 或隐私政策。')
            .fontSize(14)
            .fontColor(AISettingsUiTokens.textSecondary)
            .margin({ top: 12 })
            .width('100%')
          Button($r('app.string.ai_settings_model_local'))
            .margin({ top: 20 })
            .onClick(() => {
              this.stack.pushPath({ name: AISettingsRoutes.MODEL_LOCAL });
            })
        }
        .width('100%')
        .padding(20)
        .margin({
          left: AISettingsUiTokens.pagePaddingH,
          right: AISettingsUiTokens.pagePaddingH,
          top: 8
        })
        .backgroundColor(AISettingsUiTokens.cardBackground)
        .borderRadius(AISettingsUiTokens.cardRadius)
        .alignItems(HorizontalAlign.Start)
      } else {
        Scroll() {
          Column() {
            this.basicSection()
            this.modelsSection()
            this.testSection()

            if (this.vm?.errorMessage && this.vm.errorMessage.length > 0) {
              Text(this.vm.errorMessage)
                .fontSize(12)
                .fontColor(AISettingsUiTokens.error)
                .margin({ top: 12 })
                .width('100%')
            }
            Blank().height(24)
          }
          .width('100%')
          .padding({
            left: AISettingsUiTokens.pagePaddingH,
            right: AISettingsUiTokens.pagePaddingH
          })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
    // 对标 iOS .sheet(item: $presentedSheet)
    .bindSheet($$this.showEditorSheet, this.editorSheetBuilder(), {
      height: SheetSize.LARGE,
      dragBar: true,
      // 页内已有「关闭/取消」，勿再显示系统右上角 X，避免与「添加/+」重叠
      showClose: false,
      onDisappear: () => {
        this.closeSheet();
      }
    })
  }
}

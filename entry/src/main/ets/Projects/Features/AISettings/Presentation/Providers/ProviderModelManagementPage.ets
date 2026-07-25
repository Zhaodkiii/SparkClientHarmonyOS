import { promptAction } from '@kit.ArkUI';
import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { LocalModel } from '../../../../../Core/AI/Domain/AIConfigModels';
import {
  ProviderRemoteModel,
  ProviderRemoteModelFetchService
} from '../../Application/ProviderRemoteModelFetchService';
import { AddOnlineModelDraft } from '../../Application/AddOnlineModelModels';
import { ProviderModelCatalogService } from '../../Application/ProviderModelCatalogService';
import { AISettingsErrorLocalizer } from '../../Application/AISettingsErrorLocalizer';
import { AIProviderDisplayNameResolver } from '../../../../../Core/AI/Presentation/AIProviderDisplayNameResolver';
import { AddOnlineModelSheet } from '../Models/AddOnlineModelSheet';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { L10n } from '../../../../../Foundation/L10n/L10n';

/**
 * 对标 iOS ModelManagementView / 技术方案 ProviderModelManagementPage。
 * 由 ProviderEditorPage 通过 bindSheet 弹出，传入当前 providerId。
 */
@Component
export struct ProviderModelManagementPage {
  providerId: string = '';
  requestUrlDraft: string = '';
  onClose: () => void = () => {
  };

  @State private tick: number = 0;
  @State private remoteModels: ProviderRemoteModel[] = [];
  @State private isRefreshing: boolean = false;
  @State private searchText: string = '';
  @State private showManualAddSheet: boolean = false;
  @State private addDraft: AddOnlineModelDraft = new AddOnlineModelDraft();
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
    this.vm?.setOnChanged(() => {
      this.tick++;
    });
    if (this.remoteModels.length === 0) {
      this.refreshModels();
    }
  }

  private displayTitle(): string {
    const list = this.vm?.draftSnapshot?.providers ?? [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === this.providerId) {
        const name = AIProviderDisplayNameResolver.display(list[i]);
        return L10n.format(
          L10n.getString($r('app.string.ai_settings_models_management_nav_title'), '{name} 模型'),
          { 'name': name }
        );
      }
    }
    return L10n.getString($r('app.string.ai_settings_models_management_nav_title_fallback'), '厂商模型');
  }

  private hasUsableKey(): boolean {
    const pending = (this.vm?.pendingApiKeyByProvider.get(this.providerId) ?? '').trim();
    if (pending.length > 0) {
      return true;
    }
    return this.vm?.isKeyConfigured(this.providerId) === true;
  }

  private canRefresh(): boolean {
    return !this.isRefreshing && this.hasUsableKey();
  }

  private companyModels(): LocalModel[] {
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
    out.sort((a: LocalModel, b: LocalModel) => {
      return (a.displayName || a.name).localeCompare(b.displayName || b.name);
    });
    return out;
  }

  private normalizedSearch(): string {
    return this.searchText.trim().toLowerCase();
  }

  private filteredCompanyModels(): LocalModel[] {
    const q = this.normalizedSearch();
    const all = this.companyModels();
    if (q.length === 0) {
      return all;
    }
    const out: LocalModel[] = [];
    for (let i = 0; i < all.length; i++) {
      const m = all[i];
      const hay = `${m.displayName} ${m.name} ${m.briefDescription ?? ''}`.toLowerCase();
      if (hay.indexOf(q) >= 0) {
        out.push(m);
      }
    }
    return out;
  }

  private filteredRemoteModels(): ProviderRemoteModel[] {
    const q = this.normalizedSearch();
    if (q.length === 0) {
      return this.remoteModels;
    }
    const out: ProviderRemoteModel[] = [];
    for (let i = 0; i < this.remoteModels.length; i++) {
      const m = this.remoteModels[i];
      const hay = `${m.displayName} ${m.name} ${m.ownedBy}`.toLowerCase();
      if (hay.indexOf(q) >= 0) {
        out.push(m);
      }
    }
    return out;
  }

  private resolvedRequestUrl(): string {
    const draft = this.requestUrlDraft.trim();
    if (draft.length > 0) {
      return draft;
    }
    const list = this.vm?.draftSnapshot?.providers ?? [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === this.providerId) {
        return (list[i].requestUrl ?? '').trim();
      }
    }
    return '';
  }

  private async refreshModels(): Promise<void> {
    if (!this.hasUsableKey()) {
      this.isRefreshing = false;
      return;
    }
    this.isRefreshing = true;
    try {
      const list = await this.vm?.fetchRemoteModels(this.providerId, this.resolvedRequestUrl());
      this.remoteModels = list ?? [];
    } catch (err) {
      const msg = AISettingsErrorLocalizer.localize(err as Object);
      this.showAlert(msg.length > 0 ? msg : `${err}`);
    } finally {
      this.isRefreshing = false;
      this.tick++;
    }
  }

  private showAlert(message: string): void {
    promptAction.showDialog({
      title: L10n.getString($r('app.string.ai_settings_models_management_alert_title'), '提示'),
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

  private isModelAdded(remote: ProviderRemoteModel): boolean {
    const remoteName = ProviderRemoteModelFetchService.normalizedModelName(remote.name);
    const local = this.companyModels();
    for (let i = 0; i < local.length; i++) {
      if (ProviderRemoteModelFetchService.normalizedModelName(local[i].name) === remoteName) {
        return true;
      }
    }
    return false;
  }

  private openManualAdd(remote?: ProviderRemoteModel): void {
    const draft = new AddOnlineModelDraft();
    draft.providerID = this.providerId;
    if (remote) {
      draft.name = remote.name;
      draft.displayName = remote.displayName;
      draft.supportsText = remote.supportsText;
      draft.supportsToolUse = remote.supportsToolUse;
      draft.supportsMultimodal = remote.supportsMultimodal;
      draft.supportsReasoning = remote.supportsReasoning;
      draft.reasoningControllable = remote.supportsReasoning;
      draft.supportsImageGen = remote.supportsImageGen;
      draft.priceTier = ProviderRemoteModelFetchService.remotePriceTier(remote);
    } else {
      draft.supportsText = true;
      draft.priceTier = 2;
    }
    this.addDraft = draft;
    this.showManualAddSheet = true;
  }

  private async onDeleteModel(modelId: string): Promise<void> {
    const ok = await this.vm?.deleteModelAndPersist(modelId);
    this.tick++;
    if (!ok) {
      const msg = this.vm?.errorMessage ?? '';
      if (msg.length > 0) {
        this.showAlert(msg);
      }
    }
  }

  private async onToggleEnabled(modelId: string, enabled: boolean): Promise<void> {
    this.vm?.setModelEnabled(modelId, enabled);
    this.tick++;
    if ((this.vm?.errorMessage ?? '').length > 0) {
      this.showAlert(this.vm!.errorMessage);
      return;
    }
    await this.vm?.save();
    this.tick++;
    if ((this.vm?.errorMessage ?? '').length > 0) {
      this.showAlert(this.vm!.errorMessage);
    }
  }

  @Builder
  private manualAddSheetBuilder() {
    AddOnlineModelSheet({
      initialProviderId: this.providerId,
      initialDraft: this.addDraft,
      onClose: () => {
        this.showManualAddSheet = false;
      },
      onSaved: () => {
        this.tick++;
      }
    })
  }

  build() {
    Column() {
      // 工具栏：关闭 | 标题 | + 刷新
      Row() {
        Text(L10n.getString($r('app.string.ai_settings_models_management_action_close'), '关闭'))
          .fontSize(16)
          .fontColor(AISettingsUiTokens.accent)
          .padding({ left: 8, right: 8, top: 10, bottom: 10 })
          .onClick(() => {
            this.onClose();
          })

        Text(this.displayTitle())
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AISettingsUiTokens.textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 4 }) {
          Text('+')
            .fontSize(24)
            .fontColor(AISettingsUiTokens.accent)
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.openManualAdd();
            })

          if (this.isRefreshing) {
            LoadingProgress()
              .width(22)
              .height(22)
              .margin({ right: 8 })
          } else {
            Text('↻')
              .fontSize(20)
              .fontColor(this.canRefresh() ? AISettingsUiTokens.accent : AISettingsUiTokens.textSecondary)
              .width(36)
              .height(36)
              .textAlign(TextAlign.Center)
              .opacity(this.canRefresh() ? 1 : 0.4)
              .onClick(() => {
                if (this.canRefresh()) {
                  this.refreshModels();
                }
              })
          }
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 4, right: 4 })

      TextInput({
        text: this.searchText,
        placeholder: L10n.getString(
          $r('app.string.ai_settings_models_management_search_prompt'),
          '搜索模型'
        )
      })
        .height(40)
        .margin({ left: 16, right: 16, top: 4, bottom: 8 })
        .backgroundColor(AISettingsUiTokens.cardBackground)
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .onChange((v: string) => {
          this.searchText = v;
        })

      Refresh({ refreshing: $$this.isRefreshing }) {
        List({ space: 0 }) {
          ListItemGroup({
            header: this.sectionHeader(
              L10n.getString($r('app.string.ai_settings_models_management_section_auto_refresh'), '自动刷新')
            )
          }) {
            ListItem() {
              Text(
                this.hasUsableKey()
                  ? L10n.getString(
                    $r('app.string.ai_settings_models_management_auto_refresh_enabled'),
                    '进入页面会自动拉取一次模型列表，也支持下拉或右上角按钮手动刷新。'
                  )
                  : L10n.getString(
                    $r('app.string.ai_settings_models_management_auto_refresh_empty_key'),
                    '当前厂商还没有可用的 API Key，暂时无法自动刷新远端模型列表。你仍然可以点右上角 + 手动添加模型。'
                  )
              )
                .fontSize(13)
                .fontColor(AISettingsUiTokens.textSecondary)
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                .width('100%')
            }
          }

          ListItemGroup({
            header: this.sectionHeader(
              L10n.format(
                L10n.getString($r('app.string.ai_settings_models_management_section_added'), '已添加 ({count})'),
                { 'count': `${this.filteredCompanyModels().length}` }
              )
            )
          }) {
            if (this.filteredCompanyModels().length === 0) {
              ListItem() {
                Text(
                  this.normalizedSearch().length === 0
                    ? L10n.getString(
                      $r('app.string.ai_settings_models_management_added_empty'),
                      '该厂商还没有已添加模型'
                    )
                    : L10n.getString(
                      $r('app.string.ai_settings_models_management_added_empty_search'),
                      '没有匹配的已添加模型'
                    )
                )
                  .fontSize(13)
                  .fontColor(AISettingsUiTokens.textSecondary)
                  .padding(16)
                  .width('100%')
              }
            } else {
              ForEach(this.filteredCompanyModels(), (m: LocalModel) => {
                ListItem() {
                  Row() {
                    Column() {
                      Text(m.displayName || m.name)
                        .fontSize(15)
                        .fontColor(AISettingsUiTokens.textPrimary)
                        .width('100%')
                      Text(m.name)
                        .fontSize(12)
                        .fontColor(AISettingsUiTokens.textSecondary)
                        .margin({ top: 4 })
                        .width('100%')
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    Toggle({ type: ToggleType.Switch, isOn: m.isEnabled })
                      .selectedColor(AISettingsUiTokens.accent)
                      .onChange((on: boolean) => {
                        this.onToggleEnabled(m.id, on);
                      })

                    Button(L10n.getString($r('app.string.ai_settings_providers_editor_model_delete'), '删除'))
                      .fontSize(13)
                      .fontColor(AISettingsUiTokens.error)
                      .backgroundColor(Color.Transparent)
                      .margin({ left: 4 })
                      .onClick(() => {
                        this.onDeleteModel(m.id);
                      })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 8, top: 10, bottom: 10 })
                }
              }, (m: LocalModel) => `${m.id}-${m.isEnabled}-${this.tick}`)
            }
          }

          ListItemGroup({
            header: this.sectionHeader(
              L10n.format(
                L10n.getString($r('app.string.ai_settings_models_management_section_remote'), '远端可用 ({count})'),
                { 'count': `${this.filteredRemoteModels().length}` }
              )
            ),
            footer: this.sectionFooter(
              L10n.getString(
                $r('app.string.ai_settings_models_management_remote_footer'),
                '自动刷新优先按厂商官方接口返回结果展示；如果接口不支持列出模型，仍可手动添加。'
              )
            )
          }) {
            if (!this.hasUsableKey()) {
              ListItem() {
                Text('')
                  .height(0)
              }
            } else if (this.isRefreshing && this.remoteModels.length === 0) {
              ListItem() {
                Row() {
                  LoadingProgress().width(20).height(20)
                  Text(L10n.getString(
                    $r('app.string.ai_settings_models_management_loading'),
                    '正在刷新模型列表...'
                  ))
                    .margin({ left: 8 })
                    .fontSize(13)
                    .fontColor(AISettingsUiTokens.textSecondary)
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding(16)
              }
            } else if (this.filteredRemoteModels().length === 0) {
              ListItem() {
                Text(
                  this.normalizedSearch().length === 0
                    ? L10n.getString(
                      $r('app.string.ai_settings_models_management_remote_empty'),
                      '暂未获取到可用模型'
                    )
                    : L10n.getString(
                      $r('app.string.ai_settings_models_management_remote_empty_search'),
                      '没有匹配的远端模型'
                    )
                )
                  .fontSize(13)
                  .fontColor(AISettingsUiTokens.textSecondary)
                  .padding(16)
                  .width('100%')
              }
            } else {
              ForEach(this.filteredRemoteModels(), (remote: ProviderRemoteModel) => {
                ListItem() {
                  Row() {
                    Column() {
                      Text(remote.displayName || remote.name)
                        .fontSize(15)
                        .fontColor(AISettingsUiTokens.textPrimary)
                        .width('100%')
                      Text(remote.ownedBy.length > 0 ? remote.ownedBy : remote.name)
                        .fontSize(12)
                        .fontColor(AISettingsUiTokens.textSecondary)
                        .margin({ top: 4 })
                        .width('100%')
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    if (this.isModelAdded(remote)) {
                      Text(L10n.getString(
                        $r('app.string.ai_settings_models_management_remote_added'),
                        '已添加'
                      ))
                        .fontSize(12)
                        .fontColor('#34C759')
                        .padding({ left: 8, right: 8 })
                    } else {
                      Button(L10n.getString(
                        $r('app.string.ai_settings_models_management_action_add'),
                        '添加'
                      ))
                        .type(ButtonType.Capsule)
                        .fontSize(12)
                        .fontColor(Color.White)
                        .backgroundColor(AISettingsUiTokens.accent)
                        .height(28)
                        .padding({ left: 12, right: 12 })
                        .onClick(() => {
                          this.openManualAdd(remote);
                        })
                    }
                  }
                  .width('100%')
                  .padding({ left: 16, right: 12, top: 10, bottom: 10 })
                }
              }, (remote: ProviderRemoteModel) => `${remote.name}-${this.tick}`)
            }
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .onRefreshing(() => {
        this.refreshModels();
      })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
    .bindSheet($$this.showManualAddSheet, this.manualAddSheetBuilder(), {
      height: SheetSize.LARGE,
      dragBar: true,
      // AddOnlineModelSheet 自带「取消/添加」，关闭系统 X 避免与「添加」重叠
      showClose: false,
      onDisappear: () => {
        this.showManualAddSheet = false;
      }
    })
  }

  @Builder
  private sectionHeader(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor(AISettingsUiTokens.textSecondary)
      .padding({ left: 16, top: 14, bottom: 6 })
      .width('100%')
  }

  @Builder
  private sectionFooter(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor(AISettingsUiTokens.textSecondary)
      .padding({ left: 16, right: 16, top: 4, bottom: 12 })
      .width('100%')
  }
}

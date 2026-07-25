import { promptAction } from '@kit.ArkUI';
import { AppContainer } from '../../../../../App/AppContainer';
import { AISettingsViewModel } from '../AISettingsViewModel';
import { AISettingsRoutes } from '../AISettingsRoutes';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { ProProviderCredentialPresentation } from '../../Application/ProviderModelCatalogService';
import { AITrialCard } from '../components/AITrialCard';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';
import { AISettingsEmptyState } from '../components/AISettingsEmptyState';
import { ProviderRowComponent } from '../components/ProviderRowComponent';
import { AddCustomProviderSheet } from './AddCustomProviderSheet';

@Component
export struct ProvidersPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  @State private tick: number = 0;
  @State private refreshing: boolean = false;
  /** 对标 iOS showAddCustomProvider → .sheet */
  @State private showAddCustomProvider: boolean = false;
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    // 进入「模型密钥」页：若 Hub 已加载过草稿则只打清单，避免二次全量 load
    this.vm = AppContainer.shared()?.createAISettingsViewModel();
    this.vm?.setOnChanged(() => {
      this.tick++;
    });
    const hasDraft = (this.vm?.localCredentialRows().length ?? 0) > 0;
    if (hasDraft && !(this.vm?.loading ?? false)) {
      this.vm?.logProvidersPageCatalog();
      return;
    }
    this.vm?.load().then(() => {
      this.vm?.logProvidersPageCatalog();
    });
  }

  private doBack(): void {
    if (this.onBack) {
      this.onBack();
    } else {
      this.stack.pop();
    }
  }

  private rows(): ProProviderCredentialPresentation[] {
    return this.vm?.localCredentialRows() ?? [];
  }

  private providerListState(): string {
    if (this.vm?.loading && this.rows().length === 0) {
      return 'loading';
    }
    if (this.vm?.errorMessage && this.vm.errorMessage.length > 0 && this.rows().length === 0) {
      return 'error';
    }
    if (this.rows().length === 0) {
      return 'empty';
    }
    if (this.vm?.syncStateText === 'degraded') {
      return 'degraded';
    }
    return 'ready';
  }

  private async onPullRefresh(): Promise<void> {
    if (this.refreshing || (this.vm?.loading ?? false)) {
      this.refreshing = false;
      return;
    }
    this.refreshing = true;
    try {
      await this.vm?.refreshRemote();
    } finally {
      this.refreshing = false;
      this.tick++;
    }
  }

  /** 对标 iOS setProviderEnabled(providerID:enabled:) */
  private async setProviderEnabled(providerId: string, enabled: boolean): Promise<void> {
    const ok = await this.vm?.setProviderEnabledAndPersist(providerId, enabled);
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

  @Builder
  private addCustomProviderSheetBuilder() {
    AddCustomProviderSheet({
      onClose: () => {
        this.showAddCustomProvider = false;
      },
      onSaved: () => {
        this.tick++;
      }
    })
  }

  build() {
    Column() {
      AISettingsNavHeader({
        title: $r('app.string.ai_settings_hub_providers'),
        // 对标 iOS Image(systemName: "plus.circle.fill")
        actionSymbol: $r('sys.symbol.plus_circle_fill'),
        actionTitle: '添加',
        onBack: () => {
          this.doBack();
        },
        onAction: () => {
          this.showAddCustomProvider = true;
        }
      })

      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            if (this.providerListState() === 'error') {
              Text(this.vm?.errorMessage ?? '')
                .fontSize(12)
                .fontColor(AISettingsUiTokens.error)
                .width('100%')
                .margin({ bottom: 12 })
              Button('重试')
                .onClick(() => {
                  this.vm?.load();
                })
                .margin({ bottom: 12 })
            } else if (this.vm?.errorMessage && this.vm.errorMessage.length > 0) {
              Text(this.vm.errorMessage)
                .fontSize(12)
                .fontColor(AISettingsUiTokens.error)
                .width('100%')
                .margin({ bottom: 12 })
            }

            AITrialCard({
              status: this.vm?.trialStatus,
              message: this.vm?.trialMessage ?? '',
              submitting: this.vm?.trialSubmitting ?? false,
              onApply: async (): Promise<boolean> => {
                if (!this.vm) {
                  return false;
                }
                return await this.vm.applyTrial('harmonyos settings');
              }
            })

            Text('模型厂商')
              .fontSize(AISettingsUiTokens.titleSection)
              .fontColor(AISettingsUiTokens.textSecondary)
              .width('100%')
              .margin({ top: 16, bottom: 8, left: 4 })

            if (this.providerListState() === 'loading') {
              Text('正在加载厂商配置…')
                .fontSize(14)
                .fontColor(AISettingsUiTokens.textSecondary)
                .width('100%')
                .padding(16)
            } else if (this.providerListState() === 'error') {
              Text('加载失败，请重试。网络错误不会清空本地厂商列表。')
                .fontSize(14)
                .fontColor(AISettingsUiTokens.textSecondary)
                .width('100%')
                .padding(16)
            } else if (this.providerListState() === 'empty') {
              Column() {
                AISettingsEmptyState({
                  message: $r('app.string.ai_settings_empty_providers'),
                  actionTitle: '新增',
                  onAction: () => {
                    this.showAddCustomProvider = true;
                  }
                })
              }
              .width('100%')
              .backgroundColor(AISettingsUiTokens.cardBackground)
              .borderRadius(AISettingsUiTokens.cardRadius)
            } else {
              if (this.providerListState() === 'degraded') {
                Text($r('app.string.ai_settings_refresh_degraded'))
                  .fontSize(12)
                  .fontColor(AISettingsUiTokens.textSecondary)
                  .width('100%')
                  .margin({ bottom: 8 })
              }
              Column() {
                ForEach(this.rows(), (row: ProProviderCredentialPresentation, index: number) => {
                  ProviderRowComponent({
                    provider: row,
                    showDivider: index < this.rows().length - 1,
                    onRowClick: () => {
                      this.stack.pushPath({ name: AISettingsRoutes.PROVIDER_EDIT, param: row.providerId });
                    },
                    onToggleEnabled: (providerId: string, enabled: boolean) => {
                      this.setProviderEnabled(providerId, enabled);
                    }
                  })
                }, (row: ProProviderCredentialPresentation) =>
                  `${row.providerId}-${row.enabled}-${row.source}-${this.tick}`)
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
            right: AISettingsUiTokens.pagePaddingH,
            bottom: 16
          })
          .alignItems(HorizontalAlign.Start)
        }
        .scrollBar(BarState.Off)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.onPullRefresh();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
    // 对标 iOS .sheet(isPresented: $showAddCustomProvider)
    .bindSheet($$this.showAddCustomProvider, this.addCustomProviderSheetBuilder(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: false,
      onDisappear: () => {
        this.showAddCustomProvider = false;
      }
    })
  }
}

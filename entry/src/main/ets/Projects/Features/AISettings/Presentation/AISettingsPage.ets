import { AppContainer } from '../../../../App/AppContainer';
import { AISettingsViewModel } from './AISettingsViewModel';
import { AISettingsRoutes } from './AISettingsRoutes';
import { AISettingsUiTokens } from './AISettingsUiTokens';
import { AISettingsNavigationController } from './AISettingsNavigation';
import { AISettingsNavHeader } from './components/AISettingsNavHeader';
import { AISettingsMenuRow } from './components/AISettingsMenuRow';
import { AISettingsStatusBanner } from './components/AISettingsStatusBanner';
import { AISettingsActionBar } from './components/AISettingsActionBar';
import { ProvidersPage } from './Providers/ProvidersPage';
import { ProviderEditorPage } from './Providers/ProviderEditorPage';
import { AddCustomProviderPage } from './Providers/AddCustomProviderPage';
import { ProviderPrivacyPolicyPage } from './Providers/ProviderPrivacyPolicyPage';
import { ModelsPage } from './Models/ModelsPage';
import { AddOnlineModelPage } from './Models/AddOnlineModelPage';
import { EditModelPage } from './Models/EditModelPage';
import { AgentEditorPage } from './Models/AgentEditorPage';
import { ModelIconPickerPage } from './Models/ModelIconPickerPage';
import { LocalModelDownloadPage } from './Models/LocalModelDownloadPage';
import { DefaultModelPreferencesPage } from './Preferences/DefaultModelPreferencesPage';
import { ScenarioBindingPage } from './Preferences/ScenarioBindingPage';
import { ToolSelectionPage } from './Preferences/ToolSelectionPage';
import { SmallTaskSelectionPage } from './Preferences/SmallTaskSelectionPage';
import { SmallTasksPage } from './SmallTasks/SmallTasksPage';
import { SmallTaskEditorPage } from './SmallTasks/SmallTaskEditorPage';
import { PromptInputDrawerPage } from './SmallTasks/PromptInputDrawerPage';
import { AIRuntimePlaygroundPage } from './Runtime/AIRuntimePlaygroundPage';

@Component
export struct AISettingsPage {
  onClose: () => void = () => {
  };
  private aiStack: NavPathStack = new NavPathStack();
  private nav?: AISettingsNavigationController;
  @State private ready: boolean = false;
  @State private tick: number = 0;
  @State private refreshing: boolean = false;
  private vm?: AISettingsViewModel;

  aboutToAppear(): void {
    this.nav = new AISettingsNavigationController(this.aiStack, () => {
      this.onClose();
    });
    const container = AppContainer.shared();
    if (!container) {
      this.ready = true;
      return;
    }
    this.vm = container.createAISettingsViewModel();
    this.vm.setOnChanged(() => {
      this.tick++;
    });
    this.vm.load().then(() => {
      this.ready = true;
      this.tick++;
    }).catch(() => {
      this.ready = true;
      this.tick++;
    });
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

  private routeParam(name: string): string {
    return this.nav?.paramOf(name) ?? '';
  }

  @Builder
  aiDestination(name: string) {
    // Navigation 的目标节点必须由 NavDestination 承载，否则 push 后目标页可能为空白。
    NavDestination() {
      if (name === AISettingsRoutes.PROVIDERS) {
        ProvidersPage({ stack: this.aiStack, onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.PROVIDER_EDIT) {
        ProviderEditorPage({ stack: this.aiStack, providerId: this.routeParam(name), onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.PROVIDER_ADD) {
        AddCustomProviderPage({ stack: this.aiStack, onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.PROVIDER_PRIVACY) {
        ProviderPrivacyPolicyPage({ stack: this.aiStack, url: this.routeParam(name), onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.MODELS) {
        ModelsPage({ stack: this.aiStack, onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.MODEL_ADD) {
        AddOnlineModelPage({ stack: this.aiStack, onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.MODEL_EDIT) {
        EditModelPage({ stack: this.aiStack, modelId: this.routeParam(name), onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.MODEL_AGENT) {
        AgentEditorPage({ stack: this.aiStack, modelId: this.routeParam(name), onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.MODEL_ICON) {
        ModelIconPickerPage({ stack: this.aiStack, modelId: this.routeParam(name), onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.MODEL_LOCAL) {
        LocalModelDownloadPage({ stack: this.aiStack, onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.PREFERENCES) {
        DefaultModelPreferencesPage({ stack: this.aiStack, onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.SCENARIO_BINDING) {
        ScenarioBindingPage({ stack: this.aiStack, scenario: this.routeParam(name), onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.TOOL_SELECT) {
        ToolSelectionPage({ stack: this.aiStack, bindingKey: this.routeParam(name), onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.TASK_SELECT) {
        SmallTaskSelectionPage({ stack: this.aiStack, bindingKey: this.routeParam(name), onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.SMALL_TASKS) {
        SmallTasksPage({ stack: this.aiStack, onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.SMALL_TASK_EDIT) {
        SmallTaskEditorPage({ stack: this.aiStack, taskCode: this.routeParam(name), onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.PROMPT_DRAWER) {
        PromptInputDrawerPage({ stack: this.aiStack, taskCode: this.routeParam(name), onBack: () => { this.nav?.pop(); } });
      } else if (name === AISettingsRoutes.RUNTIME_PLAYGROUND) {
        AIRuntimePlaygroundPage({ stack: this.aiStack, onBack: () => { this.nav?.pop(); } });
      } else {
        Column() {
          AISettingsNavHeader({ title: $r('app.string.ai_settings_nav_error'), onBack: () => { this.nav?.pop(); } })
          Text($r('app.string.ai_settings_route_missing'))
            .fontSize(14)
            .fontColor(AISettingsUiTokens.textSecondary)
            .padding(24)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(AISettingsUiTokens.pageBackground)
      }
    }
    .hideTitleBar(true)
  }

  build() {
    Navigation(this.aiStack) {
      Column() {
        AISettingsNavHeader({
          title: '',
          largeTitleMode: true,
          onBack: () => {
            this.onClose();
          }
        })

        Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            Text($r('app.string.ai_settings_scene_title'))
              .fontSize(AISettingsUiTokens.titleLarge)
              .fontWeight(FontWeight.Bold)
              .fontColor(AISettingsUiTokens.textPrimary)
              .width('100%')
              .margin({ bottom: 16 })

            AISettingsStatusBanner({
              syncText: this.vm?.syncStateText ?? '',
              errorMessage: this.vm?.errorMessage ?? '',
              loading: this.vm?.loading ?? !this.ready,
              hasUnsaved: this.vm?.hasUnsavedChanges ?? false,
              onRetry: () => {
                this.vm?.load();
              }
            })

              AISettingsActionBar({
              saving: this.vm?.saving ?? false,
              hasUnsaved: this.vm?.hasUnsavedChanges ?? false,
              loading: this.vm?.loading ?? false,
              onRefresh: () => {
                this.vm?.refreshRemote();
              },
              onDiscard: () => {
                this.vm?.discard();
              },
              onSave: () => {
                this.vm?.save();
              }
            })
              .margin({ top: 12, bottom: 8 })

            Text($r('app.string.ai_settings_section_model'))
              .fontSize(AISettingsUiTokens.titleSection)
              .fontColor(AISettingsUiTokens.textSecondary)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ top: AISettingsUiTokens.sectionGap - 8, bottom: 8, left: 4 })

            Column() {
              AISettingsMenuRow({
                title: $r('app.string.ai_settings_hub_providers'),
                subtitle: $r('app.string.ai_settings_hub_providers_sub'),
                iconKind: 'key',
                showDivider: true,
                onRowClick: () => {
                  this.nav?.pushProviders();
                }
              })
              AISettingsMenuRow({
                title: $r('app.string.ai_settings_hub_models'),
                subtitle: $r('app.string.ai_settings_hub_models_sub'),
                iconKind: 'models',
                showDivider: true,
                onRowClick: () => {
                  this.nav?.pushModels();
                }
              })
              AISettingsMenuRow({
                title: $r('app.string.ai_settings_hub_preferences'),
                subtitle: $r('app.string.ai_settings_hub_preferences_sub'),
                iconKind: 'preferences',
                showDivider: false,
                onRowClick: () => {
                  this.nav?.pushPreferences();
                }
              })
            }
            .width('100%')
            .backgroundColor(AISettingsUiTokens.cardBackground)
            .borderRadius(AISettingsUiTokens.cardRadius)
            .clip(true)

            Text($r('app.string.ai_settings_section_tools'))
              .fontSize(AISettingsUiTokens.titleSection)
              .fontColor(AISettingsUiTokens.textSecondary)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ top: AISettingsUiTokens.sectionGap, bottom: 8, left: 4 })

            Column() {
              AISettingsMenuRow({
                title: $r('app.string.ai_settings_hub_tasks'),
                subtitle: $r('app.string.ai_settings_hub_tasks_sub'),
                iconKind: 'tasks',
                showDivider: true,
                onRowClick: () => {
                  this.nav?.pushSmallTasks();
                }
              })
              AISettingsMenuRow({
                title: $r('app.string.ai_settings_hub_runtime'),
                subtitle: $r('app.string.ai_settings_hub_runtime_sub'),
                iconKind: 'agent',
                showDivider: false,
                onRowClick: () => {
                  this.nav?.pushRuntimePlayground();
                }
              })
            }
            .width('100%')
            .backgroundColor(AISettingsUiTokens.cardBackground)
            .borderRadius(AISettingsUiTokens.cardRadius)
            .clip(true)

            Blank()
              .height(40)
          }
          .width('100%')
          .padding({
            left: AISettingsUiTokens.pagePaddingH,
            right: AISettingsUiTokens.pagePaddingH,
            bottom: 24
          })
          .alignItems(HorizontalAlign.Start)
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        }
        .layoutWeight(1)
        .onRefreshing(() => {
          this.onPullRefresh();
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AISettingsUiTokens.pageBackground)
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.aiDestination)
  }
}

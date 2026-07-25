import { AppContainer } from '../../../App/AppContainer';
import { appRouter } from '../../../App/Navigation/AppRouter';
import { SESSION_STATE_KEY, SessionState } from '../../../App/AppSessionStore';
import { LoginPage } from '../Auth/LoginPage';
import { SettingsAccountRouting } from './SettingsAccountRouting';
import { SettingsRoutes } from './SettingsRoutes';

/**
 * 设置 Tab 根内容。账号 / AI 设置经 appRouter 压入根栈，跳转后不显示底部 Tab。
 */
@Component
export struct SettingsPage {
  @StorageLink(SESSION_STATE_KEY) sessionState: SessionState = 'loading';
  @State showUpgradeSheet: boolean = false;
  @State accountSummary: string = '';
  @State accountDisabled: boolean = false;

  aboutToAppear(): void {
    this.refreshAccountRow();
  }

  @Builder
  upgradeSheetBuilder() {
    LoginPage({ isUpgradeSheet: true })
  }

  build() {
    Column() {
      Text($r('app.string.tab_settings'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 20, right: 20, top: 18, bottom: 8 })

      List() {
        ListItem() {
          Row() {
            Column() {
              Text($r('app.string.settings_account'))
                .fontSize(16)
              if (this.accountSummary.length > 0) {
                Text(this.accountSummary)
                  .fontSize(13)
                  .fontColor($r('sys.color.font_secondary'))
                  .margin({ top: 4 })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('›')
              .fontSize(18)
              .fontColor($r('sys.color.font_secondary'))
              .opacity(this.accountDisabled ? 0.4 : 1)
          }
          .width('100%')
          .padding(16)
          .opacity(this.accountDisabled ? 0.5 : 1)
          .onClick(() => {
            this.onAccountRowClick();
          })
        }

        ListItem() {
          Row() {
            Text($r('app.string.settings_ai'))
              .fontSize(16)
              .layoutWeight(1)
            Text('›')
              .fontSize(18)
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .padding(16)
          .onClick(() => {
            appRouter.jumpPage(SettingsRoutes.AI);
          })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#E5E5E5' })
    }
    .width('100%')
    .height('100%')
    .onAppear(() => {
      this.refreshAccountRow();
    })
    .bindSheet($$this.showUpgradeSheet, this.upgradeSheetBuilder(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: true
    })
  }

  /** 登出时清空 sheet；根栈由会话切换自然回退。 */
  clearLocalNav(): void {
    this.showUpgradeSheet = false;
  }

  private refreshAccountRow(): void {
    const container = AppContainer.shared();
    const session = container?.sessionStore.session;
    const state = container?.sessionStore.sessionState ?? this.sessionState;
    this.accountSummary = SettingsAccountRouting.summaryText(state, session);
    this.accountDisabled = SettingsAccountRouting.resolveAction(state, session) === 'disabled';
  }

  private onAccountRowClick(): void {
    const container = AppContainer.shared();
    const session = container?.sessionStore.session;
    const state = container?.sessionStore.sessionState ?? this.sessionState;
    const action = SettingsAccountRouting.resolveAction(state, session);
    if (action === 'disabled' || action === 'none') {
      return;
    }
    if (action === 'upgrade') {
      this.showUpgradeSheet = true;
      return;
    }
    appRouter.jumpPage(SettingsRoutes.ACCOUNT);
  }
}

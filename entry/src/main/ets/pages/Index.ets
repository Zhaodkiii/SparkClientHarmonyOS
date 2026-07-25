import { SESSION_STATE_KEY } from '../App/AppSessionStore';
import {
  NETWORK_GATE_KEY,
  PREPARED_ACCOUNT_ID_KEY,
  CURRENT_ACCOUNT_ID_KEY
} from '../App/AppStartupKeys';
import { appRouter } from '../App/Navigation/AppRouter';
import { AppRootNavDestinationBuilder } from '../App/Navigation/AppRootNavDestination';
import { LaunchPlaceholder } from '../Projects/App/LaunchPlaceholder';
import { NetworkGateView } from '../Projects/App/NetworkGateView';
import { MainTabsPage } from '../Projects/App/MainTabsPage';
import { LoginPage } from '../Projects/Features/Auth/LoginPage';
import { AppNotificationHost } from '../App/Notification/AppNotificationHost';

/**
 * 应用根页：会话壳 + 根 Navigation。
 * 二级业务页经 appRouter.jumpPage 压入 rootStack，覆盖 MainTabsPage，统一隐藏底部 Tab
 *（对齐 Recycling Index + phoneRouterControl.jumpPage）。
 */
@Entry
@Component
struct Index {
  @StorageLink(SESSION_STATE_KEY) @Watch('onSessionStateChanged') sessionState: string = 'loading';
  @StorageLink(NETWORK_GATE_KEY) networkGate: string = 'evaluating';
  @StorageLink(PREPARED_ACCOUNT_ID_KEY) preparedAccountId: number = -1;
  @StorageLink(CURRENT_ACCOUNT_ID_KEY) currentAccountId: number = -1;
  private rootStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    appRouter.bind(this.rootStack);
  }

  onSessionStateChanged(): void {
    if (this.sessionState !== 'signedIn') {
      appRouter.clear();
    }
  }

  @Builder
  rootDestination(name: string) {
    AppRootNavDestinationBuilder(name)
  }

  build() {
    Stack() {
      Navigation(this.rootStack) {
        if (this.networkGate === 'offline') {
          NetworkGateView()
        } else if (this.sessionState === 'signedOut') {
          LoginPage()
        } else if (this.sessionState === 'signedIn'
          && this.preparedAccountId > 0
          && this.preparedAccountId === this.currentAccountId) {
          MainTabsPage()
        } else {
          LaunchPlaceholder()
        }
      }
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .navDestination(this.rootDestination)

      AppNotificationHost()
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Top)
  }
}

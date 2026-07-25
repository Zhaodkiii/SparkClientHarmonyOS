import { HomeTabPage } from './HomeTabPage';
import { ChatConversationListPage } from '../Features/Chat/Presentation/ChatConversationListPage';
import { SettingsPage } from '../Features/Settings/SettingsPage';

/**
 * 主框架底部 Tab（对齐 Recycling HomePage：Tabs + BarPosition.End）。
 * 仅承载各 Tab 根内容；二级页请用 appRouter.jumpPage 压入 Index.rootStack，勿在此再套 Navigation。
 */
@Component
export struct MainTabsPage {
  @State currentIndex: number = 0;
  private tabsController: TabsController = new TabsController();

  @Builder
  tabBar(title: Resource, index: number) {
    Column() {
      Text(title)
        .fontSize(12)
        .fontColor(this.currentIndex === index ? $r('sys.color.brand') : $r('sys.color.font_secondary'))
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Regular)
    }
    .width('100%')
    .height(52)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentIndex = index;
      this.tabsController.changeIndex(index);
    })
  }

  build() {
    Tabs({
      barPosition: BarPosition.End,
      index: this.currentIndex,
      controller: this.tabsController
    }) {
      TabContent() {
        HomeTabPage()
      }
      .tabBar(this.tabBar($r('app.string.tab_home'), 0))

      TabContent() {
        ChatConversationListPage()
      }
      .tabBar(this.tabBar($r('app.string.tab_chat'), 1))

      TabContent() {
        SettingsPage()
      }
      .tabBar(this.tabBar($r('app.string.tab_settings'), 2))
    }
    .scrollable(false)
    .barMode(BarMode.Fixed)
    .barHeight(52)
    .animationDuration(0)
    .width('100%')
    .height('100%')
    .onChange((index: number) => {
      this.currentIndex = index;
    })
  }
}

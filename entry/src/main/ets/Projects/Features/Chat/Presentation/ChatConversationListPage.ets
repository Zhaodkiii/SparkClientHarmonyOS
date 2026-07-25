import { AppContainer } from '../../../../App/AppContainer';
import { appRouter } from '../../../../App/Navigation/AppRouter';
import { ChatThread } from '../Domain/ChatModels';
import { ChatThreadListItem } from './ChatPresentationModels';
import { ChatRoutes } from './ChatRoutes';

/**
 * 对话 Tab 根列表。详情经 appRouter 压入根栈，跳转后不显示底部 Tab。
 */
@Component
export struct ChatConversationListPage {
  @State private ready: boolean = false;
  @State private loading: boolean = false;
  @State private refreshing: boolean = false;
  @State private errorText: string = '';
  @State private query: string = '';
  @State private threads: ChatThread[] = [];
  @State private items: ChatThreadListItem[] = [];
  private accountId: number = 0;

  aboutToAppear(): void { this.load(false); }

  private async load(refresh: boolean): Promise<void> {
    const container = AppContainer.shared();
    if (!container) { this.errorText = '应用未就绪'; this.ready = true; return; }
    this.accountId = container.accountRuntime.activeAccountId ?? 0;
    if (this.accountId <= 0) { this.errorText = '请先登录'; this.ready = true; return; }
    if (refresh) this.refreshing = true; else this.loading = true;
    try {
      if (refresh) await container.chatSyncSupervisor.refreshThreadListIncremental();
      this.threads = await container.chatRepository.listThreads(this.accountId);
      this.items = this.threads.map((value: ChatThread): ChatThreadListItem => ChatThreadListItem.from(value));
      this.errorText = '';
    } catch (_e) {
      this.errorText = '会话列表加载失败';
    } finally {
      this.loading = false; this.refreshing = false; this.ready = true;
    }
  }

  private visibleItems(): ChatThreadListItem[] {
    const value = this.query.trim().toLowerCase();
    if (value.length === 0) return this.items;
    return this.items.filter((item: ChatThreadListItem): boolean =>
      item.title.toLowerCase().includes(value) || item.preview.toLowerCase().includes(value));
  }

  private pushDetail(id: string): void {
    appRouter.jumpPage(ChatRoutes.DETAIL, id);
  }

  private async createThread(): Promise<void> {
    const container = AppContainer.shared();
    if (!container || this.accountId <= 0) return;
    const thread = await container.createThreadUseCase.execute(this.accountId);
    await this.load(false);
    this.pushDetail(thread.clientId);
  }

  build() {
    Column() {
      Row() {
        Text('对话').fontSize(28).fontWeight(FontWeight.Bold).layoutWeight(1)
        Button('新对话').fontSize(13).onClick(() => { this.createThread(); })
      }
      .width('100%').padding({ left: 20, right: 20, top: 18, bottom: 12 })

      TextInput({ text: this.query, placeholder: '搜索对话' })
        .height(42).margin({ left: 16, right: 16, bottom: 8 })
        .onChange((value: string) => { this.query = value; })

      Refresh({ refreshing: $$this.refreshing }) {
        if (!this.ready || this.loading) {
          Scroll() {
            List() {
              ForEach([1, 2, 3], (_value: number) => {
                ListItem() { Row().width('100%').height(64).backgroundColor('#EEF2F6').borderRadius(12) }
                  .margin({ left: 16, right: 16, bottom: 10 })
              }, (value: number) => `${value}`)
            }.layoutWeight(1)
          }
        } else if (this.visibleItems().length === 0) {
          Column() {
            Text(this.errorText.length > 0 ? this.errorText : (this.query.length > 0 ? '没有匹配的对话' : '还没有对话'))
              .fontSize(16).fontColor('#66717D')
            Button(this.query.length > 0 ? '清除搜索' : '开始新的健康对话')
              .margin({ top: 14 }).onClick(() => { this.query = ''; this.createThread(); })
          }.layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.visibleItems(), (item: ChatThreadListItem) => {
              ListItem() {
                Row() {
                  Text(item.iconName).fontSize(22).width(44).height(44).textAlign(TextAlign.Center)
                    .backgroundColor(item.iconColor).borderRadius(22)
                  Column() {
                    Row() {
                      Text(item.title).fontSize(16).fontWeight(FontWeight.Medium).maxLines(1).layoutWeight(1)
                      if (item.isPinned) Text('置顶').fontSize(11).fontColor('#3973B9')
                    }.width('100%')
                    Text(item.preview).fontSize(13).fontColor('#66717D').maxLines(2).margin({ top: 5 })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: 12 })
                  Text('›').fontSize(22).fontColor('#A0AAB4')
                }
                .width('100%').padding({ left: 16, right: 12, top: 12, bottom: 12 })
                .onClick(() => { this.pushDetail(item.id); })
              }
              .margin({ left: 8, right: 8, bottom: 2 })
            }, (item: ChatThreadListItem) => item.id)
          }.width('100%').height('100%').divider({ strokeWidth: 0.5, color: '#E5EDF5' })
        }
      }
      .layoutWeight(1)
      .onRefreshing(() => { this.load(true); })
    }
    .width('100%').height('100%').backgroundColor('#F6F8FB')
    .onAppear(() => { if (!this.ready) this.load(false); })
  }
}

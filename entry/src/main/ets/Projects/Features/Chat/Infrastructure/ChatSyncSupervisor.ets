import { ChatLocalChangeEvent, ChatLocalChangeHub, ChatLocalChangeListener } from './ChatLocalChangeHub';
import { ChatSyncEngine } from './ChatSyncEngine';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';

/**
 * 对齐 iOS ChatSyncSupervisor：监听本地变更 → 防抖 → pushOutboxOnly / pushSingleThread。
 */
export class ChatSyncSupervisor {
  private readonly syncEngine: ChatSyncEngine;
  private readonly listener: ChatLocalChangeListener;
  private outboxTimer?: number;
  private readonly threadTimers: Map<string, number> = new Map();
  private static readonly DEBOUNCE_MS: number = 700;

  constructor(syncEngine: ChatSyncEngine) {
    this.syncEngine = syncEngine;
    this.listener = (event: ChatLocalChangeEvent): void => {
      this.onLocalChange(event);
    };
    ChatLocalChangeHub.addListener(this.listener);
  }

  dispose(): void {
    ChatLocalChangeHub.removeListener(this.listener);
    if (this.outboxTimer !== undefined) {
      clearTimeout(this.outboxTimer);
      this.outboxTimer = undefined;
    }
    this.threadTimers.forEach((timer: number) => {
      clearTimeout(timer);
    });
    this.threadTimers.clear();
  }

  async syncNow(): Promise<void> {
    await this.syncEngine.syncNow();
  }

  async syncNowWithPull(): Promise<void> {
    await this.syncEngine.syncNowWithPull();
  }

  async refreshThreadListIncremental(): Promise<void> {
    await this.syncEngine.refreshThreadListIncremental();
  }

  async pullThreadMessagesIncrementalOnOpen(threadId: string): Promise<void> {
    await this.syncEngine.pullThreadMessagesIncrementalOnOpen(threadId);
  }

  async startRealtimeSync(): Promise<void> {
    await this.syncEngine.startRealtime();
  }

  async stopRealtimeSync(): Promise<void> {
    await this.syncEngine.stopRealtime();
  }

  private onLocalChange(event: ChatLocalChangeEvent): void {
    if (event.kind === 'threadsChanged') {
      const threadId = event.threadId;
      if (threadId && threadId.length > 0) {
        this.scheduleThreadPush(threadId);
      }
      return;
    }
    if (event.kind === 'messagesAppended' || event.kind === 'messagesUpdated') {
      if (event.affectsThreadList) {
        this.scheduleOutboxPush(event.kind);
      }
    }
  }

  private scheduleOutboxPush(reason: string): void {
    if (this.outboxTimer !== undefined) {
      clearTimeout(this.outboxTimer);
    }
    this.outboxTimer = setTimeout((): void => {
      this.outboxTimer = undefined;
      void this.runOutboxPush(reason);
    }, ChatSyncSupervisor.DEBOUNCE_MS) as number;
  }

  private scheduleThreadPush(threadId: string): void {
    const existing = this.threadTimers.get(threadId);
    if (existing !== undefined) {
      clearTimeout(existing);
    }
    const timer = setTimeout((): void => {
      this.threadTimers.delete(threadId);
      void this.runThreadPush(threadId);
    }, ChatSyncSupervisor.DEBOUNCE_MS) as number;
    this.threadTimers.set(threadId, timer);
  }

  private async runOutboxPush(reason: string): Promise<void> {
    try {
      await this.syncEngine.pushOutboxOnly();
    } catch (err) {
      const fields = new LogFields();
      fields.detail = `聊天 outbox 自动上送失败，reason=${reason}, error=${err}`;
      Logger.debug('chat.sync.outbox.auto_failed', LogModule.GENERAL, fields);
    }
  }

  private async runThreadPush(threadId: string): Promise<void> {
    try {
      await this.syncEngine.pushSingleThread(threadId);
      await this.syncEngine.syncNow();
    } catch (err) {
      const fields = new LogFields();
      fields.detail = `单会话元数据自动上送失败，thread=${threadId.substring(0, 8)}, error=${err}`;
      Logger.debug('chat.sync.thread.auto_failed', LogModule.GENERAL, fields);
    }
  }
}

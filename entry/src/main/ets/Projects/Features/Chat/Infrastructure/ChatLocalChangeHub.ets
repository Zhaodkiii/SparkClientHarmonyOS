/**
 * 对齐 iOS Notification.sparkChatDatabaseDidChange 的轻量事件总线。
 * Repository 在本地线程/消息变更后发布；ChatSyncSupervisor 订阅并防抖上送。
 */
export type ChatLocalChangeKind = 'messagesAppended' | 'messagesUpdated' | 'threadsChanged';

export class ChatLocalChangeEvent {
  kind: ChatLocalChangeKind = 'messagesUpdated';
  threadId?: string;
  affectsThreadList: boolean = true;
}

export type ChatLocalChangeListener = (event: ChatLocalChangeEvent) => void;

export class ChatLocalChangeHub {
  private static listeners: ChatLocalChangeListener[] = [];

  static addListener(listener: ChatLocalChangeListener): void {
    ChatLocalChangeHub.listeners.push(listener);
  }

  static removeListener(listener: ChatLocalChangeListener): void {
    const next: ChatLocalChangeListener[] = [];
    for (let i = 0; i < ChatLocalChangeHub.listeners.length; i++) {
      if (ChatLocalChangeHub.listeners[i] !== listener) {
        next.push(ChatLocalChangeHub.listeners[i]);
      }
    }
    ChatLocalChangeHub.listeners = next;
  }

  static publish(kind: ChatLocalChangeKind, threadId?: string, affectsThreadList: boolean = true): void {
    const event = new ChatLocalChangeEvent();
    event.kind = kind;
    event.threadId = threadId;
    event.affectsThreadList = affectsThreadList;
    for (let i = 0; i < ChatLocalChangeHub.listeners.length; i++) {
      try {
        ChatLocalChangeHub.listeners[i](event);
      } catch (_e) {
        // 监听失败不阻断业务写路径
      }
    }
  }
}

import {
  NotificationEnqueueResult,
  NotificationIntent,
  NotificationMessage,
  NotificationTapAction
} from '../Domain/NotificationModels';
import { NotificationInboxStore } from './NotificationInboxStore';
import { NotificationMetricsStore } from './NotificationMetricsStore';

/**
 * 串行入队：2s 去重、128 容量、tapAction 旁路。
 */
export class NotificationQueue {
  private readonly dedupeWindowMs: number = 2000;
  private readonly maxQueueDepth: number = 128;
  private messages: NotificationMessage[] = [];
  private lastSeenByKey: Map<string, number> = new Map();
  private tapActions: Map<string, NotificationTapAction> = new Map();
  private chain: Promise<void> = Promise.resolve();
  private readonly inbox: NotificationInboxStore;
  private readonly metrics: NotificationMetricsStore;

  constructor(inbox: NotificationInboxStore, metrics: NotificationMetricsStore) {
    this.inbox = inbox;
    this.metrics = metrics;
  }

  get depth(): number {
    return this.messages.length;
  }

  async enqueue(intent: NotificationIntent): Promise<NotificationEnqueueResult> {
    return new Promise<NotificationEnqueueResult>((resolve: (r: NotificationEnqueueResult) => void) => {
      this.chain = this.chain
        .then(async () => {
          const result = await this.enqueueUnlocked(intent);
          resolve(result);
        })
        .catch(async () => {
          const message = NotificationMessage.fromIntent(intent);
          const result = NotificationEnqueueResult.dropped(message, 'queueOverflow');
          resolve(result);
        });
    });
  }

  dequeue(): NotificationMessage | undefined {
    if (this.messages.length === 0) {
      return undefined;
    }
    return this.messages.shift();
  }

  takeTapAction(messageId: string): NotificationTapAction | undefined {
    const action = this.tapActions.get(messageId);
    this.tapActions.delete(messageId);
    return action;
  }

  clearTapAction(messageId: string): void {
    this.tapActions.delete(messageId);
  }

  reset(): void {
    this.messages = [];
    this.lastSeenByKey.clear();
    this.tapActions.clear();
  }

  private async enqueueUnlocked(intent: NotificationIntent): Promise<NotificationEnqueueResult> {
    const trimmedMsg = intent.message.trim();
    if (trimmedMsg.length === 0) {
      const empty = NotificationMessage.fromIntent(intent);
      return NotificationEnqueueResult.dropped(empty, 'duplicate');
    }
    intent.message = trimmedMsg;
    const message = NotificationMessage.fromIntent(intent);
    const now = Date.now();
    const previous = this.lastSeenByKey.get(message.dedupeKey);
    if (previous !== undefined && now - previous < this.dedupeWindowMs) {
      await this.metrics.recordDropped('duplicate');
      await this.inbox.markDropped(message, 'duplicate', now);
      return NotificationEnqueueResult.dropped(message, 'duplicate');
    }
    if (this.messages.length >= this.maxQueueDepth) {
      await this.metrics.recordDropped('queueOverflow');
      await this.inbox.markDropped(message, 'queueOverflow', now);
      return NotificationEnqueueResult.dropped(message, 'queueOverflow');
    }
    this.messages.push(message);
    this.lastSeenByKey.set(message.dedupeKey, now);
    if (intent.onTap) {
      this.tapActions.set(message.id, intent.onTap);
    }
    await this.inbox.appendQueued(message);
    await this.metrics.recordEnqueued();
    return NotificationEnqueueResult.enqueued(message);
  }
}

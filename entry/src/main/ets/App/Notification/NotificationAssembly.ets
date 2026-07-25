import { NotificationInboxStore } from '../../Projects/Core/Notification/Infrastructure/NotificationInboxStore';
import { NotificationMetricsStore } from '../../Projects/Core/Notification/Infrastructure/NotificationMetricsStore';
import { NotificationQueue } from '../../Projects/Core/Notification/Infrastructure/NotificationQueue';
import { NotificationStore } from '../../Projects/Core/Notification/Application/NotificationStore';
import { NotificationDeliveryCoordinator } from '../../Projects/Core/Notification/Application/NotificationDeliveryCoordinator';
import { PublishNotificationUseCase } from '../../Projects/Core/Notification/Application/PublishNotificationUseCase';
import { DefaultNotificationClient, NotificationClient } from '../../Projects/Core/Notification/Application/NotificationClient';

/**
 * 应用内通知装配产物。
 */
export class NotificationAssembly {
  readonly inbox: NotificationInboxStore;
  readonly metrics: NotificationMetricsStore;
  readonly queue: NotificationQueue;
  readonly store: NotificationStore;
  readonly delivery: NotificationDeliveryCoordinator;
  readonly client: NotificationClient;

  constructor(filesDir: string) {
    this.inbox = new NotificationInboxStore(filesDir);
    this.metrics = new NotificationMetricsStore();
    this.queue = new NotificationQueue(this.inbox, this.metrics);
    this.store = new NotificationStore();
    this.delivery = new NotificationDeliveryCoordinator(
      this.queue,
      this.store,
      this.inbox,
      this.metrics
    );
    this.client = new DefaultNotificationClient(
      new PublishNotificationUseCase(this.queue, this.delivery)
    );
  }

  /** 登出 / 账号切换 / 鉴权失效时清理历史与展示态 */
  async clearForAccountChange(): Promise<void> {
    this.delivery.reset();
    this.metrics.reset();
    await this.inbox.clear();
  }
}

import { NotificationIntent } from '../Domain/NotificationModels';
import { NotificationQueue } from '../Infrastructure/NotificationQueue';
import { NotificationDeliveryCoordinator } from './NotificationDeliveryCoordinator';
import { ErrorLogger } from '../../../../Foundation/Logging/ErrorLogger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';

export class PublishNotificationUseCase {
  private readonly queue: NotificationQueue;
  private readonly delivery: NotificationDeliveryCoordinator;

  constructor(queue: NotificationQueue, delivery: NotificationDeliveryCoordinator) {
    this.queue = queue;
    this.delivery = delivery;
  }

  async execute(intent: NotificationIntent): Promise<void> {
    if (!intent.message || intent.message.trim().length === 0) {
      ErrorLogger.log('notification.empty_message', LogModule.NOTIFICATION, new Error('empty'));
      return;
    }
    const result = await this.queue.enqueue(intent);
    if (result.enqueued) {
      this.delivery.startIfNeeded();
    }
  }
}

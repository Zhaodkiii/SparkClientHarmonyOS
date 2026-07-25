import {
  NotificationIntent,
  NotificationLevel,
  NotificationMessage,
  NotificationPresentation
} from '../Domain/NotificationModels';
import { PublishNotificationUseCase } from './PublishNotificationUseCase';
import { ErrorLogger } from '../../../../Foundation/Logging/ErrorLogger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';

/**
 * 业务统一发布入口（抽象类，避免 structural typing）。
 */
export abstract class NotificationClient {
  abstract publish(intent: NotificationIntent): void;

  success(message: string, title?: string, source: string = 'app'): void {
    this.publish(new NotificationIntent(message, 'success', 'toast', source, title));
  }

  error(message: string, title?: string, source: string = 'app'): void {
    this.publish(new NotificationIntent(message, 'error', 'banner', source, title));
  }

  warning(message: string, title?: string, source: string = 'app'): void {
    this.publish(new NotificationIntent(message, 'warning', 'banner', source, title));
  }

  info(message: string, title?: string, source: string = 'app'): void {
    this.publish(new NotificationIntent(message, 'info', 'toast', source, title));
  }
}

export class DefaultNotificationClient extends NotificationClient {
  private readonly useCase: PublishNotificationUseCase;

  constructor(useCase: PublishNotificationUseCase) {
    super();
    this.useCase = useCase;
  }

  publish(intent: NotificationIntent): void {
    this.useCase.execute(intent).catch((err: Object) => {
      ErrorLogger.log('notification.publish_failed', LogModule.NOTIFICATION, err);
    });
  }
}

export { NotificationIntent, NotificationLevel, NotificationPresentation, NotificationMessage };

/**
 * 兼容旧 NotificationHost：转发到 NotificationClient.info。
 */
import { NotificationClient } from '../Projects/Core/Notification/Application/NotificationClient';

export const NOTIFICATION_TOAST_KEY: string = 'app.notificationToast';

export class NotificationHost {
  private client?: NotificationClient;

  bindClient(client: NotificationClient): void {
    this.client = client;
  }

  showToast(text: string): void {
    if (this.client) {
      this.client.info(text, undefined, 'legacy.host');
      return;
    }
    try {
      AppStorage.setOrCreate(NOTIFICATION_TOAST_KEY, text ?? '');
    } catch (_e) {
      // ignore
    }
  }

  clear(): void {
    try {
      AppStorage.setOrCreate(NOTIFICATION_TOAST_KEY, '');
    } catch (_e) {
      // ignore
    }
  }

  get current(): string {
    return '';
  }
}

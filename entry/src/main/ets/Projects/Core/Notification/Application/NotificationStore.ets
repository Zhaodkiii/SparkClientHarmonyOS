import { NotificationMessage } from '../Domain/NotificationModels';

export const NOTIFICATION_TOAST_KEY: string = 'app.notification.currentToast';
export const NOTIFICATION_BANNER_KEY: string = 'app.notification.currentBanner';
export const NOTIFICATION_ALERT_KEY: string = 'app.notification.currentAlert';
/** 兼容旧底部 toast key */
export const NOTIFICATION_TOAST_LEGACY_KEY: string = 'app.notificationToast';

/**
 * 当前展示态；AppStorage 只存 JSON 摘要。
 */
export class NotificationStore {
  private currentToast?: NotificationMessage;
  private currentBanner?: NotificationMessage;
  private currentAlert?: NotificationMessage;
  private alertResolver?: () => void;

  get toast(): NotificationMessage | undefined {
    return this.currentToast;
  }

  get banner(): NotificationMessage | undefined {
    return this.currentBanner;
  }

  get alert(): NotificationMessage | undefined {
    return this.currentAlert;
  }

  present(message: NotificationMessage): void {
    if (message.presentation === 'toast') {
      this.currentToast = message;
      this.publishToast(message.toUiJson());
    } else if (message.presentation === 'banner') {
      this.currentBanner = message;
      this.publishBanner(message.toUiJson());
    } else {
      this.currentAlert = message;
      this.publishAlert(message.toUiJson());
    }
  }

  dismissToast(): void {
    this.currentToast = undefined;
    this.publishToast('');
  }

  dismissBanner(): void {
    this.currentBanner = undefined;
    this.publishBanner('');
  }

  dismissAlert(): void {
    this.currentAlert = undefined;
    this.publishAlert('');
    if (this.alertResolver) {
      const resolve = this.alertResolver;
      this.alertResolver = undefined;
      resolve();
    }
  }

  waitForAlertDismissal(): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      this.alertResolver = resolve;
    });
  }

  dismissAll(): void {
    this.dismissToast();
    this.dismissBanner();
    this.dismissAlert();
  }

  private publishToast(value: string): void {
    try {
      AppStorage.setOrCreate(NOTIFICATION_TOAST_KEY, value);
      AppStorage.setOrCreate(NOTIFICATION_TOAST_LEGACY_KEY, value.length > 0
        ? (NotificationMessage.fromUiJson(value)?.message ?? '')
        : '');
    } catch (_e) {
      // ignore
    }
  }

  private publishBanner(value: string): void {
    try {
      AppStorage.setOrCreate(NOTIFICATION_BANNER_KEY, value);
    } catch (_e) {
      // ignore
    }
  }

  private publishAlert(value: string): void {
    try {
      AppStorage.setOrCreate(NOTIFICATION_ALERT_KEY, value);
    } catch (_e) {
      // ignore
    }
  }
}

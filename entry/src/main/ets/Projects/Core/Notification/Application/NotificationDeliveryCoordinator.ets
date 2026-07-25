import { NotificationMessage } from '../Domain/NotificationModels';
import { NotificationQueue } from '../Infrastructure/NotificationQueue';
import { NotificationInboxStore } from '../Infrastructure/NotificationInboxStore';
import { NotificationMetricsStore } from '../Infrastructure/NotificationMetricsStore';
import { NotificationStore } from './NotificationStore';
import { ErrorLogger } from '../../../../Foundation/Logging/ErrorLogger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { promptAction } from '@kit.ArkUI';

/**
 * 串行消费队列；toast/banner 自动消失；alert 阻塞。
 */
export class NotificationDeliveryCoordinator {
  private readonly queue: NotificationQueue;
  private readonly store: NotificationStore;
  private readonly inbox: NotificationInboxStore;
  private readonly metrics: NotificationMetricsStore;
  private isConsuming: boolean = false;
  private toastTimer?: number;
  private bannerTimer?: number;
  private toastWaitResolve?: () => void;
  private bannerWaitResolve?: () => void;
  /** 测试可缩短时长 */
  toastDefaultMs: number = 2000;
  toastMinMs: number = 400;
  bannerDefaultMs: number = 2800;
  bannerMinMs: number = 600;

  constructor(
    queue: NotificationQueue,
    store: NotificationStore,
    inbox: NotificationInboxStore,
    metrics: NotificationMetricsStore
  ) {
    this.queue = queue;
    this.store = store;
    this.inbox = inbox;
    this.metrics = metrics;
  }

  startIfNeeded(): void {
    if (this.isConsuming) {
      return;
    }
    this.isConsuming = true;
    this.consumeLoop().catch((err: Object) => {
      ErrorLogger.log('notification.delivery_failed', LogModule.NOTIFICATION, err);
    }).finally(() => {
      this.isConsuming = false;
      if (this.queue.depth > 0) {
        this.startIfNeeded();
      }
    });
  }

  dismissCurrentBanner(triggerTap: boolean): void {
    const banner = this.store.banner;
    if (!banner) {
      return;
    }
    this.clearBannerTimer();
    this.store.dismissBanner();
    this.inbox.markDismissed(banner.id).catch(() => {
      // ignore
    });
    if (triggerTap) {
      const action = this.queue.takeTapAction(banner.id);
      if (action) {
        try {
          action();
        } catch (err) {
          ErrorLogger.log('notification.tap_failed', LogModule.NOTIFICATION, err as Object);
        }
      }
    } else {
      this.queue.clearTapAction(banner.id);
    }
    this.resolveBannerWait();
  }

  confirmAlert(): void {
    const alert = this.store.alert;
    if (!alert) {
      return;
    }
    this.store.dismissAlert();
    this.inbox.markDismissed(alert.id).catch(() => {
      // ignore
    });
  }

  reset(): void {
    this.clearToastTimer();
    this.clearBannerTimer();
    this.resolveToastWait();
    this.resolveBannerWait();
    this.store.dismissAll();
    this.queue.reset();
  }

  private async consumeLoop(): Promise<void> {
    while (true) {
      const message = this.queue.dequeue();
      if (!message) {
        break;
      }
      const now = Date.now();
      await this.inbox.markPresented(message.id, now);
      await this.metrics.recordDisplayed(now - message.enqueuedAtMs);
      this.store.present(message);

      if (message.presentation === 'toast') {
        await this.waitAutoDismiss(message, true);
        this.store.dismissToast();
        await this.inbox.markDismissed(message.id);
      } else if (message.presentation === 'banner') {
        await this.waitAutoDismiss(message, false);
        if (this.store.banner && this.store.banner.id === message.id) {
          this.store.dismissBanner();
          this.queue.clearTapAction(message.id);
          await this.inbox.markDismissed(message.id);
        }
      } else {
        await this.showAlertAndWait(message);
      }
    }
  }

  private waitAutoDismiss(message: NotificationMessage, isToast: boolean): Promise<void> {
    const configured = message.autoDismissAfterMs;
    let ms = configured !== undefined ? configured : (isToast ? this.toastDefaultMs : this.bannerDefaultMs);
    const min = isToast ? this.toastMinMs : this.bannerMinMs;
    if (ms < min) {
      ms = min;
    }
    return new Promise<void>((resolve: () => void) => {
      if (isToast) {
        this.toastWaitResolve = resolve;
      } else {
        this.bannerWaitResolve = resolve;
      }
      const timer = setTimeout(() => {
        if (isToast) {
          this.toastTimer = undefined;
          this.toastWaitResolve = undefined;
        } else {
          this.bannerTimer = undefined;
          this.bannerWaitResolve = undefined;
        }
        resolve();
      }, ms) as number;
      if (isToast) {
        this.clearToastTimer();
        this.toastTimer = timer;
      } else {
        this.clearBannerTimer();
        this.bannerTimer = timer;
      }
    });
  }

  private resolveToastWait(): void {
    if (this.toastWaitResolve) {
      const r = this.toastWaitResolve;
      this.toastWaitResolve = undefined;
      r();
    }
  }

  private resolveBannerWait(): void {
    if (this.bannerWaitResolve) {
      const r = this.bannerWaitResolve;
      this.bannerWaitResolve = undefined;
      r();
    }
  }

  private async showAlertAndWait(message: NotificationMessage): Promise<void> {
    const wait = this.store.waitForAlertDismissal();
    try {
      promptAction.showDialog({
        title: message.title && message.title.length > 0 ? message.title : '提示',
        message: message.message,
        buttons: [{ text: '确定', color: '#007DFF' }]
      }).then(() => {
        this.confirmAlert();
      }).catch(() => {
        this.confirmAlert();
      });
    } catch (_e) {
      // 无 UI 上下文时（单测）直接确认
      this.confirmAlert();
    }
    await wait;
  }

  private clearToastTimer(): void {
    if (this.toastTimer !== undefined) {
      clearTimeout(this.toastTimer);
      this.toastTimer = undefined;
    }
  }

  private clearBannerTimer(): void {
    if (this.bannerTimer !== undefined) {
      clearTimeout(this.bannerTimer);
      this.bannerTimer = undefined;
    }
  }
}

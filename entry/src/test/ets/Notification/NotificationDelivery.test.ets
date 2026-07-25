import { describe, it, expect } from '@ohos/hypium';
import { NotificationIntent } from '../../../main/ets/Projects/Core/Notification/Domain/NotificationModels';
import { NotificationInboxStore } from '../../../main/ets/Projects/Core/Notification/Infrastructure/NotificationInboxStore';
import { NotificationMetricsStore } from '../../../main/ets/Projects/Core/Notification/Infrastructure/NotificationMetricsStore';
import { NotificationQueue } from '../../../main/ets/Projects/Core/Notification/Infrastructure/NotificationQueue';
import { NotificationStore } from '../../../main/ets/Projects/Core/Notification/Application/NotificationStore';
import { NotificationDeliveryCoordinator } from '../../../main/ets/Projects/Core/Notification/Application/NotificationDeliveryCoordinator';
import { PublishNotificationUseCase } from '../../../main/ets/Projects/Core/Notification/Application/PublishNotificationUseCase';
import { DefaultNotificationClient } from '../../../main/ets/Projects/Core/Notification/Application/NotificationClient';

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(resolve, ms);
  });
}

export default function notificationDeliveryTest() {
  describe('NotificationDeliveryAndClient', () => {
    it('client_shortcuts_use_toast_or_banner_presentation', 0, async () => {
      const inbox = new NotificationInboxStore('', true);
      const metrics = new NotificationMetricsStore();
      const queue = new NotificationQueue(inbox, metrics);
      const store = new NotificationStore();
      const delivery = new NotificationDeliveryCoordinator(queue, store, inbox, metrics);
      delivery.toastDefaultMs = 400;
      delivery.toastMinMs = 400;
      delivery.bannerDefaultMs = 600;
      delivery.bannerMinMs = 600;
      const client = new DefaultNotificationClient(new PublishNotificationUseCase(queue, delivery));

      client.success('ok', undefined, 'unit');
      await sleep(50);
      expect(queue.depth + (store.toast ? 1 : 0) >= 1 || metrics.snapshot().enqueuedCount >= 1).assertTrue();
      await sleep(500);
      expect(metrics.snapshot().displayedCount >= 1).assertTrue();
    });

    it('serial_consume_two_toasts', 0, async () => {
      const inbox = new NotificationInboxStore('', true);
      const metrics = new NotificationMetricsStore();
      const queue = new NotificationQueue(inbox, metrics);
      const store = new NotificationStore();
      const delivery = new NotificationDeliveryCoordinator(queue, store, inbox, metrics);
      delivery.toastDefaultMs = 400;
      delivery.toastMinMs = 400;
      const useCase = new PublishNotificationUseCase(queue, delivery);

      const a = new NotificationIntent('a', 'info', 'toast', 't', undefined, 'ser-a');
      a.autoDismissAfterMs = 400;
      const b = new NotificationIntent('b', 'info', 'toast', 't', undefined, 'ser-b');
      b.autoDismissAfterMs = 400;
      await useCase.execute(a);
      await useCase.execute(b);
      await sleep(100);
      expect(metrics.snapshot().enqueuedCount).assertEqual(2);
      await sleep(1200);
      expect(metrics.snapshot().displayedCount).assertEqual(2);
      expect(store.toast === undefined).assertTrue();
    });

    it('error_shortcut_enqueues_banner', 0, async () => {
      const inbox = new NotificationInboxStore('', true);
      const metrics = new NotificationMetricsStore();
      const queue = new NotificationQueue(inbox, metrics);
      const store = new NotificationStore();
      const delivery = new NotificationDeliveryCoordinator(queue, store, inbox, metrics);
      delivery.bannerDefaultMs = 600;
      delivery.bannerMinMs = 600;
      const client = new DefaultNotificationClient(new PublishNotificationUseCase(queue, delivery));
      client.error('boom', undefined, 'unit');
      await sleep(80);
      const depthOrBanner = queue.depth > 0 || store.banner !== undefined;
      expect(depthOrBanner || metrics.snapshot().enqueuedCount === 1).assertTrue();
      await sleep(800);
      expect(metrics.snapshot().displayedCount).assertEqual(1);
    });
  });
}

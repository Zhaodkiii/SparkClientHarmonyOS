import { describe, it, expect } from '@ohos/hypium';
import { NotificationIntent } from '../../../main/ets/Projects/Core/Notification/Domain/NotificationModels';
import { NotificationInboxStore } from '../../../main/ets/Projects/Core/Notification/Infrastructure/NotificationInboxStore';
import { NotificationMetricsStore } from '../../../main/ets/Projects/Core/Notification/Infrastructure/NotificationMetricsStore';
import { NotificationQueue } from '../../../main/ets/Projects/Core/Notification/Infrastructure/NotificationQueue';

function makeQueue(): NotificationQueue {
  const inbox = new NotificationInboxStore('', true);
  const metrics = new NotificationMetricsStore();
  return new NotificationQueue(inbox, metrics);
}

export default function notificationQueueTest() {
  describe('NotificationQueue', () => {
    it('dedupe_within_2s_drops_duplicate_into_inbox', 0, async () => {
      const inbox = new NotificationInboxStore('', true);
      const metrics = new NotificationMetricsStore();
      const queue = new NotificationQueue(inbox, metrics);
      const intent = new NotificationIntent('same', 'info', 'toast', 'test', undefined, 'k1');
      const first = await queue.enqueue(intent);
      const second = await queue.enqueue(intent);
      expect(first.enqueued).assertTrue();
      expect(second.enqueued).assertFalse();
      expect(second.dropReason).assertEqual('duplicate');
      expect(queue.depth).assertEqual(1);
      expect(metrics.snapshot().droppedDuplicateCount).assertEqual(1);
      expect(inbox.count).assertEqual(2);
    });

    it('overflow_at_128_drops_and_records_inbox', 0, async () => {
      const inbox = new NotificationInboxStore('', true);
      const metrics = new NotificationMetricsStore();
      const queue = new NotificationQueue(inbox, metrics);
      for (let i = 0; i < 128; i++) {
        const r = await queue.enqueue(new NotificationIntent(`m${i}`, 'info', 'toast', 't', undefined, `k${i}`));
        expect(r.enqueued).assertTrue();
      }
      const overflow = await queue.enqueue(new NotificationIntent('overflow', 'info', 'toast', 't', undefined, 'kOverflow'));
      expect(overflow.enqueued).assertFalse();
      expect(overflow.dropReason).assertEqual('queueOverflow');
      expect(queue.depth).assertEqual(128);
      expect(metrics.snapshot().droppedOverflowCount).assertEqual(1);
      expect(inbox.count >= 129).assertTrue();
    });

    it('inbox_trims_to_500', 0, async () => {
      const inbox = new NotificationInboxStore('', true);
      const metrics = new NotificationMetricsStore();
      const queue = new NotificationQueue(inbox, metrics);
      for (let i = 0; i < 510; i++) {
        await queue.enqueue(new NotificationIntent(`m${i}`, 'info', 'toast', 't', undefined, `trim${i}`));
        queue.dequeue();
      }
      expect(inbox.count).assertEqual(500);
    });

    it('empty_message_not_enqueued', 0, async () => {
      const queue = makeQueue();
      const r = await queue.enqueue(new NotificationIntent('   ', 'info', 'toast', 't'));
      expect(r.enqueued).assertFalse();
      expect(queue.depth).assertEqual(0);
    });
  });
}

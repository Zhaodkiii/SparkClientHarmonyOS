import {
  NotificationDropReason,
  NotificationMetricsSnapshot
} from '../Domain/NotificationModels';

/**
 * 通知指标：仅内存，重启归零。
 */
export class NotificationMetricsStore {
  private enqueuedCount: number = 0;
  private displayedCount: number = 0;
  private droppedDuplicateCount: number = 0;
  private droppedOverflowCount: number = 0;
  private latencySumMs: number = 0;
  private latencySamples: number = 0;

  async recordEnqueued(): Promise<void> {
    this.enqueuedCount += 1;
  }

  async recordDisplayed(latencyMs: number): Promise<void> {
    this.displayedCount += 1;
    if (latencyMs >= 0) {
      this.latencySumMs += latencyMs;
      this.latencySamples += 1;
    }
  }

  async recordDropped(reason: NotificationDropReason): Promise<void> {
    if (reason === 'duplicate') {
      this.droppedDuplicateCount += 1;
    } else if (reason === 'queueOverflow') {
      this.droppedOverflowCount += 1;
    }
  }

  snapshot(): NotificationMetricsSnapshot {
    const s = new NotificationMetricsSnapshot();
    s.enqueuedCount = this.enqueuedCount;
    s.displayedCount = this.displayedCount;
    s.droppedDuplicateCount = this.droppedDuplicateCount;
    s.droppedOverflowCount = this.droppedOverflowCount;
    s.averageDisplayLatencyMs =
      this.latencySamples > 0 ? this.latencySumMs / this.latencySamples : 0;
    return s;
  }

  reset(): void {
    this.enqueuedCount = 0;
    this.displayedCount = 0;
    this.droppedDuplicateCount = 0;
    this.droppedOverflowCount = 0;
    this.latencySumMs = 0;
    this.latencySamples = 0;
  }
}

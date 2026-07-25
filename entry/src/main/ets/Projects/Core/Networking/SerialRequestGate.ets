import { QueuePriority, queuePriorityValue } from './SupportNetworkModels';

class QueuedJob {
  priority: QueuePriority;
  sequence: number;
  run: () => Promise<void>;

  constructor(priority: QueuePriority, sequence: number, run: () => Promise<void>) {
    this.priority = priority;
    this.sequence = sequence;
    this.run = run;
  }
}

class QueueState {
  isRunning: boolean = false;
  queue: QueuedJob[] = [];
}

/**
 * 按 serialKey 串行；不同 key 并行。同优先级 FIFO。
 */
export class SerialRequestGate {
  private states: Map<string, QueueState> = new Map();
  private nextSequence: number = 0;

  async enqueue<T>(serialKey: string, priority: QueuePriority, operation: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const job = new QueuedJob(priority, this.nextSequence++, async () => {
        try {
          const result = await operation();
          resolve(result);
        } catch (e) {
          reject(e);
        }
      });
      let state = this.states.get(serialKey);
      if (!state) {
        state = new QueueState();
        this.states.set(serialKey, state);
      }
      state.queue.push(job);
      if (!state.isRunning) {
        state.isRunning = true;
        this.runQueue(serialKey);
      }
    });
  }

  private async runQueue(serialKey: string): Promise<void> {
    while (true) {
      const state = this.states.get(serialKey);
      if (!state) {
        return;
      }
      if (state.queue.length === 0) {
        state.isRunning = false;
        return;
      }
      let bestIdx = 0;
      for (let i = 1; i < state.queue.length; i++) {
        const a = state.queue[i];
        const b = state.queue[bestIdx];
        const pa = queuePriorityValue(a.priority);
        const pb = queuePriorityValue(b.priority);
        if (pa < pb || (pa === pb && a.sequence < b.sequence)) {
          bestIdx = i;
        }
      }
      const next = state.queue.splice(bestIdx, 1)[0];
      await next.run();
    }
  }
}

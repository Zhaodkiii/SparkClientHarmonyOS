import { RetryConfig } from './SupportNetworkModels';

export class RetryAfterParser {
  static parseSeconds(headerValue: string | undefined, nowMs: number = Date.now()): number | undefined {
    if (!headerValue) {
      return undefined;
    }
    const trimmed = headerValue.trim();
    if (trimmed.length === 0) {
      return undefined;
    }
    const asNumber = Number(trimmed);
    if (!Number.isNaN(asNumber) && asNumber >= 0) {
      return asNumber;
    }
    const parsed = Date.parse(trimmed);
    if (!Number.isNaN(parsed)) {
      const delta = (parsed - nowMs) / 1000;
      return delta >= 0 ? delta : 0;
    }
    return undefined;
  }
}

export class RetryPolicy {
  readonly config: RetryConfig;

  constructor(config: RetryConfig = RetryConfig.defaultConfig()) {
    this.config = config;
  }

  shouldRetryStatus(statusCode: number | undefined): boolean {
    if (statusCode === undefined) {
      return false;
    }
    return this.config.retryableStatusCodes.indexOf(statusCode) >= 0;
  }

  shouldRetryTransport(): boolean {
    return this.config.isEnabled;
  }

  computeDelayMs(retryCount: number, retryAfterHeader: string | undefined): number {
    if (this.config.honorsRetryAfter) {
      const seconds = RetryAfterParser.parseSeconds(retryAfterHeader);
      if (seconds !== undefined) {
        return Math.floor(seconds * 1000);
      }
    }
    if (this.config.backoffIntervalsMs.length === 0) {
      return 0;
    }
    const idx = Math.min(retryCount, this.config.backoffIntervalsMs.length - 1);
    return this.config.backoffIntervalsMs[idx];
  }

  async sleepIfNeeded(retryCount: number, retryAfterHeader: string | undefined): Promise<void> {
    const delayMs = this.computeDelayMs(retryCount, retryAfterHeader);
    if (delayMs <= 0) {
      return;
    }
    await new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve();
      }, delayMs);
    });
  }
}

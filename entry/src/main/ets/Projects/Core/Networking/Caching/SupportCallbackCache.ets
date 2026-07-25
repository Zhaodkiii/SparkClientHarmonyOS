import { NetworkResponse } from '../SupportNetworkModels';
import { NetworkLogger } from '../../../../Foundation/Logging/NetworkLogger';

/**
 * GET in-flight Promise 合并；finally 必须删除。
 */
export class SupportCallbackCache {
  private inFlight: Map<string, Promise<NetworkResponse>> = new Map();
  private readonly logger: NetworkLogger;

  constructor(logger?: NetworkLogger) {
    this.logger = logger ?? new NetworkLogger();
  }

  async execute(
    key: string,
    operationName: string,
    factory: () => Promise<NetworkResponse>
  ): Promise<NetworkResponse> {
    const existing = this.inFlight.get(key);
    if (existing) {
      this.logger.debug(`CallbackCache HIT key=${key} operation=${operationName}`);
      return existing;
    }
    this.logger.debug(`CallbackCache MISS key=${key} operation=${operationName}`);
    const promise = factory().finally(() => {
      this.inFlight.delete(key);
    });
    this.inFlight.set(key, promise);
    return promise;
  }

  /** 测试辅助 */
  size(): number {
    return this.inFlight.size;
  }
}

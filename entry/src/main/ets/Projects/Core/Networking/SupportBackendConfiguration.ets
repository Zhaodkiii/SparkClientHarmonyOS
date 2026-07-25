import { NetworkLogger } from '../../../Foundation/Logging/NetworkLogger';
import { NetworkResponse } from './SupportNetworkModels';
import { SupportNetworkEngine } from './SupportNetworkEngine';
import { SupportCallbackCache } from './Caching/SupportCallbackCache';
import { DeviceCache } from './Caching/DeviceCache';
import { CacheableSupportNetworkOperation, SupportNetworkOperation } from './Operations/SupportNetworkOperation';
import { SupportAPIResponseDecoder } from './API/Common/SupportAPIResponseDecoder';

export class SupportBackendConfiguration {
  readonly engine: SupportNetworkEngine;
  readonly callbackCache: SupportCallbackCache;
  readonly deviceCache: DeviceCache;
  readonly logger: NetworkLogger;

  constructor(
    engine: SupportNetworkEngine,
    deviceCache: DeviceCache,
    callbackCache?: SupportCallbackCache,
    logger?: NetworkLogger
  ) {
    this.engine = engine;
    this.deviceCache = deviceCache;
    this.callbackCache = callbackCache ?? new SupportCallbackCache(logger);
    this.logger = logger ?? engine.networkLogger;
  }

  async execute(operation: SupportNetworkOperation): Promise<NetworkResponse> {
    this.logger.debug(
      `Backend execute api=${operation.apiName} operation=${operation.name} method=${operation.request.method} path=${operation.request.path}`
    );
    const key = operation.callbackCacheKey ??
      CacheableSupportNetworkOperation.getCallbackKey(
        operation.request,
        this.deviceCache.getAccountScope()
      );
    if (key) {
      return this.callbackCache.execute(key, operation.name, async () => {
        return operation.execute(this.engine);
      });
    }
    return operation.execute(this.engine);
  }

  async executeDecoded<T>(
    operation: SupportNetworkOperation,
    mapper: (data: Object | null) => T,
    wrapped: boolean = true
  ): Promise<T> {
    const response = await this.execute(operation);
    if (wrapped) {
      return SupportAPIResponseDecoder.decodeWrappedData(
        response,
        mapper,
        operation.request.strategy.requiresAuth
      );
    }
    return SupportAPIResponseDecoder.decodeDirect(response, (root: Object) => mapper(root));
  }
}

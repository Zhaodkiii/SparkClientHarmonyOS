import { NetworkRequest, NetworkResponse } from '../SupportNetworkModels';
import { SupportNetworkEngine } from '../SupportNetworkEngine';

export interface SupportNetworkOperation {
  name: string;
  apiName: string;
  request: NetworkRequest;
  callbackCacheKey?: string;
  execute(engine: SupportNetworkEngine): Promise<NetworkResponse>;
}

export class CacheableSupportNetworkOperation implements SupportNetworkOperation {
  name: string;
  apiName: string;
  request: NetworkRequest;
  callbackCacheKey?: string;

  constructor(name: string, apiName: string, request: NetworkRequest, callbackCacheKey?: string) {
    this.name = name;
    this.apiName = apiName;
    this.request = request;
    this.callbackCacheKey = callbackCacheKey;
  }

  async execute(engine: SupportNetworkEngine): Promise<NetworkResponse> {
    return engine.sendRaw(this.request);
  }

  static getCallbackKey(request: NetworkRequest, authScope: string): string | undefined {
    if (request.method !== 'GET') {
      return undefined;
    }
    const queryParts: string[] = [];
    const items = request.queryItems.slice().sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0);
    for (let i = 0; i < items.length; i++) {
      queryParts.push(`${items[i].name}=${items[i].value}`);
    }
    return `GET|${request.path}|${queryParts.join('&')}|${authScope}`;
  }
}

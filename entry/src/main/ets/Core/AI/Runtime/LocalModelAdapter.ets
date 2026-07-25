import { AIResolvedConfig, AIRuntimeResponse, AIRuntimeTextRequest } from '../Domain/AIConfigModels';
import { AIProviderAdapter } from './AIProviderAdapter';

/**
 * 本地 GGUF 适配器桩：未接入真实 engine 前返回明确错误。
 * sendStream 走基类默认合成（会发出 started → failed）。
 */
export class LocalModelAdapter extends AIProviderAdapter {
  readonly providerKind: string = 'local-gguf';

  cancel(_requestId: string): void {
    // no-op until engine supports stop()
  }

  async send(request: AIRuntimeTextRequest, config: AIResolvedConfig): Promise<AIRuntimeResponse> {
    const r = new AIRuntimeResponse();
    r.requestId = request.requestId;
    r.modelId = config.modelId;
    r.modelName = config.modelName;
    r.source = 'local';
    r.createdAt = new Date().toISOString();
    r.finishReason = 'error';
    r.errorCode = 'localEngineUnavailable';
    r.errorMessage = 'GGUF engine not enabled on HarmonyOS yet';
    r.isDegraded = true;
    return r;
  }

  async healthCheck(): Promise<boolean> {
    return false;
  }
}

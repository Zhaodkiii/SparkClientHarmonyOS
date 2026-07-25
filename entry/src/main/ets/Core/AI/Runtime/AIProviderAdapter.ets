import {
  AIResolvedConfig,
  AIRuntimeEvent,
  AIRuntimeEventHandler,
  AIRuntimeResponse,
  AIRuntimeTextRequest
} from '../Domain/AIConfigModels';

/**
 * 对齐 iOS AIRuntimeGateway：统一远程/本地适配器协议。
 */
export abstract class AIProviderAdapter {
  abstract readonly providerKind: string;

  /** 非流式一次性完成 */
  abstract send(request: AIRuntimeTextRequest, config: AIResolvedConfig): Promise<AIRuntimeResponse>;

  /**
   * 流式发送：通过 onEvent 推送增量，最终 Promise resolve 为 completed/失败响应。
   * 默认回退为 send + 合成 textDelta/completed（子类可覆盖为真 SSE）。
   */
  async sendStream(
    request: AIRuntimeTextRequest,
    config: AIResolvedConfig,
    onEvent: AIRuntimeEventHandler
  ): Promise<AIRuntimeResponse> {
    const started = new AIRuntimeEvent();
    started.kind = 'started';
    started.requestId = request.requestId;
    onEvent(started);

    const response = await this.send(request, config);
    if (response.errorCode) {
      const failed = new AIRuntimeEvent();
      failed.kind = response.errorCode === 'cancelled' ? 'cancelled' : 'failed';
      failed.requestId = request.requestId;
      failed.errorCode = response.errorCode;
      failed.errorMessage = response.errorMessage;
      failed.response = response;
      onEvent(failed);
      return response;
    }
    if (response.text.length > 0) {
      const delta = new AIRuntimeEvent();
      delta.kind = 'textDelta';
      delta.requestId = request.requestId;
      delta.deltaText = response.text;
      onEvent(delta);
    }
    if (response.reasoningText && response.reasoningText.length > 0) {
      const rd = new AIRuntimeEvent();
      rd.kind = 'reasoningDelta';
      rd.requestId = request.requestId;
      rd.reasoningDelta = response.reasoningText;
      onEvent(rd);
    }
    const completed = new AIRuntimeEvent();
    completed.kind = 'completed';
    completed.requestId = request.requestId;
    completed.response = response;
    onEvent(completed);
    return response;
  }

  abstract cancel(requestId: string): void;

  async healthCheck(): Promise<boolean> {
    return true;
  }
}

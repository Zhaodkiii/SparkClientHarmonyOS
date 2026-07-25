/**
 * Runtime 可分类错误（对齐 iOS AIRuntimeError / AIConfigError 语义）。
 * 禁止把原始 Exception.toString / API Key / 完整 body 暴露给 UI。
 */
export class AIRuntimeErrorCodes {
  static readonly EMPTY_MESSAGES: string = 'emptyMessages';
  static readonly EMPTY_OUTPUT: string = 'emptyOutput';
  static readonly INVALID_RESPONSE: string = 'invalidResponse';
  static readonly TRANSPORT: string = 'transport';
  static readonly SERVER: string = 'server';
  static readonly CANCELLED: string = 'cancelled';
  static readonly NO_AVAILABLE_MODEL: string = 'noAvailableModel';
  static readonly CAPABILITY_DENIED: string = 'capabilityDenied';
  static readonly SESSION_INVALIDATED: string = 'sessionInvalidated';
  static readonly LOCAL_ENGINE_UNAVAILABLE: string = 'localEngineUnavailable';
  static readonly PROVIDER_ERROR: string = 'providerError';
  static readonly HTTP_ERROR: string = 'httpError';
  static readonly ACCOUNT_REQUIRED: string = 'accountRequired';
  static readonly INVALID_ROLE: string = 'invalidRole';
  static readonly INVALID_TOOL_CHOICE: string = 'invalidToolChoice';
}

export class AIRuntimeError extends Error {
  code: string;
  userMessage: string;
  httpStatus?: number;
  serverCode?: string;
  serverRequestId?: string;

  constructor(code: string, userMessage: string) {
    super(userMessage);
    this.name = 'AIRuntimeError';
    this.code = code;
    this.userMessage = userMessage;
  }

  static cancelled(): AIRuntimeError {
    return new AIRuntimeError(AIRuntimeErrorCodes.CANCELLED, '已取消');
  }

  static emptyMessages(): AIRuntimeError {
    return new AIRuntimeError(AIRuntimeErrorCodes.EMPTY_MESSAGES, '消息为空');
  }

  static emptyOutput(): AIRuntimeError {
    return new AIRuntimeError(AIRuntimeErrorCodes.EMPTY_OUTPUT, '模型未返回可用内容');
  }

  static accountRequired(): AIRuntimeError {
    return new AIRuntimeError(AIRuntimeErrorCodes.ACCOUNT_REQUIRED, '请先登录后再使用 AI');
  }

  static noModel(scenario: string): AIRuntimeError {
    return new AIRuntimeError(AIRuntimeErrorCodes.NO_AVAILABLE_MODEL, `场景 ${scenario} 无可用模型`);
  }

  static http(status: number, detail?: string): AIRuntimeError {
    const e = new AIRuntimeError(AIRuntimeErrorCodes.HTTP_ERROR, detail && detail.length > 0 ? detail : `服务异常(${status})`);
    e.httpStatus = status;
    return e;
  }

  static server(message: string, code?: string, requestId?: string): AIRuntimeError {
    const e = new AIRuntimeError(AIRuntimeErrorCodes.SERVER, message.length > 0 ? message : '服务端业务失败');
    e.serverCode = code;
    e.serverRequestId = requestId;
    return e;
  }

  /** 日志用短摘要，不含密钥与全文 */
  logSummary(): string {
    let s = `code=${this.code}`;
    if (this.httpStatus !== undefined) {
      s += ` http=${this.httpStatus}`;
    }
    if (this.serverCode) {
      s += ` serverCode=${this.serverCode}`;
    }
    if (this.serverRequestId) {
      s += ` rid=${this.serverRequestId}`;
    }
    return s;
  }
}

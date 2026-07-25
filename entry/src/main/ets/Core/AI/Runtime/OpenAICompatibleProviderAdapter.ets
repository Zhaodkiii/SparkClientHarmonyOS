import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import {
  AIResolvedConfig,
  AIRuntimeEvent,
  AIRuntimeEventHandler,
  AIRuntimeResponse,
  AIRuntimeTextRequest,
  AIRuntimeToolCall,
  AIRuntimeUsage
} from '../Domain/AIConfigModels';
import { OpenAIChatBodyEncoder } from '../Domain/OpenAIChatBodyEncoder';
import { AIRuntimeSseParser } from '../Domain/AIRuntimeSseParser';
import { AIRuntimeError, AIRuntimeErrorCodes } from '../Domain/AIRuntimeErrors';
import { AIProviderAdapter } from './AIProviderAdapter';
import { AIKeyStore } from '../Infrastructure/AIKeyStore';
import { AIRuntimeCancellationToken, AIRuntimeCancelledError } from './AIRuntimeCancellation';

class ActiveHttpRequest {
  requestId: string = '';
  httpRequest: http.HttpRequest = http.createHttp();
}

/**
 * OpenAI 兼容 Chat Completions。
 * body 由 OpenAIChatBodyEncoder；SSE 由 AIRuntimeSseParser；HTTP 生命周期参考 FileCacheManager。
 * 同一 requestId 只允许一个终态事件。
 */
export class OpenAICompatibleProviderAdapter extends AIProviderAdapter {
  readonly providerKind: string = 'openai-compatible';
  private readonly keys: AIKeyStore;
  private readonly active: Map<string, ActiveHttpRequest> = new Map();
  private readonly softCancelled: Set<string> = new Set();
  private readonly terminalEmitted: Set<string> = new Set();

  constructor(keys: AIKeyStore) {
    super();
    this.keys = keys;
  }

  cancel(requestId: string): void {
    this.softCancelled.add(requestId);
    const active = this.active.get(requestId);
    if (active) {
      try {
        active.httpRequest.destroy();
      } catch (_e) {
        // ignore
      }
      this.active.delete(requestId);
    }
  }

  async send(request: AIRuntimeTextRequest, config: AIResolvedConfig): Promise<AIRuntimeResponse> {
    return this.execute(request, config, false, (_e: AIRuntimeEvent) => {
    });
  }

  async sendStream(
    request: AIRuntimeTextRequest,
    config: AIResolvedConfig,
    onEvent: AIRuntimeEventHandler
  ): Promise<AIRuntimeResponse> {
    this.emitOnce(request.requestId, onEvent, () => {
      const started = new AIRuntimeEvent();
      started.kind = 'started';
      started.requestId = request.requestId;
      return started;
    }, false);
    return this.execute(request, config, true, onEvent);
  }

  private async execute(
    request: AIRuntimeTextRequest,
    config: AIResolvedConfig,
    stream: boolean,
    onEvent: AIRuntimeEventHandler
  ): Promise<AIRuntimeResponse> {
    const response = new AIRuntimeResponse();
    response.requestId = request.requestId;
    response.modelId = config.modelId;
    response.modelName = config.modelName;
    response.source = config.source;
    response.createdAt = new Date().toISOString();

    if (!config.endpoint || config.endpoint.length === 0) {
      response.errorCode = 'noEndpoint';
      response.errorMessage = 'endpoint missing';
      response.finishReason = 'error';
      this.emitTerminal(onEvent, request.requestId, 'failed', response);
      return response;
    }

    try {
      this.checkToken(request);
    } catch (_e) {
      response.errorCode = AIRuntimeErrorCodes.CANCELLED;
      response.finishReason = 'cancelled';
      this.emitTerminal(onEvent, request.requestId, 'cancelled', response);
      return response;
    }

    let apiKey = '';
    if (config.secretRef) {
      apiKey = (await this.keys.get(config.secretRef)) ?? '';
    }

    let body: Record<string, Object | string | number | boolean | Object[] | null>;
    try {
      body = OpenAIChatBodyEncoder.encode(request, config, stream);
    } catch (err) {
      response.errorCode = AIRuntimeErrorCodes.INVALID_RESPONSE;
      response.errorMessage = err instanceof AIRuntimeError ? err.userMessage : 'request encode failed';
      response.finishReason = 'error';
      this.emitTerminal(onEvent, request.requestId, 'failed', response);
      return response;
    }

    const headers: Record<string, string> = {};
    headers['Content-Type'] = 'application/json';
    if (apiKey.length > 0) {
      headers['Authorization'] = `Bearer ${apiKey}`;
    }

    const httpRequest = http.createHttp();
    const active = new ActiveHttpRequest();
    active.requestId = request.requestId;
    active.httpRequest = httpRequest;
    this.active.set(request.requestId, active);
    const endpoint = config.endpoint;

    try {
      if (stream) {
        return await this.executeStream(request, endpoint, httpRequest, headers, body, response, onEvent);
      }
      return await this.executeOnce(request, endpoint, httpRequest, headers, body, response, onEvent);
    } catch (err) {
      if (err instanceof AIRuntimeCancelledError || this.softCancelled.has(request.requestId)) {
        response.errorCode = AIRuntimeErrorCodes.CANCELLED;
        response.finishReason = 'cancelled';
        this.emitTerminal(onEvent, request.requestId, 'cancelled', response);
        return response;
      }
      if (err instanceof AIRuntimeError) {
        response.errorCode = err.code;
        response.errorMessage = err.userMessage;
        response.finishReason = 'error';
        this.emitTerminal(onEvent, request.requestId, 'failed', response);
        return response;
      }
      response.errorCode = AIRuntimeErrorCodes.PROVIDER_ERROR;
      response.errorMessage = 'provider error';
      response.finishReason = 'error';
      this.emitTerminal(onEvent, request.requestId, 'failed', response);
      return response;
    } finally {
      this.active.delete(request.requestId);
      this.softCancelled.delete(request.requestId);
      this.terminalEmitted.delete(request.requestId);
      try {
        httpRequest.off('headersReceive');
        httpRequest.off('dataReceive');
        httpRequest.off('dataEnd');
        httpRequest.destroy();
      } catch (_e) {
        // ignore
      }
    }
  }

  private async executeOnce(
    request: AIRuntimeTextRequest,
    endpoint: string,
    httpRequest: http.HttpRequest,
    headers: Record<string, string>,
    body: Record<string, Object | string | number | boolean | Object[] | null>,
    response: AIRuntimeResponse,
    onEvent: AIRuntimeEventHandler
  ): Promise<AIRuntimeResponse> {
    const result = await httpRequest.request(endpoint, {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: JSON.stringify(body),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: request.timeoutMs,
      readTimeout: request.timeoutMs
    });
    this.checkToken(request);
    if (this.softCancelled.has(request.requestId)) {
      response.errorCode = AIRuntimeErrorCodes.CANCELLED;
      response.finishReason = 'cancelled';
      this.emitTerminal(onEvent, request.requestId, 'cancelled', response);
      return response;
    }
    const textBody = `${result.result ?? ''}`;
    if (result.responseCode < 200 || result.responseCode >= 300) {
      const parsedErr = OpenAICompatibleProviderAdapter.parseProviderError(textBody, result.responseCode);
      response.errorCode = parsedErr.code;
      response.errorMessage = parsedErr.userMessage;
      response.finishReason = 'error';
      this.emitTerminal(onEvent, request.requestId, 'failed', response);
      return response;
    }
    this.parseNonStreamBody(textBody, response);
    this.emitTerminal(onEvent, request.requestId, 'completed', response);
    return response;
  }

  private async executeStream(
    request: AIRuntimeTextRequest,
    endpoint: string,
    httpRequest: http.HttpRequest,
    headers: Record<string, string>,
    body: Record<string, Object | string | number | boolean | Object[] | null>,
    response: AIRuntimeResponse,
    onEvent: AIRuntimeEventHandler
  ): Promise<AIRuntimeResponse> {
    let buffer = '';
    let textAcc = '';
    let reasoningAcc = '';
    let finishReason = 'stop';
    const toolCallsByIndex: Map<number, AIRuntimeToolCall> = new Map();
    let aborted = false;
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });

    await new Promise<void>((resolve, reject) => {
      const fail = (err: Object): void => {
        if (aborted) {
          return;
        }
        aborted = true;
        reject(err);
      };

      httpRequest.on('dataReceive', (data: ArrayBuffer) => {
        if (aborted || this.softCancelled.has(request.requestId)) {
          return;
        }
        try {
          this.checkToken(request);
          const chunk = decoder.decodeToString(new Uint8Array(data));
          buffer += chunk;
          const lines = buffer.split('\n');
          buffer = lines.length > 0 ? lines[lines.length - 1] : '';
          const completeCount = lines.length - 1;
          for (let i = 0; i < completeCount; i++) {
            const parse = AIRuntimeSseParser.consumeLine(lines[i], toolCallsByIndex);
            if (parse.errorMessage) {
              fail(AIRuntimeError.server(parse.errorMessage, parse.errorCode));
              return;
            }
            if (parse.finishReason.length > 0) {
              finishReason = parse.finishReason;
            }
            if (parse.textDelta.length > 0) {
              textAcc += parse.textDelta;
            }
            if (parse.reasoningDelta.length > 0) {
              reasoningAcc += parse.reasoningDelta;
            }
            AIRuntimeSseParser.emitParseEvents(request.requestId, parse, onEvent);
          }
        } catch (err) {
          fail(err as Object);
        }
      });

      httpRequest.on('dataEnd', () => {
        // settle via requestInStream
      });

      httpRequest.requestInStream(endpoint, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(body),
        connectTimeout: request.timeoutMs,
        readTimeout: Math.max(request.timeoutMs, 300000)
      }).then((code: number) => {
        if (aborted) {
          return;
        }
        if (this.softCancelled.has(request.requestId)) {
          fail(new AIRuntimeCancelledError());
          return;
        }
        if (code < 200 || code >= 300) {
          fail(AIRuntimeError.http(code));
          return;
        }
        if (buffer.length > 0) {
          const parse = AIRuntimeSseParser.consumeLine(buffer, toolCallsByIndex);
          if (parse.errorMessage) {
            fail(AIRuntimeError.server(parse.errorMessage, parse.errorCode));
            return;
          }
          if (parse.finishReason.length > 0) {
            finishReason = parse.finishReason;
          }
          if (parse.textDelta.length > 0) {
            textAcc += parse.textDelta;
          }
          if (parse.reasoningDelta.length > 0) {
            reasoningAcc += parse.reasoningDelta;
          }
          AIRuntimeSseParser.emitParseEvents(request.requestId, parse, onEvent);
          buffer = '';
        }
        resolve();
      }).catch((err: Object) => {
        if (aborted) {
          return;
        }
        if (this.softCancelled.has(request.requestId)) {
          fail(new AIRuntimeCancelledError());
        } else {
          fail(err);
        }
      });
    });

    response.text = textAcc;
    response.reasoningText = reasoningAcc.length > 0 ? reasoningAcc : undefined;
    response.toolCalls = AIRuntimeSseParser.mapToolCalls(toolCallsByIndex);
    if (response.hasToolCalls) {
      response.finishReason = 'tool_calls';
    } else {
      response.finishReason = finishReason.length > 0 ? finishReason : 'stop';
    }
    this.emitTerminal(onEvent, request.requestId, 'completed', response);
    return response;
  }

  private parseNonStreamBody(textBody: string, response: AIRuntimeResponse): void {
    const parsed = JSON.parse(textBody) as Record<string, Object>;
    const codeVal = parsed['code'];
    if (codeVal !== undefined && typeof codeVal === 'number' && (codeVal as number) !== 0) {
      throw AIRuntimeError.server(`${parsed['msg'] ?? parsed['message'] ?? 'server error'}`, `${codeVal}`);
    }
    const dataObj = parsed['data'];
    const root = (dataObj !== undefined && typeof dataObj === 'object')
      ? dataObj as Record<string, Object>
      : parsed;
    const choices = root['choices'] as Object[] | undefined;
    if (choices && choices.length > 0) {
      const choice = choices[0] as Record<string, Object>;
      const msg = choice['message'] as Record<string, Object> | undefined;
      if (msg) {
        if (msg['content'] !== undefined) {
          response.text = `${msg['content']}`;
        }
        if (msg['reasoning_content'] !== undefined) {
          response.reasoningText = `${msg['reasoning_content']}`;
        } else if (msg['reasoning'] !== undefined) {
          response.reasoningText = `${msg['reasoning']}`;
        }
        const toolCalls = msg['tool_calls'] as Object[] | undefined;
        if (toolCalls) {
          const mapped: AIRuntimeToolCall[] = [];
          for (let i = 0; i < toolCalls.length; i++) {
            const tc = toolCalls[i] as Record<string, Object>;
            const call = new AIRuntimeToolCall();
            call.id = `${tc['id'] ?? ''}`;
            const fn = tc['function'] as Record<string, Object> | undefined;
            call.name = fn ? `${fn['name'] ?? ''}` : '';
            call.arguments = fn ? `${fn['arguments'] ?? ''}` : '';
            mapped.push(call);
          }
          response.toolCalls = mapped;
        }
      }
      response.finishReason = `${choice['finish_reason'] ?? 'stop'}`;
    }
    const usage = root['usage'] as Record<string, number> | undefined;
    if (usage) {
      const u = new AIRuntimeUsage();
      u.promptTokens = usage['prompt_tokens'] ?? 0;
      u.completionTokens = usage['completion_tokens'] ?? 0;
      u.totalTokens = usage['total_tokens'] ?? 0;
      response.usage = u;
    }
  }

  private static parseProviderError(textBody: string, status: number): AIRuntimeError {
    try {
      const parsed = JSON.parse(textBody) as Record<string, Object>;
      const errObj = parsed['error'];
      if (errObj !== undefined && typeof errObj === 'object') {
        const e = errObj as Record<string, Object>;
        return AIRuntimeError.server(`${e['message'] ?? 'http error'}`, `${e['code'] ?? status}`);
      }
      if (parsed['msg'] !== undefined || parsed['message'] !== undefined) {
        return AIRuntimeError.server(`${parsed['msg'] ?? parsed['message']}`, `${parsed['code'] ?? status}`);
      }
    } catch (_e) {
      // fallthrough
    }
    return AIRuntimeError.http(status);
  }

  private checkToken(request: AIRuntimeTextRequest): void {
    const token = request.cancellationToken;
    if (token instanceof AIRuntimeCancellationToken) {
      token.checkCancellation();
    }
  }

  private emitOnce(
    requestId: string,
    onEvent: AIRuntimeEventHandler,
    factory: () => AIRuntimeEvent,
    isTerminal: boolean
  ): void {
    if (isTerminal && this.terminalEmitted.has(requestId)) {
      return;
    }
    if (isTerminal) {
      this.terminalEmitted.add(requestId);
    }
    onEvent(factory());
  }

  private emitTerminal(
    onEvent: AIRuntimeEventHandler,
    requestId: string,
    kind: 'completed' | 'failed' | 'cancelled',
    response: AIRuntimeResponse
  ): void {
    this.emitOnce(requestId, onEvent, () => {
      const ev = new AIRuntimeEvent();
      ev.kind = kind;
      ev.requestId = requestId;
      ev.response = response;
      ev.errorCode = response.errorCode;
      ev.errorMessage = response.errorMessage;
      return ev;
    }, true);
  }
}

import {
  AIResolvedConfig,
  AIRuntimeEvent,
  AIRuntimeEventHandler,
  AIRuntimeResponse,
  AIRuntimeTextRequest,
  RuntimeSnapshot
} from '../Domain/AIConfigModels';
import { AIRuntimeErrorCodes } from '../Domain/AIRuntimeErrors';
import { AIRuntimeMappers } from '../Domain/AIRuntimeMappers';
import { ScenarioPolicyResolver } from '../Application/ScenarioPolicyResolver';
import { AIRuntimeSnapshotStore } from './AIRuntimeSnapshotStore';
import { AIKeyStore } from '../Infrastructure/AIKeyStore';
import { AIProviderAdapter } from './AIProviderAdapter';
import { OpenAICompatibleProviderAdapter } from './OpenAICompatibleProviderAdapter';
import { LocalModelAdapter } from './LocalModelAdapter';
import { AccountSessionRuntime } from '../../../App/AccountSessionRuntime';
import { Logger } from '../../../Foundation/Logging/Logger';
import { LogModule } from '../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../Foundation/Logging/LogEvent';
import { AIRuntimeCancellationToken, AIRuntimeCancelledError } from './AIRuntimeCancellation';
import { AIRuntimeOutputLog } from './AIRuntimeOutputLog';

/**
 * 统一文本消费入口（对齐 iOS AIRuntimeService）。
 * Feature / Orchestrator 只提交 AIRuntimeTextRequest，不得直连厂商 HTTP。
 */
export class AIRuntimeService {
  private readonly snapshotStore: AIRuntimeSnapshotStore;
  private readonly keys: AIKeyStore;
  private readonly session: AccountSessionRuntime;
  private readonly remoteAdapter: AIProviderAdapter;
  private readonly localAdapter: AIProviderAdapter;
  private readonly activeRequests: Map<string, boolean> = new Map();

  constructor(
    snapshotStore: AIRuntimeSnapshotStore,
    keys: AIKeyStore,
    session: AccountSessionRuntime,
    remoteAdapter?: AIProviderAdapter,
    localAdapter?: AIProviderAdapter
  ) {
    this.snapshotStore = snapshotStore;
    this.keys = keys;
    this.session = session;
    this.remoteAdapter = remoteAdapter ?? new OpenAICompatibleProviderAdapter(keys);
    this.localAdapter = localAdapter ?? new LocalModelAdapter();
  }

  cancel(requestId: string): void {
    this.activeRequests.delete(requestId);
    this.remoteAdapter.cancel(requestId);
    this.localAdapter.cancel(requestId);
  }

  /** 取消全部 in-flight（登出/切号） */
  cancelAll(): void {
    const ids: string[] = [];
    this.activeRequests.forEach((_v: boolean, k: string) => {
      ids.push(k);
    });
    for (let i = 0; i < ids.length; i++) {
      this.cancel(ids[i]);
    }
  }

  invalidateAccount(accountId: number): void {
    this.cancelAll();
    this.snapshotStore.invalidate(accountId);
  }

  /** 非流式便捷封装 */
  async generateText(request: AIRuntimeTextRequest): Promise<AIRuntimeResponse> {
    let last: AIRuntimeResponse | undefined = undefined;
    await this.generateTextStream(request, (ev: AIRuntimeEvent) => {
      if (ev.response) {
        last = ev.response;
      }
    });
    if (last) {
      return last;
    }
    return AIRuntimeService.fail(request.requestId, 'providerError', 'no response');
  }

  /**
   * 主路径：流式推理。事件序 started → textDelta/reasoningDelta/toolCall* → completed|failed|cancelled
   */
  async generateTextStream(
    request: AIRuntimeTextRequest,
    onEvent: AIRuntimeEventHandler
  ): Promise<AIRuntimeResponse> {
    if (!request.requestId) {
      request.requestId = `req_${Date.now()}`;
    }
    const accountId = request.accountId || this.session.activeAccountId || 0;
    request.accountId = accountId;
    if (accountId <= 0) {
      const failed = AIRuntimeService.fail(request.requestId, AIRuntimeErrorCodes.ACCOUNT_REQUIRED, 'account required');
      const ev = new AIRuntimeEvent();
      ev.kind = 'failed';
      ev.requestId = request.requestId;
      ev.errorCode = failed.errorCode;
      ev.errorMessage = failed.errorMessage;
      ev.response = failed;
      onEvent(ev);
      return failed;
    }

    const snapAtStart = this.snapshotStore.get(accountId);
    const generationAtStart = snapAtStart?.generation ?? 0;

    try {
      AIRuntimeService.checkToken(request);
    } catch (_e) {
      const cancelled = AIRuntimeService.fail(request.requestId, AIRuntimeErrorCodes.CANCELLED, 'cancelled');
      cancelled.finishReason = 'cancelled';
      const ev = new AIRuntimeEvent();
      ev.kind = 'cancelled';
      ev.requestId = request.requestId;
      ev.response = cancelled;
      ev.errorCode = AIRuntimeErrorCodes.CANCELLED;
      onEvent(ev);
      return cancelled;
    }

    if (request.messages.length === 0) {
      const empty = AIRuntimeService.fail(request.requestId, AIRuntimeErrorCodes.EMPTY_MESSAGES, 'messages empty');
      const ev = new AIRuntimeEvent();
      ev.kind = 'failed';
      ev.requestId = request.requestId;
      ev.errorCode = empty.errorCode;
      ev.errorMessage = empty.errorMessage;
      ev.response = empty;
      onEvent(ev);
      return empty;
    }

    const snap = this.snapshotStore.get(accountId);
    if (!snap || snap.state === 'invalidated' || snap.state === 'empty' || snap.state === 'uninitialized') {
      const failed = AIRuntimeService.fail(request.requestId, AIRuntimeErrorCodes.SESSION_INVALIDATED, 'runtime not ready');
      const ev = new AIRuntimeEvent();
      ev.kind = 'failed';
      ev.requestId = request.requestId;
      ev.errorCode = failed.errorCode;
      ev.errorMessage = failed.errorMessage;
      ev.response = failed;
      onEvent(ev);
      return failed;
    }
    if (snap.generation !== generationAtStart) {
      const failed = AIRuntimeService.fail(request.requestId, AIRuntimeErrorCodes.SESSION_INVALIDATED, 'generation stale');
      const ev = new AIRuntimeEvent();
      ev.kind = 'failed';
      ev.requestId = request.requestId;
      ev.errorCode = failed.errorCode;
      ev.errorMessage = failed.errorMessage;
      ev.response = failed;
      onEvent(ev);
      return failed;
    }

    const resolved = AIRuntimeService.pickResolved(snap, request);
    if (!resolved) {
      const failed = AIRuntimeService.fail(
        request.requestId,
        'noAvailableModel',
        `no model for ${request.scenario}`
      );
      const ev = new AIRuntimeEvent();
      ev.kind = 'failed';
      ev.requestId = request.requestId;
      ev.errorCode = failed.errorCode;
      ev.errorMessage = failed.errorMessage;
      ev.response = failed;
      onEvent(ev);
      return failed;
    }

    if (!resolved.capabilities.supportsText) {
      const failed = AIRuntimeService.fail(request.requestId, 'capabilityDenied', 'supportsText=false');
      const ev = new AIRuntimeEvent();
      ev.kind = 'failed';
      ev.requestId = request.requestId;
      ev.errorCode = failed.errorCode;
      ev.errorMessage = failed.errorMessage;
      ev.response = failed;
      onEvent(ev);
      return failed;
    }

    if (request.preferredSource === 'multimodal' && !resolved.capabilities.supportsMultimodal) {
      const failed = AIRuntimeService.fail(request.requestId, 'capabilityDenied', 'supportsMultimodal=false');
      const ev = new AIRuntimeEvent();
      ev.kind = 'failed';
      ev.requestId = request.requestId;
      ev.errorCode = failed.errorCode;
      ev.errorMessage = failed.errorMessage;
      ev.response = failed;
      onEvent(ev);
      return failed;
    }

    const effective = AIRuntimeService.applyToolsDegrade(request, resolved);
    try {
      effective.toolChoice = AIRuntimeMappers.normalizeToolChoice(
        effective.toolChoice,
        effective.tools.length > 0
      );
    } catch (_e) {
      effective.toolChoice = 'none';
      effective.tools = [];
    }
    if (!effective.providerCompanyUppercased || effective.providerCompanyUppercased.length === 0) {
      effective.providerCompanyUppercased = resolved.company;
    }

    this.activeRequests.set(request.requestId, true);
    const fields = new LogFields();
    fields.detail =
      `准备推理 scenario=${effective.scenario} source=${resolved.source} model=${resolved.modelName}` +
      ` messages=${effective.messages.length} tools=${effective.tools.length} gen=${generationAtStart}`;
    Logger.debug('ai.runtime.begin', LogModule.AI_CONFIG, fields);

    try {
      AIRuntimeService.checkToken(effective);
      const snapNow = this.snapshotStore.get(accountId);
      if (!snapNow || snapNow.generation !== generationAtStart || snapNow.state === 'invalidated') {
        const failed = AIRuntimeService.fail(request.requestId, AIRuntimeErrorCodes.SESSION_INVALIDATED, 'generation stale');
        const ev = new AIRuntimeEvent();
        ev.kind = 'failed';
        ev.requestId = request.requestId;
        ev.errorCode = failed.errorCode;
        ev.errorMessage = failed.errorMessage;
        ev.response = failed;
        onEvent(ev);
        return failed;
      }
      const adapter = resolved.modelType === 'gguf' ? this.localAdapter : this.remoteAdapter;
      const response = await adapter.sendStream(effective, resolved, onEvent);
      if (!response.errorCode) {
        AIRuntimeOutputLog.recordFinalModelOutput(
          effective.scenario,
          resolved.source,
          response,
          resolved.modelName
        );
      }
      return response;
    } catch (err) {
      if (err instanceof AIRuntimeCancelledError) {
        const cancelled = AIRuntimeService.fail(request.requestId, AIRuntimeErrorCodes.CANCELLED, 'cancelled');
        cancelled.finishReason = 'cancelled';
        const ev = new AIRuntimeEvent();
        ev.kind = 'cancelled';
        ev.requestId = request.requestId;
        ev.response = cancelled;
        ev.errorCode = AIRuntimeErrorCodes.CANCELLED;
        onEvent(ev);
        return cancelled;
      }
      const warn = new LogFields();
      warn.detail = `推理失败 code=providerError requestId=${request.requestId}`;
      Logger.warn('ai.runtime.failed', LogModule.AI_CONFIG, warn);
      const failed = AIRuntimeService.fail(request.requestId, AIRuntimeErrorCodes.PROVIDER_ERROR, 'provider error');
      const ev = new AIRuntimeEvent();
      ev.kind = 'failed';
      ev.requestId = request.requestId;
      ev.errorCode = failed.errorCode;
      ev.errorMessage = failed.errorMessage;
      ev.response = failed;
      onEvent(ev);
      return failed;
    } finally {
      this.activeRequests.delete(request.requestId);
    }
  }

  /** @deprecated 使用 generateTextStream；保留兼容旧单测合成事件 */
  async collectEvents(request: AIRuntimeTextRequest): Promise<AIRuntimeEvent[]> {
    const events: AIRuntimeEvent[] = [];
    await this.generateTextStream(request, (ev: AIRuntimeEvent) => {
      events.push(ev);
    });
    return events;
  }

  /**
   * 精确 preferred：仅 modelName / modelId 全等；找不到则失败（对齐 iOS，禁止模糊 indexOf）。
   */
  private static pickResolved(snap: RuntimeSnapshot, request: AIRuntimeTextRequest): AIResolvedConfig | undefined {
    const list = snap.scenarios.get(request.scenario) ?? [];
    if (request.preferredModelName && request.preferredModelName.length > 0) {
      return ScenarioPolicyResolver.pickExact(list, request.preferredModelName);
    }
    return ScenarioPolicyResolver.pickBySource(list, request.preferredSource);
  }

  /** 无工具能力：清空 tools 且 toolChoice=none（严格降级） */
  private static applyToolsDegrade(
    request: AIRuntimeTextRequest,
    resolved: AIResolvedConfig
  ): AIRuntimeTextRequest {
    if (resolved.capabilities.supportsToolUse) {
      return request;
    }
    if (request.tools.length === 0 && request.toolChoice === 'none') {
      return request;
    }
    const fields = new LogFields();
    fields.detail = `模型不支持 tools，已降级为纯文本 model=${resolved.modelName}`;
    Logger.info('ai.runtime.tools_degraded', LogModule.AI_CONFIG, fields);
    request.tools = [];
    request.toolChoice = 'none';
    return request;
  }

  private static checkToken(request: AIRuntimeTextRequest): void {
    const token = request.cancellationToken;
    if (token instanceof AIRuntimeCancellationToken) {
      token.checkCancellation();
    }
  }

  private static fail(requestId: string, code: string, message: string): AIRuntimeResponse {
    const r = new AIRuntimeResponse();
    r.requestId = requestId;
    r.finishReason = code === 'cancelled' ? 'cancelled' : 'error';
    r.errorCode = code;
    r.errorMessage = message;
    r.createdAt = new Date().toISOString();
    r.isDegraded = true;
    return r;
  }
}

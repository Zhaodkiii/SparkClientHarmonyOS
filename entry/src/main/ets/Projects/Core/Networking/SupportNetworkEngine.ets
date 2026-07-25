import { NetworkLogger } from '../../../Foundation/Logging/NetworkLogger';
import {
  CancellationToken,
  NetworkRequest,
  NetworkResponse,
  QueuePriority,
  RawHttpRequest,
  SupportNetworkError,
  buildURLWithQuery,
  headerValue,
  makeRequestId
} from './SupportNetworkModels';
import { NetworkTransport } from './SupportNetworkTransport';
import { AuthTokenProvider, AuthTokenProviderError } from './AuthTokenProvider';
import { SerialRequestGate } from './SerialRequestGate';
import { RetryPolicy } from './RetryLayer';
import { ETagStore } from './ETagStore';
import { DeviceCache } from './Caching/DeviceCache';
import { SessionInvalidation } from './SessionInvalidation';
import { SupportAPIResponseDecoder } from './API/Common/SupportAPIResponseDecoder';

/**
 * 网络编排：串行门控 → 鉴权 → ETag → 重试 → Transport → 401 刷新重放。
 */
export class SupportNetworkEngine {
  private readonly baseURL: string;
  private readonly transport: NetworkTransport;
  private readonly gate: SerialRequestGate;
  private readonly retryPolicy: RetryPolicy;
  private readonly authProvider: AuthTokenProvider;
  private readonly etagStore: ETagStore;
  private readonly deviceCache: DeviceCache;
  private readonly logger: NetworkLogger;
  private readonly defaultTimeoutMs: number;

  constructor(
    baseURL: string,
    transport: NetworkTransport,
    authProvider: AuthTokenProvider,
    etagStore: ETagStore,
    deviceCache: DeviceCache,
    logger?: NetworkLogger,
    gate?: SerialRequestGate,
    retryPolicy?: RetryPolicy,
    defaultTimeoutMs: number = 60000
  ) {
    this.baseURL = baseURL;
    this.transport = transport;
    this.authProvider = authProvider;
    this.etagStore = etagStore;
    this.deviceCache = deviceCache;
    this.logger = logger ?? new NetworkLogger();
    this.gate = gate ?? new SerialRequestGate();
    this.retryPolicy = retryPolicy ?? new RetryPolicy();
    this.defaultTimeoutMs = defaultTimeoutMs;
  }

  get networkLogger(): NetworkLogger {
    return this.logger;
  }

  get serviceBaseURL(): string {
    return this.baseURL;
  }

  tokenProvider(): AuthTokenProvider {
    return this.authProvider;
  }

  cache(): DeviceCache {
    return this.deviceCache;
  }

  async sendRaw(request: NetworkRequest, cancellation: CancellationToken = new CancellationToken()): Promise<NetworkResponse> {
    const serialKey = request.strategy.serialKey ?? request.path;
    let retryCount = 0;
    let authReplayUsed = false;
    if (!request.requestId) {
      request.requestId = makeRequestId();
    }

    while (true) {
      cancellation.throwIfCancelled(request.requestId);
      const priority: QueuePriority = retryCount === 0 ? request.strategy.queuePriority : 'retry';
      try {
        const response = await this.gate.enqueue(serialKey, priority, async () => {
          return this.performAttempt(request, cancellation);
        });

        if (request.strategy.requiresAuth && response.statusCode === 401 && !authReplayUsed) {
          this.logger.info(`Auth refresh triggered path=${request.path}`);
          try {
            await this.authProvider.forceRefreshTokens();
          } catch (error) {
            const backend = SupportAPIResponseDecoder.parseBackendError(response.bodyText);
            this.postAuthInvalidationIfNeeded(response.statusCode, backend?.code, backend?.message ?? '', error);
            throw SupportNetworkError.refreshFailed(
              error instanceof Error ? error.message : `${error}`,
              backend
            );
          }
          authReplayUsed = true;
          retryCount += 1;
          continue;
        }

        if (this.isSuccess(response)) {
          return response;
        }

        const backend = SupportAPIResponseDecoder.parseBackendError(response.bodyText);
        if (this.shouldRetry(request, retryCount, response.statusCode, false)) {
          retryCount += 1;
          const retryAfter = headerValue(response.headers, 'Retry-After');
          await this.retryPolicy.sleepIfNeeded(retryCount - 1, retryAfter);
          continue;
        }

        // Anonymous endpoints (OTP request/verify, device registration, etc.)
        // may legitimately return 401/403 business errors. They do not prove
        // that the current signed-in session is invalid and must not clear the
        // global token store. iOS scopes this signal to authenticated calls.
        if (request.strategy.requiresAuth) {
          SessionInvalidation.postIfNeeded(
            response.statusCode,
            backend?.code,
            backend?.message ?? '',
            'SupportNetworkEngine.sendRaw'
          );
        }
        throw SupportNetworkError.http(response.statusCode, backend, response.requestId);
      } catch (error) {
        if (error instanceof SupportNetworkError) {
          if (error.kind === 'cancelled') {
            throw error;
          }
          if (error.kind === 'transport') {
            if (this.shouldRetry(request, retryCount, undefined, true)) {
              retryCount += 1;
              await this.retryPolicy.sleepIfNeeded(retryCount - 1, undefined);
              continue;
            }
          }
          throw error;
        }
        if (this.shouldRetry(request, retryCount, undefined, true)) {
          retryCount += 1;
          await this.retryPolicy.sleepIfNeeded(retryCount - 1, undefined);
          continue;
        }
        throw SupportNetworkError.transport('Unexpected network error', request.requestId);
      }
    }
  }

  private async performAttempt(request: NetworkRequest, cancellation: CancellationToken): Promise<NetworkResponse> {
    cancellation.throwIfCancelled(request.requestId);
    const url = buildURLWithQuery(this.baseURL, request.path, request.queryItems);
    const headers: Record<string, string> = {};
    const keys = Object.keys(request.headers);
    for (let i = 0; i < keys.length; i++) {
      headers[keys[i]] = request.headers[keys[i]];
    }
    headers['X-Request-ID'] = request.requestId ?? makeRequestId();
    request.requestId = headers['X-Request-ID'];

    let body: string | undefined = undefined;
    if (request.jsonBody !== undefined) {
      headers['Content-Type'] = headers['Content-Type'] ?? 'application/json';
      body = JSON.stringify(request.jsonBody);
    } else if (request.rawBody !== undefined) {
      if (request.contentType && !headers['Content-Type']) {
        headers['Content-Type'] = request.contentType;
      }
      body = request.rawBody;
    }

    if (request.strategy.requiresAuth) {
      headers['Authorization'] = await this.authProvider.authorizationHeaderValue();
    }

    const accountScope = this.deviceCache.getAccountScope();
    const authFp = request.strategy.requiresAuth ? this.authProvider.authFingerprint() : 'anon';
    let cacheKey: string | undefined = undefined;
    if (request.strategy.allowETag) {
      cacheKey = this.etagStore.cacheKey(url, authFp);
      this.etagStore.applyIfNoneMatch(headers, accountScope, cacheKey, request);
    }

    const timeoutMs = request.timeoutMs ?? this.defaultTimeoutMs;
    const raw = await this.transport.execute(
      new RawHttpRequest(url, request.method, headers, body, timeoutMs, request.requestId!),
      cancellation
    );

    let response = new NetworkResponse(
      raw.statusCode,
      raw.headers,
      raw.bodyText,
      false,
      request.requestId!,
      raw.durationMs
    );

    if (cacheKey && request.strategy.allowETag) {
      response = this.etagStore.mergeResponse(accountScope, cacheKey, response, request);
    }
    return response;
  }

  private isSuccess(response: NetworkResponse): boolean {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    }
    if (response.statusCode === 304 && response.didMerge304) {
      return true;
    }
    return false;
  }

  private shouldRetry(
    request: NetworkRequest,
    retryCount: number,
    statusCode: number | undefined,
    isTransport: boolean
  ): boolean {
    if (!request.strategy.retry.isEnabled) {
      return false;
    }
    const allow = request.strategy.isIdempotent || request.method === 'GET';
    if (!allow) {
      return false;
    }
    if (retryCount >= request.strategy.retry.maxRetryCount) {
      return false;
    }
    if (isTransport) {
      return this.retryPolicy.shouldRetryTransport();
    }
    return this.retryPolicy.shouldRetryStatus(statusCode);
  }

  private postAuthInvalidationIfNeeded(
    statusCode: number,
    backendCode: number | undefined,
    message: string,
    refreshError: Object
  ): void {
    let shouldInvalidate = false;
    if (refreshError instanceof AuthTokenProviderError) {
      shouldInvalidate =
        refreshError.kind === 'missingTokens' || refreshError.kind === 'refreshFailed';
    }
    if (!shouldInvalidate) {
      return;
    }
    SessionInvalidation.postIfNeeded(statusCode, backendCode, message, 'SupportNetworkEngine.refreshFailed');
  }
}

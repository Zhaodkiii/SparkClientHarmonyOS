import { JWTExpParser } from '../../../Foundation/JWTExpParser';
import { SecureTokenStore } from '../../../Foundation/Security/SecureTokenStore';
import { SparkAssetStore } from '../../../Foundation/Security/SparkAssetStore';
import { AUTH_BUNDLE_ID } from '../../../Foundation/Security/DeviceCredentialStore';
import { NetworkLogger } from '../../../Foundation/Logging/NetworkLogger';
import {
  AuthTokens,
  CancellationToken,
  HttpMethod,
  RawHttpRequest,
  buildURLWithQuery,
  makeRequestId
} from './SupportNetworkModels';
import { NetworkTransport } from './SupportNetworkTransport';
import { SessionInvalidation } from './SessionInvalidation';

export type AuthTokenProviderErrorKind =
  | 'missingTokens'
  | 'refreshFailed'
  | 'refreshTemporarilyUnavailable'
  | 'invalidRefreshResponse';

export class AuthTokenProviderError extends Error {
  kind: AuthTokenProviderErrorKind;
  backendCode?: number;

  constructor(kind: AuthTokenProviderErrorKind, message: string, backendCode?: number) {
    super(message);
    this.name = 'AuthTokenProviderError';
    this.kind = kind;
    this.backendCode = backendCode;
  }
}

class RefreshBackendError {
  code: number;
  message: string;

  constructor(code: number, message: string) {
    this.code = code;
    this.message = message;
  }
}

/**
 * Token 内存快照 + 安全持久化 + 刷新单飞。
 */
export class AuthTokenProvider {
  private readonly transport: NetworkTransport;
  private readonly baseURL: string;
  private readonly store: SecureTokenStore;
  private readonly logger: NetworkLogger;
  private readonly deviceIdProvider: () => Promise<string> | string;
  private readonly bundleIdProvider: () => string;
  private cached?: AuthTokens;
  private refreshPromise?: Promise<AuthTokens>;
  private readonly refreshPath: string = '/api/v1/auth/token/refresh/';

  constructor(
    transport: NetworkTransport,
    baseURL: string,
    store: SecureTokenStore,
    logger?: NetworkLogger,
    deviceIdProvider?: () => Promise<string> | string,
    bundleIdProvider?: () => string
  ) {
    this.transport = transport;
    this.baseURL = baseURL;
    this.store = store;
    this.logger = logger ?? new NetworkLogger();
    // Refresh must use the same installation device ID used during login. A fixed
    // fallback breaks backends that bind refresh tokens to the device session.
    this.deviceIdProvider = deviceIdProvider ?? ((): Promise<string> =>
      SparkAssetStore.getOrCreatePersistentDeviceID());
    // Refresh must use the exact same bundle_id as login. A stale SupportClient
    // default makes the backend reject an otherwise valid refresh token as a
    // device-session mismatch, which incorrectly drives the app to signedOut.
    this.bundleIdProvider = bundleIdProvider ?? ((): string => AUTH_BUNDLE_ID);
  }

  async restoreIfNeeded(): Promise<void> {
    if (this.cached) {
      return;
    }
    this.cached = await this.store.load();
  }

  /** 是否已有可用 refresh token（先 restore）。 */
  async hasRefreshToken(): Promise<boolean> {
    await this.restoreIfNeeded();
    const token = this.cached?.refreshToken;
    return !!(token && token.length > 0);
  }

  async setTokens(tokens: AuthTokens): Promise<void> {
    const jwtExp = JWTExpParser.parseExpMs(tokens.accessToken);
    if (jwtExp !== undefined) {
      tokens.expiresAtMs = Math.min(tokens.expiresAtMs, jwtExp);
    }
    this.cached = tokens;
    await this.store.save(tokens);
  }

  async clearTokens(): Promise<void> {
    this.cached = undefined;
    await this.store.clear();
    this.logger.debug('AuthTokenProvider: tokens cleared');
  }

  async authorizationHeaderValue(): Promise<string> {
    const tokens = await this.validTokens();
    return `${tokens.tokenType} ${tokens.accessToken}`;
  }

  authFingerprint(): string {
    const token = this.cached?.accessToken ?? '';
    if (!token) {
      return 'anon';
    }
    let h = 0;
    for (let i = 0; i < Math.min(token.length, 64); i++) {
      h = (h * 31 + token.charCodeAt(i)) | 0;
    }
    return `af_${(h >>> 0).toString(16)}`;
  }

  async forceRefreshTokens(): Promise<AuthTokens> {
    this.cached = undefined;
    return this.refreshIfNeeded(true);
  }

  async refreshIfNeeded(force: boolean = false): Promise<AuthTokens> {
    if (!force && this.cached && !this.isNearExpiry(this.cached)) {
      return this.cached;
    }
    if (this.refreshPromise) {
      return this.refreshPromise;
    }
    this.refreshPromise = this.refreshTokens()
      .then(async (tokens: AuthTokens) => {
        this.cached = tokens;
        await this.store.save(tokens);
        return tokens;
      })
      .finally(() => {
        this.refreshPromise = undefined;
      });
    return this.refreshPromise;
  }

  private async validTokens(): Promise<AuthTokens> {
    await this.restoreIfNeeded();
    if (this.cached) {
      if (!this.isNearExpiry(this.cached)) {
        return this.cached;
      }
      try {
        return await this.refreshIfNeeded(false);
      } catch (e) {
        if (e instanceof AuthTokenProviderError && e.kind === 'refreshTemporarilyUnavailable') {
          this.logger.warn('Token refresh temporarily unavailable; using cached access token');
          return this.cached;
        }
        // Keep the original typed failure, matching iOS. In particular, an
        // invalid response must not be upgraded to refreshFailed, because only
        // the latter is allowed to start the global sign-out flow.
        if (e instanceof AuthTokenProviderError) {
          throw new AuthTokenProviderError(e.kind, e.message, e.backendCode);
        }
        throw new AuthTokenProviderError('invalidRefreshResponse', 'Token refresh response was invalid');
      }
    }
    return this.refreshIfNeeded(true);
  }

  private isNearExpiry(tokens: AuthTokens): boolean {
    return Date.now() + 30000 >= tokens.expiresAtMs;
  }

  private async refreshTokens(): Promise<AuthTokens> {
    await this.restoreIfNeeded();
    const refreshToken = this.cached?.refreshToken;
    if (!refreshToken) {
      const loaded = await this.store.load();
      if (!loaded?.refreshToken) {
        await this.clearTokens();
        throw new AuthTokenProviderError('missingTokens', 'No refresh token');
      }
      this.cached = loaded;
    }
    const currentRefresh = this.cached!.refreshToken;
    const requestId = makeRequestId();
    const url = buildURLWithQuery(this.baseURL, this.refreshPath, []);
    const body = JSON.stringify({
      refresh: currentRefresh,
      refresh_token: currentRefresh,
      device_id: await this.deviceIdProvider(),
      bundle_id: this.bundleIdProvider()
    });
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-Request-ID': requestId
    };
    this.logger.info(`AuthTokenProvider refreshing requestId=${requestId}`);
    const raw = await this.transport.execute(
      new RawHttpRequest(url, 'POST' as HttpMethod, headers, body, 60000, requestId),
      new CancellationToken()
    );
    if (raw.statusCode >= 200 && raw.statusCode < 300) {
      try {
        const obj = JSON.parse(raw.bodyText) as Record<string, string>;
        const access = obj['access'] ?? obj['access_token'] ?? obj['accessToken'];
        const refresh = obj['refresh'] ?? obj['refresh_token'] ?? obj['refreshToken'] ?? currentRefresh;
        const tokenType = (obj['token_type'] ?? obj['tokenType'] ?? 'Bearer').trim() || 'Bearer';
        if (!access) {
          throw new AuthTokenProviderError('invalidRefreshResponse', 'Missing access token');
        }
        let expiresAtMs = Date.now() + 3600 * 1000;
        const jwtExp = JWTExpParser.parseExpMs(access);
        if (jwtExp !== undefined) {
          expiresAtMs = jwtExp;
        }
        return new AuthTokens(access, refresh, expiresAtMs, tokenType);
      } catch (e) {
        if (e instanceof AuthTokenProviderError) {
          throw new AuthTokenProviderError(e.kind, e.message, e.backendCode);
        }
        throw new AuthTokenProviderError('invalidRefreshResponse', `${e}`);
      }
    }
    const backend = this.parseRefreshBackendError(raw.bodyText);
    if (backend && this.isDefinitiveRefreshAuthFailure(backend.code, backend.message)) {
      await this.clearTokens();
      SessionInvalidation.postIfNeeded(raw.statusCode, backend.code, backend.message, 'AuthTokenProvider.refresh');
      throw new AuthTokenProviderError('refreshFailed', `Refresh HTTP ${raw.statusCode} code=${backend.code}`,
        backend.code);
    }
    if (raw.statusCode === 429 || raw.statusCode >= 500 || !backend) {
      throw new AuthTokenProviderError('refreshTemporarilyUnavailable', `Refresh temporary HTTP ${raw.statusCode}`);
    }
    throw new AuthTokenProviderError('refreshTemporarilyUnavailable',
      `Refresh HTTP ${raw.statusCode} code=${backend.code}`);
  }

  private parseRefreshBackendError(bodyText: string): RefreshBackendError | undefined {
    try {
      const obj = JSON.parse(bodyText) as Record<string, Object | string | number>;
      const codeValue = obj['code'];
      if (typeof codeValue !== 'number' && typeof codeValue !== 'string') {
        return undefined;
      }
      const msgValue = obj['msg'];
      return new RefreshBackendError(Number(codeValue), msgValue === undefined ? '' : `${msgValue}`);
    } catch (_e) {
      return undefined;
    }
  }

  private isDefinitiveRefreshAuthFailure(code: number, message: string): boolean {
    if ((code >= 40100 && code <= 40199) || (code >= 40300 && code <= 40399)) {
      return true;
    }
    const normalized = message.trim().toLowerCase();
    return normalized === 'token_not_valid' ||
      normalized === 'device_session_revoked' ||
      normalized === 'device_session_replaced' ||
      normalized === 'device_session_not_found' ||
      normalized === 'device_mismatch';
  }
}

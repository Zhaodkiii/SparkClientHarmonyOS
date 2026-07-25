/**
 * 网络模块核心模型：请求、策略、响应、错误与取消。
 */

export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

export type ResponseDecodingMode = 'backendWrapped' | 'direct';

export type QueuePriority = 'retry' | 'veryHigh' | 'high' | 'normal' | 'low';

export type NetworkErrorKind =
  | 'transport'
  | 'http'
  | 'business'
  | 'refreshFailed'
  | 'cancelled'
  | 'decoding'
  | 'invalidResponse'
  | 'unauthenticated';

export class RetryConfig {
  isEnabled: boolean;
  maxRetryCount: number;
  retryableStatusCodes: number[];
  honorsRetryAfter: boolean;
  /** 毫秒；对齐 iOS [0, 0.75, 3] 秒 */
  backoffIntervalsMs: number[];

  constructor(
    isEnabled: boolean = true,
    maxRetryCount: number = 2,
    retryableStatusCodes: number[] = [429, 500, 502, 503, 504],
    honorsRetryAfter: boolean = true,
    backoffIntervalsMs: number[] = [0, 750, 3000]
  ) {
    this.isEnabled = isEnabled;
    this.maxRetryCount = maxRetryCount;
    this.retryableStatusCodes = retryableStatusCodes;
    this.honorsRetryAfter = honorsRetryAfter;
    this.backoffIntervalsMs = backoffIntervalsMs;
  }

  static defaultConfig(): RetryConfig {
    return new RetryConfig();
  }

  static disabled(): RetryConfig {
    return new RetryConfig(false, 0, [], false, []);
  }
}

export class NetworkStrategy {
  requiresAuth: boolean;
  allowETag: boolean;
  serialKey?: string;
  isIdempotent: boolean;
  queuePriority: QueuePriority;
  retry: RetryConfig;
  etagTtlMs?: number;

  constructor(
    requiresAuth: boolean = false,
    allowETag: boolean = false,
    serialKey?: string,
    isIdempotent: boolean = false,
    queuePriority: QueuePriority = 'normal',
    retry: RetryConfig = RetryConfig.defaultConfig(),
    etagTtlMs?: number
  ) {
    this.requiresAuth = requiresAuth;
    this.allowETag = allowETag;
    this.serialKey = serialKey;
    this.isIdempotent = isIdempotent;
    this.queuePriority = queuePriority;
    this.retry = retry;
    this.etagTtlMs = etagTtlMs;
  }
}

export class QueryItem {
  name: string;
  value: string;

  constructor(name: string, value: string) {
    this.name = name;
    this.value = value;
  }
}

/** body 为 JSON 对象字符串或原始字符串；二进制用 rawBody + contentType */
export class NetworkRequest {
  method: HttpMethod;
  path: string;
  queryItems: QueryItem[];
  headers: Record<string, string>;
  /** JSON 对象；发送时 stringify */
  jsonBody?: Object;
  /** 原始 body 文本（非 JSON 对象时） */
  rawBody?: string;
  contentType?: string;
  timeoutMs?: number;
  strategy: NetworkStrategy;
  /** 重试复用同一 Request ID */
  requestId?: string;

  constructor(
    method: HttpMethod,
    path: string,
    strategy: NetworkStrategy = new NetworkStrategy(),
    queryItems: QueryItem[] = [],
    headers: Record<string, string> = {},
    jsonBody?: Object,
    rawBody?: string,
    contentType?: string,
    timeoutMs?: number
  ) {
    this.method = method;
    this.path = path;
    this.strategy = strategy;
    this.queryItems = queryItems;
    this.headers = headers;
    this.jsonBody = jsonBody;
    this.rawBody = rawBody;
    this.contentType = contentType;
    this.timeoutMs = timeoutMs;
  }
}

export class NetworkResponse {
  statusCode: number;
  headers: Record<string, string>;
  bodyText: string;
  didMerge304: boolean;
  requestId: string;
  durationMs: number;

  constructor(
    statusCode: number,
    headers: Record<string, string>,
    bodyText: string,
    didMerge304: boolean = false,
    requestId: string = '',
    durationMs: number = 0
  ) {
    this.statusCode = statusCode;
    this.headers = headers;
    this.bodyText = bodyText;
    this.didMerge304 = didMerge304;
    this.requestId = requestId;
    this.durationMs = durationMs;
  }
}

export class BackendErrorInfo {
  code: number;
  message: string;
  rawMsg?: Object;

  constructor(code: number, message: string, rawMsg?: Object) {
    this.code = code;
    this.message = message;
    this.rawMsg = rawMsg;
  }
}

export class SupportNetworkError extends Error {
  kind: NetworkErrorKind;
  statusCode?: number;
  backend?: BackendErrorInfo;
  requestId?: string;
  causeMessage?: string;

  constructor(
    kind: NetworkErrorKind,
    message: string,
    statusCode?: number,
    backend?: BackendErrorInfo,
    requestId?: string,
    causeMessage?: string
  ) {
    super(message);
    this.name = 'SupportNetworkError';
    this.kind = kind;
    this.statusCode = statusCode;
    this.backend = backend;
    this.requestId = requestId;
    this.causeMessage = causeMessage;
  }

  static transport(message: string, requestId?: string): SupportNetworkError {
    return new SupportNetworkError('transport', message, undefined, undefined, requestId, message);
  }

  static http(statusCode: number, backend?: BackendErrorInfo, requestId?: string): SupportNetworkError {
    const msg = backend?.message ?? `HTTP ${statusCode}`;
    return new SupportNetworkError('http', msg, statusCode, backend, requestId);
  }

  static business(backend: BackendErrorInfo, statusCode?: number, requestId?: string): SupportNetworkError {
    return new SupportNetworkError('business', backend.message, statusCode, backend, requestId);
  }

  static cancelled(requestId?: string): SupportNetworkError {
    return new SupportNetworkError('cancelled', 'Request cancelled', undefined, undefined, requestId);
  }

  static decoding(message: string, requestId?: string): SupportNetworkError {
    return new SupportNetworkError('decoding', message, undefined, undefined, requestId);
  }

  static invalidResponse(message: string, requestId?: string): SupportNetworkError {
    return new SupportNetworkError('invalidResponse', message, undefined, undefined, requestId);
  }

  static unauthenticated(message: string = 'Unauthenticated'): SupportNetworkError {
    return new SupportNetworkError('unauthenticated', message);
  }

  static refreshFailed(message: string, backend?: BackendErrorInfo): SupportNetworkError {
    return new SupportNetworkError('refreshFailed', message, undefined, backend);
  }
}

export class CancellationToken {
  private _cancelled: boolean = false;
  private listeners: Array<() => void> = [];

  get cancelled(): boolean {
    return this._cancelled;
  }

  cancel(): void {
    if (this._cancelled) {
      return;
    }
    this._cancelled = true;
    const copy = this.listeners.slice();
    this.listeners = [];
    for (let i = 0; i < copy.length; i++) {
      try {
        copy[i]();
      } catch (_e) {
        // ignore listener errors
      }
    }
  }

  onCancel(listener: () => void): void {
    if (this._cancelled) {
      listener();
      return;
    }
    this.listeners.push(listener);
  }

  offCancel(listener: () => void): void {
    const idx = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  throwIfCancelled(requestId?: string): void {
    if (this._cancelled) {
      throw SupportNetworkError.cancelled(requestId);
    }
  }
}

export class RawHttpRequest {
  url: string;
  method: HttpMethod;
  headers: Record<string, string>;
  body?: string;
  timeoutMs: number;
  requestId: string;

  constructor(
    url: string,
    method: HttpMethod,
    headers: Record<string, string>,
    body: string | undefined,
    timeoutMs: number,
    requestId: string
  ) {
    this.url = url;
    this.method = method;
    this.headers = headers;
    this.body = body;
    this.timeoutMs = timeoutMs;
    this.requestId = requestId;
  }
}

export class RawHttpResponse {
  statusCode: number;
  headers: Record<string, string>;
  bodyText: string;
  durationMs: number;

  constructor(statusCode: number, headers: Record<string, string>, bodyText: string, durationMs: number) {
    this.statusCode = statusCode;
    this.headers = headers;
    this.bodyText = bodyText;
    this.durationMs = durationMs;
  }
}

export class AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresAtMs: number;
  tokenType: string;

  constructor(accessToken: string, refreshToken: string, expiresAtMs: number, tokenType: string = 'Bearer') {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.expiresAtMs = expiresAtMs;
    this.tokenType = tokenType;
  }
}

export class ETagCacheRecord {
  etag: string;
  lastUpdatedMs: number;
  expirationMs?: number;

  constructor(etag: string, lastUpdatedMs: number, expirationMs?: number) {
    this.etag = etag;
    this.lastUpdatedMs = lastUpdatedMs;
    this.expirationMs = expirationMs;
  }

  isExpired(nowMs: number = Date.now()): boolean {
    if (this.expirationMs === undefined || this.expirationMs === null) {
      return false;
    }
    return this.expirationMs <= nowMs;
  }
}

export function queuePriorityValue(priority: QueuePriority): number {
  switch (priority) {
    case 'retry':
      return 0;
    case 'veryHigh':
      return 1;
    case 'high':
      return 2;
    case 'normal':
      return 3;
    case 'low':
      return 4;
    default:
      return 3;
  }
}

export function joinBaseURLAndPath(baseURL: string, path: string): string {
  const base = baseURL.endsWith('/') ? baseURL.substring(0, baseURL.length - 1) : baseURL;
  const p = path.startsWith('/') ? path : `/${path}`;
  return `${base}${p}`;
}

export function buildURLWithQuery(baseURL: string, path: string, queryItems: QueryItem[]): string {
  const url = joinBaseURLAndPath(baseURL, path);
  if (!queryItems || queryItems.length === 0) {
    return url;
  }
  const sorted = queryItems.slice().sort((a, b) => {
    if (a.name < b.name) {
      return -1;
    }
    if (a.name > b.name) {
      return 1;
    }
    return 0;
  });
  const parts: string[] = [];
  for (let i = 0; i < sorted.length; i++) {
    const item = sorted[i];
    parts.push(`${encodeURIComponent(item.name)}=${encodeURIComponent(item.value)}`);
  }
  return `${url}?${parts.join('&')}`;
}

export function makeRequestId(): string {
  const now = Date.now().toString(16);
  const rand = Math.floor(Math.random() * 0xffffffff).toString(16).padStart(8, '0');
  return `${now}-${rand}`;
}

export function headerValue(headers: Record<string, string>, name: string): string | undefined {
  const keys = Object.keys(headers);
  const lower = name.toLowerCase();
  for (let i = 0; i < keys.length; i++) {
    if (keys[i].toLowerCase() === lower) {
      return headers[keys[i]];
    }
  }
  return undefined;
}

export function normalizeMsg(msg: Object | string | null | undefined): string {
  if (msg === null || msg === undefined) {
    return '';
  }
  if (typeof msg === 'string') {
    return msg;
  }
  const obj = msg as Record<string, Object>;
  if (typeof obj['detail'] === 'string') {
    return obj['detail'] as string;
  }
  if (typeof obj['message'] === 'string') {
    return obj['message'] as string;
  }
  if (typeof obj['code'] === 'string') {
    return obj['code'] as string;
  }
  try {
    return JSON.stringify(msg);
  } catch (_e) {
    return 'Unknown backend error';
  }
}

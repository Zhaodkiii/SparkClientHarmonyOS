import { LogEvent } from './LogEvent';
import { LogLevel } from './LogLevel';
import { LogModule } from './LogModule';

/**
 * 统一脱敏：Token/OTP/API Key/STS、手机号、邮箱；单行截断 200。
 */
export class LogSanitizer {
  static readonly MAX_SNIPPET_LENGTH: number = 200;

  private static readonly SENSITIVE_HEADER_KEYS: string[] = [
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key'
  ];

  private static readonly SENSITIVE_FIELD_KEYS: string[] = [
    'password',
    'access',
    'refresh',
    'accessToken',
    'refreshToken',
    'access_token',
    'refresh_token',
    'authorization',
    'authorizationCode',
    'identityToken',
    'deviceSecret',
    'apiKey',
    'api_key',
    'code',
    'otp',
    'accessKeySecret',
    'securityToken',
    'security_token',
    'verification_ticket',
    'verificationTicket'
  ];

  static sanitizeHeaderValue(key: string, value: string): string {
    const lower = key.toLowerCase();
    for (let i = 0; i < LogSanitizer.SENSITIVE_HEADER_KEYS.length; i++) {
      if (lower === LogSanitizer.SENSITIVE_HEADER_KEYS[i] || lower.indexOf('token') >= 0) {
        return '<redacted>';
      }
    }
    return value;
  }

  static headersPreview(headers: Record<string, string> | undefined): string {
    if (!headers) {
      return '{}';
    }
    const keys = Object.keys(headers);
    if (keys.length === 0) {
      return '{}';
    }
    const parts: string[] = [];
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      parts.push(`${k}=${LogSanitizer.sanitizeHeaderValue(k, headers[k])}`);
    }
    return `{${parts.join(', ')}}`;
  }

  static bodySummary(bodyText: string | undefined, maxLen: number = 256): string {
    if (!bodyText || bodyText.length === 0) {
      return '';
    }
    try {
      const parsed = JSON.parse(bodyText) as Object;
      return LogSanitizer.sanitizeObjectSummary(parsed, maxLen);
    } catch (_e) {
      if (bodyText.length > maxLen) {
        return `<raw:${bodyText.length} bytes>`;
      }
      return LogSanitizer.redactPlainText(bodyText);
    }
  }

  /** 完整 UTF-8 正文（脱敏但不截断）；大正文由 NetworkLogger 分块输出。 */
  static bodyFull(bodyText: string | undefined): string {
    if (!bodyText || bodyText.length === 0) {
      return '';
    }
    try {
      const parsed = JSON.parse(bodyText) as Object;
      return JSON.stringify(LogSanitizer.redactValue(parsed), null, 2);
    } catch (_e) {
      return LogSanitizer.redactPlainText(bodyText);
    }
  }

  static sanitizeObjectSummary(value: Object, maxLen: number = 256): string {
    const redacted = LogSanitizer.redactValue(value);
    const text = JSON.stringify(redacted);
    if (text.length > maxLen) {
      return text.substring(0, maxLen) + '…';
    }
    return text;
  }

  static loggablePath(url: string): string {
    try {
      const q = url.indexOf('?');
      if (q >= 0) {
        const path = url.substring(0, q);
        const query = url.substring(q + 1);
        return `${LogSanitizer.pathOnly(path)}?${LogSanitizer.sanitizeQuery(query)}`;
      }
      return LogSanitizer.pathOnly(url);
    } catch (_e) {
      return url;
    }
  }

  /**
   * 合并换行并截断到 limit（默认 200），对齐 iOS LogMessageSanitizer。
   */
  static singleLineSnippet(text: string, limit: number = LogSanitizer.MAX_SNIPPET_LENGTH): string {
    const collapsed = text.replace(/\n/g, '\\n').replace(/\r/g, '');
    if (collapsed.length <= limit) {
      return collapsed;
    }
    return collapsed.substring(0, limit) + `…(len=${collapsed.length})`;
  }

  /**
   * 对 LogEvent 白名单字段脱敏；失败时 detail=redaction_failed。
   */
  static sanitizeLogEvent(event: LogEvent): LogEvent {
    try {
      const out = new LogEvent(event.event, event.module, event.level, event.timestampMs);
      if (event.requestId !== undefined) {
        out.requestId = LogSanitizer.redactPlainText(event.requestId).substring(0, 128);
      }
      if (event.ossRequestId !== undefined) {
        out.ossRequestId = LogSanitizer.redactPlainText(event.ossRequestId).substring(0, 128);
      }
      if (event.route !== undefined) {
        out.route = LogSanitizer.singleLineSnippet(event.route, 80);
      }
      if (event.operation !== undefined) {
        out.operation = LogSanitizer.singleLineSnippet(event.operation, 80);
      }
      if (event.code !== undefined) {
        out.code = event.code;
      }
      if (event.elapsedMs !== undefined) {
        out.elapsedMs = event.elapsedMs;
      }
      if (event.retryCount !== undefined) {
        out.retryCount = event.retryCount;
      }
      if (event.accountHash !== undefined) {
        out.accountHash = event.accountHash;
      }
      if (event.detail !== undefined) {
        out.detail = LogSanitizer.singleLineSnippet(LogSanitizer.redactPlainText(event.detail));
      }
      // level 在 toPlainObject 里用数字；对外展示用名字时由 Logger 处理
      return out;
    } catch (_e) {
      const failed = new LogEvent(event.event || 'general.redaction_failed', LogModule.GENERAL, event.level || LogLevel.WARN);
      failed.detail = 'redaction_failed';
      return failed;
    }
  }

  static redactPlainText(text: string): string {
    let result = text
      .replace(/Bearer\s+[A-Za-z0-9\-._~+/]+=*/gi, 'Bearer <redacted>')
      .replace(/"password"\s*:\s*"[^"]*"/gi, '"password":"<redacted>"')
      .replace(/"code"\s*:\s*"[^"]*"/gi, '"code":"<redacted>"')
      .replace(/"accessToken"\s*:\s*"[^"]*"/gi, '"accessToken":"<redacted>"')
      .replace(/"refreshToken"\s*:\s*"[^"]*"/gi, '"refreshToken":"<redacted>"')
      .replace(/"accessKeySecret"\s*:\s*"[^"]*"/gi, '"accessKeySecret":"<redacted>"')
      .replace(/"securityToken"\s*:\s*"[^"]*"/gi, '"securityToken":"<redacted>"')
      .replace(/"api[_-]?key"\s*:\s*"[^"]*"/gi, '"apiKey":"<redacted>"');
    // 手机号（大陆 11 位，简化匹配）
    result = result.replace(/1[3-9]\d{9}/g, '<phone>');
    // 简易邮箱
    result = result.replace(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, '<email>');
    return result;
  }

  private static pathOnly(url: string): string {
    const scheme = url.indexOf('://');
    if (scheme < 0) {
      return url.startsWith('/') ? url : `/${url}`;
    }
    const rest = url.substring(scheme + 3);
    const slash = rest.indexOf('/');
    if (slash < 0) {
      return '/';
    }
    return rest.substring(slash);
  }

  private static sanitizeQuery(query: string): string {
    const parts = query.split('&');
    const out: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const p = parts[i];
      const eq = p.indexOf('=');
      if (eq < 0) {
        out.push(p);
        continue;
      }
      const key = p.substring(0, eq);
      const lower = key.toLowerCase();
      let sensitive = false;
      for (let j = 0; j < LogSanitizer.SENSITIVE_FIELD_KEYS.length; j++) {
        if (lower === LogSanitizer.SENSITIVE_FIELD_KEYS[j].toLowerCase()) {
          sensitive = true;
          break;
        }
      }
      out.push(sensitive ? `${key}=<redacted>` : p);
    }
    return out.join('&');
  }

  private static redactValue(value: Object | null | undefined): Object | null {
    if (value === null || value === undefined) {
      return null;
    }
    if (Array.isArray(value)) {
      const arr = value as Object[];
      const out: Object[] = [];
      for (let i = 0; i < arr.length; i++) {
        out.push(LogSanitizer.redactValue(arr[i]) as Object);
      }
      return out;
    }
    if (typeof value === 'object') {
      const obj = value as Record<string, Object>;
      const keys = Object.keys(obj);
      const out: Record<string, Object> = {};
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i];
        if (LogSanitizer.isSensitiveField(k)) {
          out[k] = '<redacted>';
        } else {
          out[k] = LogSanitizer.redactValue(obj[k]) as Object;
        }
      }
      return out;
    }
    if (typeof value === 'string') {
      return LogSanitizer.redactPlainText(value as string);
    }
    return value;
  }

  private static isSensitiveField(key: string): boolean {
    const lower = key.toLowerCase();
    for (let i = 0; i < LogSanitizer.SENSITIVE_FIELD_KEYS.length; i++) {
      if (lower === LogSanitizer.SENSITIVE_FIELD_KEYS[i].toLowerCase()) {
        return true;
      }
    }
    if (lower.indexOf('secret') >= 0 || lower.indexOf('password') >= 0) {
      return true;
    }
    return false;
  }
}

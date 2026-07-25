import { LogLevel } from './LogLevel';
import { LogModule } from './LogModule';
import { LogFields } from './LogEvent';
import { Logger } from './Logger';
import { LogSanitizer } from './LogSanitizer';

/**
 * 网络模块日志门面；内部委托统一 Logger，模块固定为 NETWORK。
 */
export class NetworkLogger {
  private static readonly RAW_CHUNK_LENGTH: number = 160;
  private minLevel: LogLevel;

  constructor(minLevel: LogLevel = LogLevel.DEBUG) {
    this.minLevel = minLevel;
  }

  setMinLevel(level: LogLevel): void {
    this.minLevel = level;
  }

  verbose(message: string): void {
    this.log(LogLevel.VERBOSE, message);
  }

  debug(message: string): void {
    this.log(LogLevel.DEBUG, message);
  }

  info(message: string): void {
    this.log(LogLevel.INFO, message);
  }

  warn(message: string): void {
    this.log(LogLevel.WARN, message);
  }

  error(message: string): void {
    this.log(LogLevel.ERROR, message);
  }

  outbound(method: string, url: string, requestId: string, headers?: Record<string, string>): void {
    if (LogLevel.INFO < this.minLevel) {
      return;
    }
    const fields = new LogFields();
    fields.requestId = requestId;
    fields.operation = method;
    fields.detail =
      `${LogSanitizer.loggablePath(url)} headers=${LogSanitizer.headersPreview(headers)}`;
    Logger.info('network.request.outbound', LogModule.NETWORK, fields);
  }

  inbound(
    method: string,
    url: string,
    requestId: string,
    statusCode: number,
    costMs: number,
    byteCount: number
  ): void {
    if (LogLevel.INFO < this.minLevel) {
      return;
    }
    const fields = new LogFields();
    fields.requestId = requestId;
    fields.operation = method;
    fields.code = statusCode;
    fields.elapsedMs = costMs;
    fields.detail = `${LogSanitizer.loggablePath(url)} bytes=${byteCount}`;
    Logger.info('network.request.inbound', LogModule.NETWORK, fields);
  }

  /** 与 iOS raw 报文日志对齐；正文分块避免统一日志单条 detail 截断。 */
  outboundRaw(requestId: string, headers: Record<string, string>, body: string | undefined): void {
    this.rawChunks(LogLevel.DEBUG, `network.request.outbound_raw requestId=${requestId} headers=${NetworkLogger.jsonHeaders(headers)} body=`, LogSanitizer.bodyFull(body));
  }

  inboundRaw(
    requestId: string,
    method: string,
    url: string,
    statusCode: number,
    headers: Record<string, string>,
    body: string
  ): void {
    this.rawChunks(
      LogLevel.DEBUG,
      `network.request.inbound_raw requestId=${requestId} method=${method} url=${LogSanitizer.loggablePath(url)} status=${statusCode} headers=${NetworkLogger.jsonHeaders(headers)} body=`,
      LogSanitizer.bodyFull(body)
    );
  }

  etagMerged304(path: string, cacheKey: string, body: string): void {
    const full = LogSanitizer.bodyFull(body);
    this.rawChunks(LogLevel.DEBUG, `ETag 304 本地缓存完整响应体 path=${path} cacheKey=${cacheKey} bytes=${body.length}\n--- body ---\n`, full);
  }

  private rawChunks(level: LogLevel, prefix: string, body: string): void {
    if (level < this.minLevel) {
      return;
    }
    if (body.length === 0) {
      Logger.message(level, LogModule.NETWORK, prefix);
      return;
    }
    // 先单独输出报文元数据，再输出正文分块，避免 headers 很长时挤掉 body 首段。
    Logger.message(level, LogModule.NETWORK, prefix);
    let offset = 0;
    while (offset < body.length) {
      const end = Math.min(offset + NetworkLogger.RAW_CHUNK_LENGTH, body.length);
      const chunk = body.substring(offset, end);
      Logger.message(level, LogModule.NETWORK, `body${offset}:${end}/${body.length} ${chunk}`);
      offset = end;
    }
  }

  private static jsonHeaders(headers: Record<string, string> | undefined): string {
    if (!headers || Object.keys(headers).length === 0) {
      return '{}';
    }
    const out: Record<string, string> = {};
    const keys = Object.keys(headers).sort();
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      out[key] = LogSanitizer.sanitizeHeaderValue(key, headers[key]);
    }
    return JSON.stringify(out);
  }

  private log(level: LogLevel, message: string): void {
    if (level < this.minLevel) {
      return;
    }
    Logger.message(level, LogModule.NETWORK, message);
  }
}

// 重新导出，便于既有 `import { LogLevel } from '.../NetworkLogger'` 兼容
export { LogLevel } from './LogLevel';

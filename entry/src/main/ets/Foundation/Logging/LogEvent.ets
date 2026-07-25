import { LogLevel, logLevelName } from './LogLevel';
import { LogModule } from './LogModule';

/**
 * 结构化日志白名单字段（方案 §5.2 + HOS-FILE-OSS-0001）。
 * ossRequestId 与 SparkService requestId 分字段，禁止塞进长 detail 再靠字符串解析。
 */
export class LogEvent {
  event: string;
  module: LogModule;
  level: LogLevel;
  timestampMs: number;
  requestId?: string;
  /** 阿里云 OSS RequestId（与 SparkService X-Request-ID 不同）。 */
  ossRequestId?: string;
  route?: string;
  operation?: string;
  code?: string | number;
  elapsedMs?: number;
  retryCount?: number;
  accountHash?: string;
  detail?: string;

  constructor(
    event: string,
    module: LogModule,
    level: LogLevel,
    timestampMs: number = Date.now()
  ) {
    this.event = event;
    this.module = module;
    this.level = level;
    this.timestampMs = timestampMs;
  }

  /** 仅输出白名单键，供序列化 */
  toPlainObject(): Record<string, string | number | undefined> {
    const out: Record<string, string | number | undefined> = {};
    out['event'] = this.event;
    out['module'] = this.module;
    out['level'] = logLevelName(this.level);
    out['timestampMs'] = this.timestampMs;
    if (this.requestId !== undefined) {
      out['requestId'] = this.requestId;
    }
    if (this.ossRequestId !== undefined) {
      out['ossRequestId'] = this.ossRequestId;
    }
    if (this.route !== undefined) {
      out['route'] = this.route;
    }
    if (this.operation !== undefined) {
      out['operation'] = this.operation;
    }
    if (this.code !== undefined) {
      out['code'] = this.code;
    }
    if (this.elapsedMs !== undefined) {
      out['elapsedMs'] = this.elapsedMs;
    }
    if (this.retryCount !== undefined) {
      out['retryCount'] = this.retryCount;
    }
    if (this.accountHash !== undefined) {
      out['accountHash'] = this.accountHash;
    }
    if (this.detail !== undefined) {
      out['detail'] = this.detail;
    }
    return out;
  }
}

export class LogFields {
  requestId?: string;
  ossRequestId?: string;
  route?: string;
  operation?: string;
  code?: string | number;
  elapsedMs?: number;
  retryCount?: number;
  accountHash?: string;
  detail?: string;

  constructor() {
  }
}

/** event 名：小写点分，3–81 字符 */
export function isValidEventName(event: string): boolean {
  if (!event || event.length < 3 || event.length > 81) {
    return false;
  }
  return /^[a-z][a-z0-9_.]{2,80}$/.test(event);
}

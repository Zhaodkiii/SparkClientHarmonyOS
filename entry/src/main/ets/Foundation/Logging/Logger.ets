import { hilog } from '@kit.PerformanceAnalysisKit';
import { LogLevel, logLevelName } from './LogLevel';
import { LogModule } from './LogModule';
import { LogEvent, LogFields, isValidEventName } from './LogEvent';
import { LogSanitizer } from './LogSanitizer';

const DEFAULT_DOMAIN = 0x5350;
const DEFAULT_TAG = 'SupportClient';

export class LoggerConfig {
  minLevel: LogLevel = LogLevel.INFO;
  domain: number = DEFAULT_DOMAIN;
  tag: string = DEFAULT_TAG;
}

/**
 * 应用级统一日志入口。页面与业务不得直接调用 hilog。
 */
export class Logger {
  private static minLevel: LogLevel = LogLevel.INFO;
  private static domain: number = DEFAULT_DOMAIN;
  private static tag: string = DEFAULT_TAG;
  private static configured: boolean = false;
  /** 测试捕获 */
  private static captureSink?: (line: string, level: LogLevel) => void;

  static configure(config: LoggerConfig): void {
    Logger.minLevel = config.minLevel;
    Logger.domain = config.domain;
    Logger.tag = config.tag;
    Logger.configured = true;
  }

  static isConfigured(): boolean {
    return Logger.configured;
  }

  static getMinLevel(): LogLevel {
    return Logger.minLevel;
  }

  static setCaptureSinkForTests(sink?: (line: string, level: LogLevel) => void): void {
    Logger.captureSink = sink;
  }

  static resetForTests(): void {
    Logger.minLevel = LogLevel.INFO;
    Logger.domain = DEFAULT_DOMAIN;
    Logger.tag = DEFAULT_TAG;
    Logger.configured = false;
    Logger.captureSink = undefined;
  }

  static verbose(event: string, module: LogModule = LogModule.GENERAL, fields?: LogFields): void {
    Logger.emit(LogLevel.VERBOSE, event, module, fields);
  }

  static debug(event: string, module: LogModule = LogModule.GENERAL, fields?: LogFields): void {
    Logger.emit(LogLevel.DEBUG, event, module, fields);
  }

  static info(event: string, module: LogModule = LogModule.GENERAL, fields?: LogFields): void {
    Logger.emit(LogLevel.INFO, event, module, fields);
  }

  static warn(event: string, module: LogModule = LogModule.GENERAL, fields?: LogFields): void {
    Logger.emit(LogLevel.WARN, event, module, fields);
  }

  static error(event: string, module: LogModule = LogModule.GENERAL, fields?: LogFields): void {
    Logger.emit(LogLevel.ERROR, event, module, fields);
  }

  /** 兼容自由文本；会先脱敏并截断，再作为 detail 挂到 general.message */
  static message(level: LogLevel, module: LogModule, text: string): void {
    const fields = new LogFields();
    fields.detail = text;
    Logger.emit(level, 'general.message', module, fields);
  }

  private static emit(level: LogLevel, event: string, module: LogModule, fields?: LogFields): void {
    try {
      if (level < Logger.minLevel) {
        return;
      }
      let eventName = event;
      if (!isValidEventName(eventName)) {
        eventName = 'general.invalid_event';
      }
      const logEvent = new LogEvent(eventName, module, level);
      if (fields) {
        if (fields.requestId !== undefined) {
          logEvent.requestId = fields.requestId.length > 128 ? undefined : fields.requestId;
        }
        if (fields.ossRequestId !== undefined) {
          logEvent.ossRequestId = fields.ossRequestId.length > 128 ? undefined : fields.ossRequestId;
        }
        if (fields.route !== undefined) {
          logEvent.route = fields.route.substring(0, 80);
        }
        if (fields.operation !== undefined) {
          logEvent.operation = fields.operation.substring(0, 80);
        }
        if (fields.code !== undefined) {
          logEvent.code = fields.code;
        }
        if (fields.elapsedMs !== undefined && fields.elapsedMs >= 0) {
          logEvent.elapsedMs = Math.round(fields.elapsedMs);
        }
        if (fields.retryCount !== undefined) {
          const r = Math.max(0, Math.min(3, Math.round(fields.retryCount)));
          logEvent.retryCount = r;
        }
        if (fields.accountHash !== undefined) {
          logEvent.accountHash = fields.accountHash;
        }
        if (fields.detail !== undefined) {
          logEvent.detail = fields.detail;
        }
      }
      const safe = LogSanitizer.sanitizeLogEvent(logEvent);
      const line = JSON.stringify(safe.toPlainObject());
      if (Logger.captureSink) {
        Logger.captureSink(line, level);
      }
      switch (level) {
        case LogLevel.VERBOSE:
        case LogLevel.DEBUG:
          hilog.debug(Logger.domain, Logger.tag, '%{public}s', line);
          break;
        case LogLevel.INFO:
          hilog.info(Logger.domain, Logger.tag, '%{public}s', line);
          break;
        case LogLevel.WARN:
          hilog.warn(Logger.domain, Logger.tag, '%{public}s', line);
          break;
        case LogLevel.ERROR:
          hilog.error(Logger.domain, Logger.tag, '%{public}s', line);
          break;
        default:
          hilog.info(Logger.domain, Logger.tag, '%{public}s', line);
          break;
      }
    } catch (_e) {
      try {
        hilog.warn(Logger.domain, Logger.tag, '%{public}s', 'logger.emit_failed');
      } catch (_e2) {
        // swallow
      }
    }
  }

  static levelLabel(level: LogLevel): string {
    return logLevelName(level);
  }
}

/**
 * 日志等级；与 iOS LogLevel 对齐。
 */
export enum LogLevel {
  VERBOSE = 0,
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4
}

export function logLevelName(level: LogLevel): string {
  switch (level) {
    case LogLevel.VERBOSE:
      return 'verbose';
    case LogLevel.DEBUG:
      return 'debug';
    case LogLevel.INFO:
      return 'info';
    case LogLevel.WARN:
      return 'warn';
    case LogLevel.ERROR:
      return 'error';
    default:
      return 'info';
  }
}

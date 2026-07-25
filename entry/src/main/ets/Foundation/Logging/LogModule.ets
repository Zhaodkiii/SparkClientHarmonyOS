/**
 * 统一日志模块标识；与 iOS LogModule 对齐。
 */
export enum LogModule {
  APP = 'APP',
  AUTH = 'AUTH',
  NETWORK = 'NETWORK',
  DEVICE = 'DEVICE',
  CACHE = 'CACHE',
  OSS = 'OSS',
  AI_CONFIG = 'AI_CONFIG',
  DATABASE = 'DATABASE',
  NOTIFICATION = 'NOTIFICATION',
  LIFECYCLE = 'LIFECYCLE',
  FILE = 'FILE',
  OCR = 'OCR',
  ROUTING = 'ROUTING',
  CAMERA = 'CAMERA',
  HOME = 'HOME',
  GENERAL = 'GENERAL'
}

export function parseLogModule(raw: string | undefined): LogModule {
  if (!raw) {
    return LogModule.GENERAL;
  }
  switch (raw) {
    case 'APP':
      return LogModule.APP;
    case 'AUTH':
      return LogModule.AUTH;
    case 'NETWORK':
      return LogModule.NETWORK;
    case 'DEVICE':
      return LogModule.DEVICE;
    case 'CACHE':
      return LogModule.CACHE;
    case 'OSS':
      return LogModule.OSS;
    case 'AI_CONFIG':
      return LogModule.AI_CONFIG;
    case 'DATABASE':
      return LogModule.DATABASE;
    case 'NOTIFICATION':
      return LogModule.NOTIFICATION;
    case 'LIFECYCLE':
      return LogModule.LIFECYCLE;
    case 'FILE':
      return LogModule.FILE;
    case 'OCR':
      return LogModule.OCR;
    case 'ROUTING':
      return LogModule.ROUTING;
    case 'CAMERA':
      return LogModule.CAMERA;
    case 'HOME':
      return LogModule.HOME;
    default:
      return LogModule.GENERAL;
  }
}

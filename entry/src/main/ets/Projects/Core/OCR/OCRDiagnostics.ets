import { Logger } from '../../../Foundation/Logging/Logger';
import { LogFields } from '../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../Foundation/Logging/LogModule';

/**
 * OCR 诊断日志：只记 phase / textLen / 脱敏文件名，不打印 OCR 全文或完整 URI。
 */
export class OCRDiagnostics {
  static info(event: string, detail: string): void {
    const fields = new LogFields();
    fields.operation = 'ocr_diagnostics';
    fields.detail = detail;
    Logger.info(event, LogModule.OCR, fields);
  }

  static warn(event: string, detail: string): void {
    const fields = new LogFields();
    fields.operation = 'ocr_diagnostics';
    fields.detail = detail;
    Logger.warn(event, LogModule.OCR, fields);
  }

  static errorMessage(error: Object | Error | string | undefined): string {
    if (error === undefined || error === null) {
      return 'undefined';
    }
    if (typeof error === 'string') {
      return error.substring(0, 200);
    }
    if (error instanceof Error) {
      return error.message.substring(0, 200);
    }
    try {
      return `${error}`.substring(0, 200);
    } catch (_e) {
      return 'unprintable_error';
    }
  }

  /** URI 脱敏：只保留末段文件名与 kind 推断。 */
  static uriFingerprint(uri: string): string {
    if (uri.length === 0) {
      return 'empty';
    }
    let kind = 'path';
    if (uri.indexOf('content://') === 0) {
      kind = 'content';
    } else if (uri.indexOf('file://') === 0) {
      kind = 'file';
    } else if (uri.indexOf('datashare://') === 0 || uri.indexOf('media://') === 0) {
      kind = 'media';
    } else if (uri.indexOf('/') === 0) {
      kind = 'sandbox';
    }
    const slash = uri.lastIndexOf('/');
    const name = slash >= 0 ? uri.substring(slash + 1) : uri;
    const shortName = name.length > 48 ? name.substring(0, 48) : name;
    return `kind=${kind};name=${shortName}`;
  }
}

import { LogLevel } from './LogLevel';
import { LogModule } from './LogModule';
import { LogFields } from './LogEvent';
import { Logger } from './Logger';
import { LogSanitizer } from './LogSanitizer';
import { FileTransferError } from '../../Core/FileStorage/FileStorageModels';

/**
 * 错误诊断日志：只提取 name / code / 短 message，禁止 stack 与 JSON.stringify(err)。
 * FileTransferError：核心字段写入白名单；detail 去重后追加短摘要（D-04）。
 */
export class ErrorLogger {
  static log(
    event: string,
    module: LogModule,
    error: Object | Error | string | undefined,
    level: LogLevel = LogLevel.ERROR,
    extra?: LogFields
  ): void {
    const fields = extra ?? new LogFields();
    ErrorLogger.enrichFromFileTransferError(fields, error);
    const summary = ErrorLogger.summarize(error);
    if (!ErrorLogger.detailAlreadyContainsSummary(fields.detail, summary)) {
      fields.detail = fields.detail && fields.detail.length > 0
        ? `${fields.detail}; ${summary}`
        : summary;
    }
    fields.detail = ErrorLogger.dedupeDetailPairs(fields.detail);
    if (level === LogLevel.WARN) {
      Logger.warn(event, module, fields);
    } else if (level === LogLevel.INFO) {
      Logger.info(event, module, fields);
    } else {
      Logger.error(event, module, fields);
    }
  }

  static summarize(error: Object | Error | string | undefined): string {
    if (error === undefined || error === null) {
      return 'unknown_error';
    }
    if (typeof error === 'string') {
      return LogSanitizer.singleLineSnippet(LogSanitizer.redactPlainText(error));
    }
    if (error instanceof FileTransferError) {
      // 短摘要：核心诊断已在 enrich / extra.detail；此处只保留 name/code/stage。
      return `FileTransferError code=${error.code} stage=${error.stage}`;
    }
    try {
      const err = error as Record<string, Object | string | number>;
      const name = typeof err['name'] === 'string' ? err['name'] as string : 'Error';
      let code: string | number | undefined = undefined;
      if (typeof err['code'] === 'number' || typeof err['code'] === 'string') {
        code = err['code'] as string | number;
      }
      let message = '';
      if (typeof err['message'] === 'string') {
        message = err['message'] as string;
      }
      const parts: string[] = [name];
      if (code !== undefined) {
        parts.push(`code=${code}`);
      }
      if (message) {
        parts.push(LogSanitizer.singleLineSnippet(LogSanitizer.redactPlainText(message), 120));
      }
      return parts.join(' ');
    } catch (_e) {
      return 'redaction_failed';
    }
  }

  private static enrichFromFileTransferError(
    fields: LogFields,
    error: Object | Error | string | undefined
  ): void {
    if (!(error instanceof FileTransferError)) {
      return;
    }
    if (fields.code === undefined) {
      fields.code = error.code;
    }
    if (fields.operation === undefined && error.operation) {
      fields.operation = error.operation;
    }
    // D-03：SparkService requestId 与 OSS ossRequestId 分字段。
    if (fields.requestId === undefined && error.requestId) {
      fields.requestId = error.requestId;
    }
    if (fields.ossRequestId === undefined && error.ossRequestId) {
      fields.ossRequestId = error.ossRequestId;
    }
    const diagParts: string[] = [];
    if (error.httpStatus !== undefined) {
      diagParts.push(`httpStatus=${error.httpStatus}`);
    }
    if (error.ossCode) {
      diagParts.push(`ossCode=${error.ossCode}`);
    }
    if (error.ossEc) {
      diagParts.push(`ossEc=${error.ossEc}`);
    }
    if (error.objectKeyFingerprint) {
      diagParts.push(`keyFp=${error.objectKeyFingerprint}`);
    }
    if (error.contentTypeCategory) {
      diagParts.push(`contentTypeCategory=${error.contentTypeCategory}`);
    }
    if (error.stsAgeBucket) {
      diagParts.push(`stsAge=${error.stsAgeBucket}`);
    }
    if (error.transportPolicyVersion) {
      diagParts.push(`policy=${error.transportPolicyVersion}`);
    }
    diagParts.push(`retryable=${error.retryable}`);
    diagParts.push(`stage=${error.stage}`);
    if (diagParts.length === 0) {
      return;
    }
    const merged = diagParts.join(';');
    if (!fields.detail || fields.detail.length === 0) {
      fields.detail = merged;
      return;
    }
    // 若 extra.detail 已含同类键，不再重复拼一整段。
    if (fields.detail.indexOf('httpStatus=') >= 0 || fields.detail.indexOf('ossCode=') >= 0) {
      return;
    }
    fields.detail = `${fields.detail};${merged}`;
  }

  private static detailAlreadyContainsSummary(detail: string | undefined, summary: string): boolean {
    if (!detail || detail.length === 0) {
      return false;
    }
    if (summary.indexOf('FileTransferError code=') === 0) {
      const codeToken = summary.substring('FileTransferError '.length).split(' ')[0];
      return detail.indexOf(codeToken) >= 0;
    }
    return detail.indexOf(summary) >= 0;
  }

  /** 去掉 `key=value` 重复对，保留首次出现。 */
  static dedupeDetailPairs(detail: string | undefined): string | undefined {
    if (detail === undefined || detail.length === 0) {
      return detail;
    }
    const parts = detail.split(';');
    const seenKeys: string[] = [];
    const out: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const raw = parts[i].trim();
      if (raw.length === 0) {
        continue;
      }
      const eq = raw.indexOf('=');
      if (eq <= 0) {
        out.push(raw);
        continue;
      }
      const key = raw.substring(0, eq).trim();
      if (seenKeys.indexOf(key) >= 0) {
        continue;
      }
      seenKeys.push(key);
      out.push(raw);
    }
    return out.join(';');
  }
}

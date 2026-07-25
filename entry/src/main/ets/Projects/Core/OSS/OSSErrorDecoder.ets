import {
  CancelToken,
  ContentTypeCategory,
  FileTransferError,
  FileTransferErrorDiagnostics,
  StsAgeBucket
} from '../../../Core/FileStorage/FileStorageModels';
import { FileTransferL10n } from '../../../Core/FileStorage/FileTransferL10n';

/**
 * Vendor OSS SDK 异常 → 受控 FileTransferError。
 * 仅读取 d.ts / 运行时安全字段；不序列化 rawErrorInfo / 完整 XML。
 * OSS RequestId 只写入 ossRequestId，不写入 requestId。
 */
export class OSSErrorDecodeContext {
  contentTypeCategory: ContentTypeCategory = 'other';
  objectKeyFingerprint: string = '';
  stsAgeBucket: StsAgeBucket = 'unknown';
  hasContentMd5: boolean = false;
  transportPolicyVersion: string = '';
}

export class OSSErrorDecoder {
  static decode(
    err: Object,
    cancelToken?: CancelToken,
    context?: OSSErrorDecodeContext
  ): FileTransferError {
    if (cancelToken && cancelToken.cancelled) {
      return new FileTransferError('cancelled', 'uploading', '已取消', true);
    }
    if (err instanceof FileTransferError) {
      return err;
    }

    const status = OSSErrorDecoder.readNumberField(err, 'status');
    const ossRequestId = OSSErrorDecoder.clip(
      OSSErrorDecoder.readStringField(err, 'requestId'),
      128
    );
    const ossCode = OSSErrorDecoder.clip(OSSErrorDecoder.readCodeField(err), 64);
    const ossEc = OSSErrorDecoder.clip(OSSErrorDecoder.readStringField(err, 'ec'), 64);
    const message = OSSErrorDecoder.readStringField(err, 'message');
    const looksLikeRequestError = status > 0 || ossRequestId.length > 0 ||
      (ossCode.length > 0 && !OSSErrorDecoder.isRcpTransportCode(ossCode));

    let mapped: FileTransferError;
    if (looksLikeRequestError) {
      mapped = OSSErrorDecoder.mapHttpAndCode(status, ossCode);
    } else if (OSSErrorDecoder.isRcpTransportFailure(ossCode, message)) {
      const rcpReason = OSSErrorDecoder.classifyRcpReason(ossCode, message);
      mapped = new FileTransferError(
        'ossTransientFailure',
        'uploading',
        FileTransferL10n.text('file.transfer.error.rcp_transport'),
        true
      );
      const reason = new FileTransferErrorDiagnostics();
      reason.transportRetryable = true;
      reason.userCanRetry = true;
      reason.requestValidationReason = rcpReason;
      mapped = mapped.withDiagnostics(reason);
    } else {
      mapped = new FileTransferError(
        'ossTransientFailure',
        'uploading',
        FileTransferL10n.text('file.transfer.error.transient'),
        true
      );
    }

    const diag = new FileTransferErrorDiagnostics();
    diag.operation = 'oss.put_object';
    const isRcpLayer = !looksLikeRequestError &&
      (mapped.requestValidationReason === 'peerReceiveFailed' ||
        mapped.requestValidationReason === 'serverReturnedNothing' ||
        mapped.requestValidationReason === 'rcpTransport' ||
        mapped.requestValidationReason === 'responseTimeout' ||
        mapped.requestValidationReason === 'connectionClosedByPeer' ||
        mapped.requestValidationReason === 'tlsFailed' ||
        mapped.requestValidationReason === 'unknownRcpTransport' ||
        OSSErrorDecoder.isRcpTransportFailure(ossCode, message));

    // RCP：不得伪造 HTTP status / OSS RequestId / OSS EC；rcp 数字码仅作诊断 ossCode。
    if (!isRcpLayer && ossRequestId.length > 0) {
      diag.ossRequestId = ossRequestId;
    }
    if (!isRcpLayer && status > 0) {
      diag.httpStatus = status;
    }
    if (ossCode.length > 0) {
      diag.ossCode = ossCode;
    }
    if (!isRcpLayer && ossEc.length > 0) {
      diag.ossEc = ossEc;
    }
    if (context) {
      diag.contentTypeCategory = context.contentTypeCategory;
      diag.stsAgeBucket = context.stsAgeBucket;
      if (context.objectKeyFingerprint.length > 0) {
        diag.objectKeyFingerprint = context.objectKeyFingerprint;
      }
      if (context.transportPolicyVersion.length > 0) {
        diag.transportPolicyVersion = context.transportPolicyVersion;
      }
    }
    return mapped.withDiagnostics(diag);
  }

  /**
   * OSS Code 优先，其次 HTTP status。
   * InvalidArgument 在未字段级确认前归入 ossRequestValidationUnknown（可重试 + banner）。
   */
  static mapHttpAndCode(status: number, ossCode: string): FileTransferError {
    const codeUpper = ossCode.trim().toUpperCase();

    if (codeUpper === 'REQUESTTIMETOOSKEWED') {
      return new FileTransferError(
        'ossClockSkew',
        'uploading',
        FileTransferL10n.text('file.transfer.error.clock_skew'),
        false,
        undefined,
        status > 0 ? status : undefined
      );
    }

    if (codeUpper === 'BADDIGEST' || codeUpper === 'INVALIDDIGEST') {
      return new FileTransferError(
        'integrityMismatch',
        'uploading',
        FileTransferL10n.text('file.transfer.error.integrity'),
        false,
        undefined,
        status > 0 ? status : undefined
      );
    }

    if (OSSErrorDecoder.isCredentialExpiryCode(codeUpper) ||
      ((status === 401 || status === 403) && OSSErrorDecoder.isCredentialExpiryCode(codeUpper))) {
      return new FileTransferError(
        'credentialsExpired',
        'uploading',
        FileTransferL10n.text('file.transfer.error.credentials_expired'),
        true,
        undefined,
        status > 0 ? status : undefined
      );
    }

    if (codeUpper === 'ACCESSDENIED' || codeUpper === 'ACCESSFORBIDDEN' ||
      codeUpper === 'ALLACCESSDISABLED' || codeUpper === 'ENTITYTOOLARGE') {
      const denied = new FileTransferError(
        'ossAccessDenied',
        'uploading',
        FileTransferL10n.text('file.transfer.error.access_denied'),
        false,
        undefined,
        status > 0 ? status : undefined
      );
      const reason = new FileTransferErrorDiagnostics();
      reason.transportRetryable = false;
      reason.userCanRetry = false;
      reason.requestValidationReason = 'cloudPolicy';
      return denied.withDiagnostics(reason);
    }

    // 无明确凭证过期 Code 的 401/403：按权限拒绝处理，禁止自动刷新 STS 重试。
    if (status === 401 || status === 403) {
      const denied = new FileTransferError(
        'ossAccessDenied',
        'uploading',
        FileTransferL10n.text('file.transfer.error.access_denied'),
        false,
        undefined,
        status
      );
      const reason = new FileTransferErrorDiagnostics();
      reason.transportRetryable = false;
      reason.userCanRetry = false;
      reason.requestValidationReason = 'cloudPolicy';
      return denied.withDiagnostics(reason);
    }

    if (status === 404 || codeUpper === 'NOSUCHBUCKET' || codeUpper === 'NOSUCHKEY' ||
      codeUpper === 'INVALIDBUCKETNAME') {
      const cfg = new FileTransferError(
        'ossConfigurationInvalid',
        'uploading',
        FileTransferL10n.text('file.transfer.error.configuration'),
        false,
        undefined,
        status > 0 ? status : undefined
      );
      const reason = new FileTransferErrorDiagnostics();
      reason.transportRetryable = false;
      reason.userCanRetry = false;
      reason.requestValidationReason = 'endpointConfig';
      return cfg.withDiagnostics(reason);
    }

    if (status === 409 || status === 412 ||
      codeUpper === 'FILEALREADYEXISTS' || codeUpper === 'POSITIONNOTEQUALTOLENGTH' ||
      codeUpper === 'PRECONDITIONFAILED') {
      return new FileTransferError(
        'ossConflict',
        'uploading',
        FileTransferL10n.text('file.transfer.error.conflict'),
        false,
        undefined,
        status > 0 ? status : undefined
      );
    }

    // 明确指向对象名非法 → 可建议重选；通用 InvalidArgument 不得误导为用户文件问题。
    if (codeUpper === 'INVALIDOBJECTNAME') {
      return new FileTransferError(
        'ossRequestInvalid',
        'uploading',
        FileTransferL10n.text('file.transfer.error.request_invalid_file'),
        false,
        undefined,
        status > 0 ? status : undefined
      );
    }

    if (codeUpper === 'INVALIDARGUMENT' || codeUpper === 'INVALIDREQUEST' ||
      codeUpper === 'MALFORMEDXML' || codeUpper === 'MISSINGARGUMENT' ||
      (status === 400 && codeUpper.length === 0)) {
      const err = new FileTransferError(
        'ossRequestValidationUnknown',
        'uploading',
        FileTransferL10n.text('file.transfer.error.request_validation_unknown'),
        false,
        undefined,
        status > 0 ? status : undefined
      );
      const reason = new FileTransferErrorDiagnostics();
      reason.transportRetryable = false;
      reason.userCanRetry = true;
      reason.requestValidationReason = 'unknown';
      return err.withDiagnostics(reason);
    }

    if (status === 400) {
      const err = new FileTransferError(
        'ossRequestValidationUnknown',
        'uploading',
        FileTransferL10n.text('file.transfer.error.request_validation_unknown'),
        false,
        undefined,
        status
      );
      const reason = new FileTransferErrorDiagnostics();
      reason.transportRetryable = false;
      reason.userCanRetry = true;
      reason.requestValidationReason = 'unknown';
      return err.withDiagnostics(reason);
    }

    if (status >= 500 || status === 429) {
      return new FileTransferError(
        'ossTransientFailure',
        'uploading',
        FileTransferL10n.text('file.transfer.error.transient'),
        true,
        undefined,
        status > 0 ? status : undefined
      );
    }

    if (status >= 400) {
      return new FileTransferError(
        'ossRejected',
        'uploading',
        FileTransferL10n.text('file.transfer.error.access_denied'),
        false,
        undefined,
        status
      );
    }

    return new FileTransferError(
      'ossTransientFailure',
      'uploading',
      FileTransferL10n.text('file.transfer.error.transient'),
      true,
      undefined,
      status > 0 ? status : undefined
    );
  }

  private static isCredentialExpiryCode(codeUpper: string): boolean {
    return codeUpper === 'EXPIREDTOKEN' ||
      codeUpper === 'SECURITYTOKENEXPIRED' ||
      codeUpper === 'INVALIDSECURITYTOKEN' ||
      codeUpper === 'TOKENEXPIRED' ||
      codeUpper === 'INVALIDACCESSKEYID' ||
      codeUpper === 'SIGNATUREDOESNOTMATCH';
  }

  /** Harmony RCP 传输层错误码（如 1007900056），不是 OSS XML Code。 */
  private static isRcpTransportCode(code: string): boolean {
    const trimmed = code.trim();
    if (trimmed.length === 0) {
      return false;
    }
    if (/^\d{8,}$/.test(trimmed)) {
      return true;
    }
    return trimmed.indexOf('10079') === 0;
  }

  private static isRcpTransportFailure(code: string, message: string): boolean {
    if (OSSErrorDecoder.isRcpTransportCode(code)) {
      return true;
    }
    const lower = message.toLowerCase();
    return lower.indexOf('failure when receiving data') >= 0 ||
      lower.indexOf('receiving data from the peer') >= 0 ||
      lower.indexOf('server returned nothing') >= 0 ||
      lower.indexOf('no headers, no data') >= 0 ||
      (lower.indexOf('rcp') >= 0 && lower.indexOf('fail') >= 0);
  }

  /**
   * 细分 RCP reason（仅诊断；用户文案统一为网络不稳定）。
   * peerReceiveFailed | serverReturnedNothing | connectionClosedByPeer |
   * responseTimeout | tlsFailed | rcpTransport | unknownRcpTransport
   */
  static classifyRcpReason(code: string, message: string): string {
    const lower = message.toLowerCase();
    if (lower.indexOf('failure when receiving') >= 0 ||
      lower.indexOf('receiving data from the peer') >= 0 ||
      code === '1007900056') {
      return 'peerReceiveFailed';
    }
    if (lower.indexOf('server returned nothing') >= 0 ||
      lower.indexOf('no headers, no data') >= 0 ||
      code === '1007900052') {
      return 'serverReturnedNothing';
    }
    if (lower.indexOf('timeout') >= 0) {
      return 'responseTimeout';
    }
    if (lower.indexOf('tls') >= 0 || lower.indexOf('ssl') >= 0) {
      return 'tlsFailed';
    }
    if (lower.indexOf('closed') >= 0 || lower.indexOf('reset') >= 0) {
      return 'connectionClosedByPeer';
    }
    if (OSSErrorDecoder.isRcpTransportCode(code)) {
      return 'rcpTransport';
    }
    return 'unknownRcpTransport';
  }

  /** Adapter / Localizer / VM 共用：是否属于 RCP 传输层 reason。 */
  static isRcpTransportReason(reason: string): boolean {
    return reason === 'peerReceiveFailed' ||
      reason === 'serverReturnedNothing' ||
      reason === 'rcpTransport' ||
      reason === 'responseTimeout' ||
      reason === 'connectionClosedByPeer' ||
      reason === 'tlsFailed' ||
      reason === 'unknownRcpTransport';
  }

  /** code 可能是 OSS 字符串，也可能是 RCP 数字错误码。 */
  static readCodeField(err: Object): string {
    const asStr = OSSErrorDecoder.readStringField(err, 'code');
    if (asStr.length > 0) {
      return asStr;
    }
    const asNum = OSSErrorDecoder.readNumberField(err, 'code');
    if (asNum > 0) {
      return `${asNum}`;
    }
    return '';
  }

  static readNumberField(err: Object, key: string): number {
    try {
      const rec = err as Record<string, Object | string | number | boolean | null>;
      const v = rec[key];
      if (typeof v === 'number' && Number.isFinite(v)) {
        return v;
      }
      if (typeof v === 'string' && v.length > 0) {
        const n = Number(v);
        if (!Number.isNaN(n)) {
          return n;
        }
      }
    } catch (_e) {
      // ignore
    }
    return 0;
  }

  static readStringField(err: Object, key: string): string {
    try {
      const rec = err as Record<string, Object | string | number | boolean | null>;
      const v = rec[key];
      if (typeof v === 'string') {
        return v;
      }
    } catch (_e) {
      // ignore
    }
    return '';
  }

  private static clip(value: string, max: number): string {
    if (value.length <= max) {
      return value;
    }
    return value.substring(0, max);
  }
}

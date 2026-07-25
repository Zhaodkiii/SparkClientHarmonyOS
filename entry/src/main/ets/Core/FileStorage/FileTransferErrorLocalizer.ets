import { FileTransferError, FileTransferErrorCode } from './FileStorageModels';
import { FileTransferL10n } from './FileTransferL10n';
import { SupportNetworkError } from '../../Projects/Core/Networking/SupportNetworkModels';
import { OSSErrorDecoder } from '../../Projects/Core/OSS/OSSErrorDecoder';

/** 页面可执行恢复动作。 */
export type FileTransferUserAction =
  | 'retryUpload'
  | 'retryRegister'
  | 'returnToPicking'
  | 'reselectFile'
  | 'cancel'
  | 'none';

/**
 * FileTransferError / SupportNetworkError → 用户文案与动作模型。
 * 文案全部经 FileTransferL10n；不读取 SDK 原始对象。
 */
export class FileTransferErrorPresentation {
  normalizedErrorCode: string = 'unknown';
  message: string = '';
  title: string = '';
  primaryAction: FileTransferUserAction = 'none';
  secondaryAction: FileTransferUserAction = 'none';
  /** 是否走全局 Notification banner。局部校验类可为 false。 */
  showGlobalBanner: boolean = true;
  /** banner 级别：error / warning；cancelled 为 none。 */
  bannerLevel: 'error' | 'warning' | 'none' = 'error';
  retryable: boolean = false;
  stage: string = '';
}

export class FileTransferErrorLocalizer {
  static present(error: Object | Error | string | undefined): FileTransferErrorPresentation {
    if (error instanceof FileTransferError) {
      return FileTransferErrorLocalizer.fromFileTransferError(error);
    }
    if (error instanceof SupportNetworkError) {
      return FileTransferErrorLocalizer.fromNetworkError(error);
    }
    if (error instanceof Error) {
      const p = new FileTransferErrorPresentation();
      p.normalizedErrorCode = 'unknown';
      p.message = FileTransferErrorLocalizer.safeFallbackMessage(error.message);
      p.title = FileTransferL10n.text('file.transfer.error.title');
      p.primaryAction = 'retryUpload';
      p.secondaryAction = 'returnToPicking';
      p.retryable = true;
      p.showGlobalBanner = true;
      p.bannerLevel = 'error';
      return p;
    }
    const unknown = new FileTransferErrorPresentation();
    unknown.normalizedErrorCode = 'unknown';
    unknown.message = FileTransferL10n.text('file.transfer.error.unknown');
    unknown.title = FileTransferL10n.text('file.transfer.error.title');
    unknown.primaryAction = 'retryUpload';
    unknown.secondaryAction = 'returnToPicking';
    unknown.retryable = true;
    unknown.showGlobalBanner = true;
    unknown.bannerLevel = 'error';
    return unknown;
  }

  static fromFileTransferError(error: FileTransferError): FileTransferErrorPresentation {
    const p = new FileTransferErrorPresentation();
    p.normalizedErrorCode = error.code;
    p.stage = error.stage;
    // UI 可重试看 userCanRetry；自动重试看 transportRetryable（服务层使用）。
    p.retryable = error.userCanRetry;
    p.title = FileTransferErrorLocalizer.titleFor(error.code);
    p.message = FileTransferErrorLocalizer.messageFor(error);
    FileTransferErrorLocalizer.applyActions(p, error.code);
    return p;
  }

  private static fromNetworkError(error: SupportNetworkError): FileTransferErrorPresentation {
    const p = new FileTransferErrorPresentation();
    if (error.statusCode === 401 || error.kind === 'unauthenticated' || error.kind === 'refreshFailed') {
      p.normalizedErrorCode = 'unauthorized';
      p.message = FileTransferL10n.text('file.transfer.error.unauthorized');
      p.title = FileTransferL10n.text('file.transfer.error.title.unauthorized');
      p.primaryAction = 'returnToPicking';
      p.secondaryAction = 'none';
      p.retryable = false;
      p.showGlobalBanner = true;
      p.bannerLevel = 'error';
      return p;
    }
    if (error.kind === 'cancelled') {
      p.normalizedErrorCode = 'cancelled';
      p.message = '';
      p.title = '';
      p.primaryAction = 'none';
      p.secondaryAction = 'none';
      p.retryable = true;
      p.showGlobalBanner = false;
      p.bannerLevel = 'none';
      return p;
    }
    p.normalizedErrorCode = 'networkUnavailable';
    p.message = FileTransferL10n.text('file.transfer.error.network');
    p.title = FileTransferL10n.text('file.transfer.error.title.network');
    p.primaryAction = 'retryUpload';
    p.secondaryAction = 'returnToPicking';
    p.retryable = true;
    p.showGlobalBanner = true;
    p.bannerLevel = 'error';
    return p;
  }

  private static messageFor(error: FileTransferError): string {
    if (error.safeMessage.length > 0 && !FileTransferErrorLocalizer.looksTechnical(error.safeMessage)) {
      return error.safeMessage;
    }
    if (error.code === 'ossTransientFailure' &&
      OSSErrorDecoder.isRcpTransportReason(error.requestValidationReason ?? '')) {
      return FileTransferL10n.text('file.transfer.error.rcp_transport');
    }
    return FileTransferErrorLocalizer.messageByCode(error.code);
  }

  private static messageByCode(code: FileTransferErrorCode): string {
    switch (code) {
      case 'networkUnavailable':
        return FileTransferL10n.text('file.transfer.error.network');
      case 'credentialsExpired':
        return FileTransferL10n.text('file.transfer.error.credentials_expired');
      case 'ossClockSkew':
        return FileTransferL10n.text('file.transfer.error.clock_skew');
      case 'ossAccessDenied':
      case 'ossRejected':
        return FileTransferL10n.text('file.transfer.error.access_denied');
      case 'integrityMismatch':
        return FileTransferL10n.text('file.transfer.error.integrity');
      case 'ossRequestValidationUnknown':
        return FileTransferL10n.text('file.transfer.error.request_validation_unknown');
      case 'ossRequestInvalid':
        return FileTransferL10n.text('file.transfer.error.request_invalid_file');
      case 'sourceInvalid':
      case 'localIoFailed':
        return FileTransferL10n.text('file.transfer.error.source_invalid');
      case 'ossConfigurationInvalid':
        return FileTransferL10n.text('file.transfer.error.configuration');
      case 'ossConflict':
        return FileTransferL10n.text('file.transfer.error.conflict');
      case 'ossTransientFailure':
        return FileTransferL10n.text('file.transfer.error.transient');
      case 'multipartInitiateFailed':
        return FileTransferL10n.text('file.transfer.error.multipart_initiate');
      case 'multipartPartUploadFailed':
        return FileTransferL10n.text('file.transfer.error.multipart_part');
      case 'multipartPartIntegrityMismatch':
        return FileTransferL10n.text('file.transfer.error.multipart_integrity');
      case 'multipartListPartsFailed':
        return FileTransferL10n.text('file.transfer.error.multipart_list');
      case 'multipartCompleteFailed':
        return FileTransferL10n.text('file.transfer.error.multipart_complete');
      case 'multipartAbortFailed':
        return FileTransferL10n.text('file.transfer.error.multipart_abort');
      case 'multipartCheckpointInvalid':
      case 'multipartUploadExpired':
        return FileTransferL10n.text('file.transfer.error.multipart_checkpoint');
      case 'multipartRegistrationPending':
      case 'registrationPending':
      case 'unknownRegistrationOutcome':
      case 'serverContractViolation':
        return FileTransferL10n.text('file.transfer.error.registration_pending');
      case 'unauthorized':
        return FileTransferL10n.text('file.transfer.error.unauthorized');
      case 'cancelled':
        return '';
      case 'generationMismatch':
        return FileTransferL10n.text('file.transfer.error.generation');
      case 'fileUnavailable':
        return FileTransferL10n.text('file.transfer.error.unavailable');
      default:
        return FileTransferL10n.text('file.transfer.error.unknown');
    }
  }

  private static titleFor(code: FileTransferErrorCode): string {
    switch (code) {
      case 'registrationPending':
      case 'unknownRegistrationOutcome':
      case 'serverContractViolation':
        return FileTransferL10n.text('file.transfer.error.title.pending_save');
      case 'cancelled':
        return '';
      default:
        return FileTransferL10n.text('file.transfer.error.title');
    }
  }

  private static applyActions(p: FileTransferErrorPresentation, code: FileTransferErrorCode): void {
    switch (code) {
      case 'cancelled':
        p.primaryAction = 'none';
        p.secondaryAction = 'none';
        p.showGlobalBanner = false;
        p.bannerLevel = 'none';
        break;
      case 'integrityMismatch':
      case 'ossRequestInvalid':
      case 'sourceInvalid':
      case 'localIoFailed':
        // 仅本地/明确文件内容问题时 inline + 重选；不发全局 banner。
        p.primaryAction = 'reselectFile';
        p.secondaryAction = 'returnToPicking';
        p.showGlobalBanner = false;
        p.bannerLevel = 'none';
        break;
      case 'ossRequestValidationUnknown':
        // N-01：确定性 400 不进自动重试；用户可手动试一次（VM 相同 fingerprint 二次降级）。
        p.primaryAction = p.retryable ? 'retryUpload' : 'returnToPicking';
        p.secondaryAction = 'returnToPicking';
        p.showGlobalBanner = true;
        p.bannerLevel = 'error';
        break;
      case 'registrationPending':
      case 'unknownRegistrationOutcome':
      case 'serverContractViolation':
        p.primaryAction = 'retryRegister';
        p.secondaryAction = 'returnToPicking';
        p.showGlobalBanner = true;
        p.bannerLevel = 'warning';
        break;
      case 'ossAccessDenied':
      case 'ossConfigurationInvalid':
      case 'ossRejected':
      case 'ossClockSkew':
      case 'ossConflict':
        // 权限/配置类：禁止引导反复重试上传；主动作返回选择。
        p.primaryAction = 'returnToPicking';
        p.secondaryAction = 'none';
        p.retryable = false;
        p.showGlobalBanner = true;
        p.bannerLevel = 'error';
        break;
      case 'credentialsExpired':
      case 'ossTransientFailure':
      case 'networkUnavailable':
      case 'multipartInitiateFailed':
      case 'multipartPartUploadFailed':
      case 'multipartPartIntegrityMismatch':
      case 'multipartListPartsFailed':
      case 'multipartCompleteFailed':
        p.primaryAction = 'retryUpload';
        p.secondaryAction = 'returnToPicking';
        p.showGlobalBanner = true;
        p.bannerLevel = 'error';
        break;
      case 'multipartCheckpointInvalid':
      case 'multipartUploadExpired':
        p.primaryAction = 'reselectFile';
        p.secondaryAction = 'returnToPicking';
        p.retryable = false;
        p.showGlobalBanner = true;
        p.bannerLevel = 'error';
        break;
      case 'multipartAbortFailed':
        p.primaryAction = 'returnToPicking';
        p.secondaryAction = 'none';
        p.showGlobalBanner = false;
        p.bannerLevel = 'none';
        break;
      case 'unauthorized':
      case 'generationMismatch':
        p.primaryAction = 'returnToPicking';
        p.secondaryAction = 'cancel';
        p.showGlobalBanner = true;
        p.bannerLevel = 'error';
        break;
      default:
        p.primaryAction = p.retryable ? 'retryUpload' : 'returnToPicking';
        p.secondaryAction = 'returnToPicking';
        p.showGlobalBanner = true;
        p.bannerLevel = 'error';
        break;
    }
  }

  private static looksTechnical(message: string): boolean {
    const lower = message.toLowerCase();
    return lower.indexOf('oss') >= 0 ||
      lower.indexOf('http') >= 0 ||
      lower.indexOf('requestid') >= 0 ||
      lower.indexOf('accessdenied') >= 0 ||
      lower.indexOf('baddigest') >= 0 ||
      lower.indexOf('invalidargument') >= 0 ||
      lower.indexOf('status=') >= 0;
  }

  private static safeFallbackMessage(raw: string): string {
    if (!raw || raw.length === 0 || FileTransferErrorLocalizer.looksTechnical(raw)) {
      return FileTransferL10n.text('file.transfer.error.unknown');
    }
    if (raw.length > 120) {
      return raw.substring(0, 120);
    }
    return raw;
  }

  static primaryActionLabel(action: FileTransferUserAction): string {
    switch (action) {
      case 'retryUpload':
        return FileTransferL10n.text('file.transfer.action.retry_upload');
      case 'retryRegister':
        return FileTransferL10n.text('file.transfer.action.retry_save');
      case 'returnToPicking':
        return FileTransferL10n.text('file.transfer.action.return_picking');
      case 'reselectFile':
        return FileTransferL10n.text('file.transfer.action.reselect');
      case 'cancel':
        return FileTransferL10n.text('file.transfer.action.cancel');
      default:
        return '';
    }
  }

  static secondaryActionLabel(action: FileTransferUserAction): string {
    switch (action) {
      case 'returnToPicking':
        return FileTransferL10n.text('file.transfer.action.return_picking');
      case 'cancel':
        return FileTransferL10n.text('file.transfer.action.cancel');
      case 'reselectFile':
        return FileTransferL10n.text('file.transfer.action.remove');
      case 'retryUpload':
        return FileTransferL10n.text('file.transfer.action.retry_upload');
      case 'retryRegister':
        return FileTransferL10n.text('file.transfer.action.retry_save');
      default:
        return '';
    }
  }
}

/**
 * 文件传输领域模型：远端记录、上传命令、本地缓存句柄、进度快照与错误。
 * 不含 HTTP/SDK 调用。
 */

export type FileTransferPhase =
  | 'preparing'
  | 'cached'
  | 'acquiringCredentials'
  | 'uploading'
  | 'registering'
  | 'completed'
  | 'failed'
  | 'cancelled'
  | 'uploadedUnregistered'
  | 'downloading';

export type FileCacheState =
  | 'ready'
  | 'downloading'
  | 'failed'
  | 'pending_delete'
  | 'uploaded_unregistered'
  | 'staging';

export type FileTransferErrorCode =
  | 'sourceInvalid'
  | 'localIoFailed'
  | 'networkUnavailable'
  | 'unauthorized'
  | 'credentialsExpired'
  | 'ossRejected'
  | 'ossClockSkew'
  | 'ossAccessDenied'
  | 'ossRequestInvalid'
  | 'ossRequestValidationUnknown'
  | 'ossConfigurationInvalid'
  | 'ossConflict'
  | 'ossTransientFailure'
  | 'multipartInitiateFailed'
  | 'multipartPartUploadFailed'
  | 'multipartPartIntegrityMismatch'
  | 'multipartListPartsFailed'
  | 'multipartCompleteFailed'
  | 'multipartAbortFailed'
  | 'multipartCheckpointInvalid'
  | 'multipartUploadExpired'
  | 'multipartRegistrationPending'
  | 'registrationPending'
  | 'fileUnavailable'
  | 'integrityMismatch'
  | 'cancelled'
  | 'serverContractViolation'
  | 'unknownRegistrationOutcome'
  | 'generationMismatch';

/** STS 相对过期状态（仅诊断，不进用户文案）。 */
export type StsAgeBucket = 'fresh' | 'near_expiry' | 'refreshed_once' | 'unknown';

/** 内容类型粗分类（仅诊断）。 */
export type ContentTypeCategory = 'image' | 'pdf' | 'other';

export class ManagedFileRecord {
  id: number = 0;
  fileUuid: string = '';
  filePath: string = '';
  originalName: string = '';
  fileSize: number = 0;
  mimeType: string = '';
  fileMd5: string = '';
  isPublic: boolean = false;
  businessType: string = '';
  businessId: string = '';
  objectKey: string = '';
  storageType: string = 'oss';
  createdAt: string = '';
}

export class FileRegistrationBody {
  file_uuid: string = '';
  original_name: string = '';
  file_size: number = 0;
  mime_type: string = '';
  file_path: string = '';
  object_key: string = '';
  storage_type: string = 'oss';
  business_type: string = '';
  business_id: string = '';
  is_public: boolean = false;
  file_md5: string = '';
}

export class FileBusinessUpdateBody {
  file_id: number = 0;
  business_type: string = '';
  business_id: string = '';
}

export class FileDownloadUrlPayload {
  url: string = '';
}

export class FileUploadRequest {
  transferId: string = '';
  accountId: number = 0;
  generation: number = 0;
  sourceUri: string = '';
  originalName: string = '';
  businessType: string = '';
  businessId: string = '';
  isPublic: boolean = false;
  mimeType: string = 'application/octet-stream';
}

export class FileDownloadOptions {
  forceRefresh: boolean = false;
  expectedMd5: string = '';
  /** >0 时与当前 session generation 比对；切号后旧任务不得写当前账号缓存。 */
  generation: number = 0;
}

export class LocalFileHandle {
  fileUuid: string = '';
  localPath: string = '';
  originalName: string = '';
  fileSize: number = 0;
  fileMd5: string = '';
  remoteFileId: number = 0;
}

export class FileTransferSnapshot {
  transferId: string = '';
  accountIdHash: string = '';
  fileUuid: string = '';
  phase: FileTransferPhase = 'preparing';
  bytesSent: number = 0;
  totalBytes: number = 0;
  progress: number = 0;
  remoteFileId?: number;
  retryable: boolean = false;
  updatedAt: number = 0;
  safeMessage: string = '';
}

/**
 * 受控传输错误。用户可见文案只用 safeMessage；诊断字段仅进脱敏日志。
 * requestId = SparkService X-Request-ID；ossRequestId = 阿里云 OSS RequestId；二者不得混用。
 */
export class FileTransferError extends Error {
  code: FileTransferErrorCode;
  stage: FileTransferPhase;
  retryable: boolean;
  /** SparkService / 网关请求 ID。 */
  requestId?: string;
  /** 阿里云 OSS RequestId。 */
  ossRequestId?: string;
  httpStatus?: number;
  safeMessage: string;
  /** OSS XML/SDK Code，最多 64 字符；不对用户展示。 */
  ossCode?: string;
  /** OSS EC，最多 64 字符。 */
  ossEc?: string;
  /** 固定如 oss.put_object。 */
  operation?: string;
  /** object key 不可逆摘要 + 长度，禁止原文。 */
  objectKeyFingerprint?: string;
  contentTypeCategory?: ContentTypeCategory;
  stsAgeBucket?: StsAgeBucket;
  /** 传输策略版本摘要（仅诊断）。 */
  transportPolicyVersion?: string;
  /**
   * 是否允许 FileTransferService/网络层自动重试。
   * 400 InvalidArgument 等确定性参数错误为 false。
   */
  transportRetryable: boolean = false;
  /** 是否允许用户手动再试一次。 */
  userCanRetry: boolean = false;
  /**
   * 参数校验原因粗分类（未确认前为 unknown）。
   * contentType / objectKey / payloadMode / endpointConfig / cloudPolicy / unknown
   */
  requestValidationReason?: string;

  constructor(
    code: FileTransferErrorCode,
    stage: FileTransferPhase,
    safeMessage: string,
    retryable: boolean,
    requestId?: string,
    httpStatus?: number
  ) {
    super(safeMessage);
    this.name = 'FileTransferError';
    this.code = code;
    this.stage = stage;
    this.safeMessage = safeMessage;
    this.retryable = retryable;
    this.transportRetryable = retryable;
    this.userCanRetry = retryable;
    this.requestId = requestId;
    this.httpStatus = httpStatus;
  }

  /** 链式写入诊断字段；不改变用户文案。 */
  withDiagnostics(partial: FileTransferErrorDiagnostics): FileTransferError {
    if (partial.ossCode !== undefined && partial.ossCode.length > 0) {
      this.ossCode = FileTransferError.clip(partial.ossCode, 64);
    }
    if (partial.ossEc !== undefined && partial.ossEc.length > 0) {
      this.ossEc = FileTransferError.clip(partial.ossEc, 64);
    }
    if (partial.operation !== undefined && partial.operation.length > 0) {
      this.operation = FileTransferError.clip(partial.operation, 64);
    }
    if (partial.objectKeyFingerprint !== undefined && partial.objectKeyFingerprint.length > 0) {
      this.objectKeyFingerprint = FileTransferError.clip(partial.objectKeyFingerprint, 96);
    }
    if (partial.contentTypeCategory !== undefined) {
      this.contentTypeCategory = partial.contentTypeCategory;
    }
    if (partial.stsAgeBucket !== undefined) {
      this.stsAgeBucket = partial.stsAgeBucket;
    }
    if (partial.transportPolicyVersion !== undefined && partial.transportPolicyVersion.length > 0) {
      this.transportPolicyVersion = FileTransferError.clip(partial.transportPolicyVersion, 64);
    }
    if (partial.requestValidationReason !== undefined && partial.requestValidationReason.length > 0) {
      this.requestValidationReason = FileTransferError.clip(partial.requestValidationReason, 32);
    }
    if (partial.transportRetryable !== undefined) {
      this.transportRetryable = partial.transportRetryable;
      this.retryable = partial.transportRetryable;
    }
    if (partial.userCanRetry !== undefined) {
      this.userCanRetry = partial.userCanRetry;
    }
    // SparkService ID 与 OSS ID 分字段，禁止互相覆盖。
    if (partial.requestId !== undefined && partial.requestId.length > 0 && !this.requestId) {
      this.requestId = FileTransferError.clip(partial.requestId, 128);
    }
    if (partial.ossRequestId !== undefined && partial.ossRequestId.length > 0 && !this.ossRequestId) {
      this.ossRequestId = FileTransferError.clip(partial.ossRequestId, 128);
    }
    if (partial.httpStatus !== undefined && partial.httpStatus > 0 && this.httpStatus === undefined) {
      this.httpStatus = partial.httpStatus;
    }
    return this;
  }

  private static clip(value: string, max: number): string {
    if (value.length <= max) {
      return value;
    }
    return value.substring(0, max);
  }
}

/** FileTransferError.withDiagnostics 入参。 */
export class FileTransferErrorDiagnostics {
  ossCode?: string;
  ossEc?: string;
  operation?: string;
  objectKeyFingerprint?: string;
  contentTypeCategory?: ContentTypeCategory;
  stsAgeBucket?: StsAgeBucket;
  transportPolicyVersion?: string;
  requestValidationReason?: string;
  transportRetryable?: boolean;
  userCanRetry?: boolean;
  /** 仅 SparkService X-Request-ID。 */
  requestId?: string;
  /** 仅阿里云 OSS RequestId。 */
  ossRequestId?: string;
  httpStatus?: number;
}

export class FileCacheRecord {
  accountIdHash: string = '';
  fileId: number = 0;
  fileUuid: string = '';
  localPath: string = '';
  originalName: string = '';
  fileSize: number = 0;
  fileMd5: string = '';
  objectKey: string = '';
  state: FileCacheState = 'staging';
  mimeType: string = 'application/octet-stream';
  businessType: string = '';
  businessId: string = '';
  isPublic: boolean = false;
  lastAccessedAt: number = 0;
  createdAt: number = 0;
  updatedAt: number = 0;
}

export class DownloadProgressEvent {
  bytesReceived: number = 0;
  totalBytes: number = 0;
}

export type DownloadProgressListener = (event: DownloadProgressEvent) => void;

export class StagedUploadFile {
  fileUuid: string = '';
  localPath: string = '';
  originalName: string = '';
  fileSize: number = 0;
  fileMd5: string = '';
  mimeType: string = 'application/octet-stream';
}

export class CancelToken {
  private _cancelled: boolean = false;

  get cancelled(): boolean {
    return this._cancelled;
  }

  cancel(): void {
    this._cancelled = true;
  }

  throwIfCancelled(stage: FileTransferPhase = 'cancelled'): void {
    if (this._cancelled) {
      throw new FileTransferError('cancelled', stage, '已取消', true);
    }
  }
}

export function parseFileTransferPhase(raw: string): FileTransferPhase {
  switch (raw) {
    case 'preparing':
    case 'cached':
    case 'acquiringCredentials':
    case 'uploading':
    case 'registering':
    case 'completed':
    case 'failed':
    case 'cancelled':
    case 'uploadedUnregistered':
    case 'downloading':
      return raw;
    default:
      return 'failed';
  }
}

export function parseFileCacheState(raw: string): FileCacheState {
  switch (raw) {
    case 'ready':
    case 'downloading':
    case 'failed':
    case 'pending_delete':
    case 'uploaded_unregistered':
    case 'staging':
      return raw;
    default:
      return 'failed';
  }
}

export function contentTypeCategoryOf(mimeType: string): ContentTypeCategory {
  const lower = mimeType.trim().toLowerCase();
  if (lower.indexOf('image/') === 0) {
    return 'image';
  }
  if (lower === 'application/pdf' || lower.indexOf('pdf') >= 0) {
    return 'pdf';
  }
  return 'other';
}

export function stsAgeBucketOf(expirationEpochSeconds: number, refreshedOnce: boolean = false): StsAgeBucket {
  if (refreshedOnce) {
    return 'refreshed_once';
  }
  if (expirationEpochSeconds <= 0) {
    return 'unknown';
  }
  const nowSec = Math.floor(Date.now() / 1000);
  const remain = expirationEpochSeconds - nowSec;
  if (remain > 300) {
    return 'fresh';
  }
  if (remain > 0) {
    return 'near_expiry';
  }
  return 'unknown';
}

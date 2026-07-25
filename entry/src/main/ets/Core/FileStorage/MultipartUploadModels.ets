/**
 * Multipart 领域模型与断点快照（HOS-FILE-OSS-0008）。
 * 断点可持久化 uploadId（恢复必需）；日志仅用 uploadIdHash，禁止打原文。
 */

export type MultipartPartStatus = 'pending' | 'uploading' | 'succeeded' | 'failed';
export type MultipartCheckpointStatus =
  | 'initiated'
  | 'uploading'
  | 'completing'
  | 'completed'
  | 'aborting'
  | 'aborted'
  | 'failed'
  | 'pending_abort';

export class MultipartPartRecord {
  partNumber: number = 0;
  offset: number = 0;
  length: number = 0;
  attempt: number = 0;
  /** ETag 摘要（日志用）；完整 ETag 仅存 checkpoint。 */
  etagHash: string = '';
  /** 完整 ETag，仅 checkpoint / Complete 使用，禁止进日志。 */
  etag: string = '';
  status: MultipartPartStatus = 'pending';
  lastErrorCode: string = '';
  lastRequestId: string = '';
  completedAt: number = 0;
}

export class MultipartUploadCheckpoint {
  checkpointVersion: string = 'v1';
  /** 完整 uploadId，仅持久化层使用。 */
  uploadId: string = '';
  uploadIdHash: string = '';
  bucketFp: string = '';
  objectKey: string = '';
  objectKeyFp: string = '';
  fileUuid: string = '';
  localPath: string = '';
  fileSize: number = 0;
  fileMd5: string = '';
  mimeType: string = '';
  partSize: number = 0;
  totalParts: number = 0;
  accountId: number = 0;
  generation: number = 0;
  createdAt: number = 0;
  updatedAt: number = 0;
  status: MultipartCheckpointStatus = 'initiated';
  policyVersion: string = '';
  parts: MultipartPartRecord[] = [];
  pendingAbort: boolean = false;
  abortReason: string = '';
}

export class MultipartUploadInput {
  localPath: string = '';
  objectKey: string = '';
  contentType: string = 'application/octet-stream';
  contentLength: number = 0;
  contentMd5Hex: string = '';
  fileUuid: string = '';
  accountId: number = 0;
  generation: number = 0;
  transferIdHash: string = '';
  partSize: number = 0;
  totalParts: number = 0;
}

export class ManagedFileUploadResult {
  mode: string = 'simple';
  objectKey: string = '';
  fileSize: number = 0;
  uploadIdHash: string = '';
  totalParts: number = 0;
}

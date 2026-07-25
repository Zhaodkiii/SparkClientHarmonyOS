import { OSSRuntimeConfig } from '../../Projects/Core/OSS/OSSRuntimeConfig';
import { OSSMultipartUploadAdapter } from '../../Projects/Core/OSS/OSSMultipartUploadAdapter';
import { OSSDiagnosticFingerprint } from '../../Projects/Core/OSS/OSSDiagnosticFingerprint';
import { FileUploadCheckpointStore } from './FileUploadCheckpointStore';
import { FileUploadMode } from './FileUploadMode';
import {
  ManagedFileUploadResult,
  MultipartPartRecord,
  MultipartUploadCheckpoint,
  MultipartUploadInput
} from './MultipartUploadModels';
import {
  CancelToken,
  FileTransferError,
  FileTransferPhase
} from './FileStorageModels';
import { FileTransferL10n } from './FileTransferL10n';
import { ObjectKeyPolicy } from './ObjectKeyPolicy';
import { OSSErrorDecoder } from '../../Projects/Core/OSS/OSSErrorDecoder';

/**
 * 分片上传编排（HOS-FILE-OSS-0008）。
 * 顺序 uploadPart（并发=1）；checkpoint 持久化；Complete 成功前不得登记。
 * 不 import Vendor SDK；Client 仅由 OSSMultipartUploadAdapter 持有。
 */
export class MultipartUploadService {
  private readonly adapter: OSSMultipartUploadAdapter;
  private readonly checkpointStore: FileUploadCheckpointStore;
  private activeUploadId: string = '';
  private activeObjectKey: string = '';

  constructor(
    checkpointStore: FileUploadCheckpointStore,
    adapter?: OSSMultipartUploadAdapter
  ) {
    this.checkpointStore = checkpointStore;
    this.adapter = adapter ?? new OSSMultipartUploadAdapter();
  }

  async upload(
    input: MultipartUploadInput,
    cfg: OSSRuntimeConfig,
    cancelToken?: CancelToken,
    onProgress?: (phase: FileTransferPhase, bytesSent: number, totalBytes: number) => void
  ): Promise<ManagedFileUploadResult> {
    ObjectKeyPolicy.assertKeyValid(input.objectKey);
    if (input.contentLength <= 0 || input.localPath.length === 0) {
      throw new FileTransferError(
        'sourceInvalid',
        'uploading',
        FileTransferL10n.text('file.transfer.error.source_invalid'),
        false
      );
    }
    const partSize = input.partSize > 0 ? input.partSize : FileUploadMode.PART_SIZE_BYTES;
    const totalParts = input.totalParts > 0
      ? input.totalParts
      : FileUploadMode.computeTotalParts(input.contentLength, partSize);

    let checkpoint: MultipartUploadCheckpoint | undefined = undefined;
    try {
      this.adapter.createSession(cfg);
      this.activeObjectKey = input.objectKey;

      checkpoint = await this.loadOrCreateCheckpoint(input, cfg, partSize, totalParts);
      this.activeUploadId = checkpoint.uploadId;

      for (let partNumber = 1; partNumber <= totalParts; partNumber++) {
        cancelToken?.throwIfCancelled('uploading');
        const part = MultipartUploadService.findOrCreatePart(
          checkpoint, partNumber, partSize, input.contentLength
        );
        if (part.status === 'succeeded' && part.etag.length > 0) {
          continue;
        }
        await this.uploadPartWithRetry(cfg, input, checkpoint, part, cancelToken);
        if (onProgress) {
          const sent = Math.min(part.offset + part.length, input.contentLength);
          onProgress('uploading', sent, input.contentLength);
        }
      }

      cancelToken?.throwIfCancelled('uploading');
      checkpoint.status = 'completing';
      await this.checkpointStore.save(checkpoint);
      await this.adapter.complete(
        this.adapter.requireActiveClient(),
        cfg,
        input.objectKey,
        checkpoint.uploadId,
        totalParts
      );

      checkpoint.status = 'completed';
      await this.checkpointStore.remove(input.fileUuid, input.accountId);

      const result = new ManagedFileUploadResult();
      result.mode = 'multipart';
      result.objectKey = input.objectKey;
      result.fileSize = input.contentLength;
      result.uploadIdHash = checkpoint.uploadIdHash;
      result.totalParts = totalParts;
      return result;
    } catch (err) {
      if (cancelToken?.cancelled) {
        await this.tryAbort(cfg, input.objectKey, this.activeUploadId, 'cancelled', checkpoint);
        throw new FileTransferError('cancelled', 'cancelled', '已取消', true);
      }
      if (err instanceof FileTransferError &&
        (err.code === 'ossAccessDenied' || err.code === 'ossConfigurationInvalid' ||
          err.code === 'multipartCheckpointInvalid')) {
        await this.tryAbort(cfg, input.objectKey, this.activeUploadId, 'invalid', checkpoint);
      } else if (checkpoint && checkpoint.uploadId.length > 0) {
        checkpoint.status = 'failed';
        await this.checkpointStore.save(checkpoint);
      }
      if (err instanceof FileTransferError) {
        throw err;
      }
      if (err instanceof Error) {
        throw err;
      }
      throw new FileTransferError(
        'ossTransientFailure',
        'uploading',
        FileTransferL10n.text('file.transfer.error.transient'),
        true
      );
    } finally {
      this.adapter.closeActive();
      this.activeUploadId = '';
      this.activeObjectKey = '';
    }
  }

  cancelActive(): void {
    this.adapter.cancelActive();
  }

  async onAccountInvalidated(accountId: number, cfg?: OSSRuntimeConfig): Promise<void> {
    const pending = await this.checkpointStore.listPendingAbort(accountId);
    if (cfg) {
      for (let i = 0; i < pending.length; i++) {
        const cp = pending[i];
        try {
          this.adapter.createSession(cfg);
          await this.adapter.abort(
            this.adapter.requireActiveClient(),
            cfg,
            cp.objectKey,
            cp.uploadId,
            'account_switch'
          );
          this.adapter.closeActive();
          await this.checkpointStore.remove(cp.fileUuid, cp.accountId);
        } catch (_e) {
          cp.pendingAbort = true;
          cp.status = 'pending_abort';
          cp.abortReason = 'account_switch';
          await this.checkpointStore.save(cp);
          this.adapter.closeActive();
        }
      }
    }
    await this.checkpointStore.clearAccount(accountId);
  }

  private async loadOrCreateCheckpoint(
    input: MultipartUploadInput,
    cfg: OSSRuntimeConfig,
    partSize: number,
    totalParts: number
  ): Promise<MultipartUploadCheckpoint> {
    const client = this.adapter.requireActiveClient();
    const existing = await this.checkpointStore.load(input.fileUuid, input.accountId);
    if (existing) {
      const valid = MultipartUploadService.validateCheckpoint(existing, input, cfg);
      if (!valid) {
        if (existing.uploadId.length > 0) {
          try {
            await this.adapter.abort(client, cfg, existing.objectKey, existing.uploadId, 'checkpoint_invalid');
          } catch (_e) {
            existing.pendingAbort = true;
            existing.status = 'pending_abort';
            existing.abortReason = 'checkpoint_invalid';
            await this.checkpointStore.save(existing);
          }
        }
        await this.checkpointStore.remove(input.fileUuid, input.accountId);
        throw new FileTransferError(
          'multipartCheckpointInvalid',
          'uploading',
          FileTransferL10n.text('file.transfer.error.multipart_checkpoint'),
          false
        );
      }
      try {
        const listed = await this.adapter.listParts(client, cfg, input.objectKey, existing.uploadId);
        for (let i = 0; i < listed.length; i++) {
          const remote = listed[i];
          const part = MultipartUploadService.findOrCreatePart(
            existing, remote.partNumber, partSize, input.contentLength
          );
          if (remote.etag.length > 0) {
            part.etag = remote.etag;
            part.etagHash = OSSDiagnosticFingerprint.etagHash(remote.etag);
            part.status = 'succeeded';
            part.completedAt = Date.now();
          }
        }
        await this.checkpointStore.save(existing);
      } catch (_listErr) {
        // list 失败不阻断
      }
      return existing;
    }

    const uploadId = await this.adapter.initiate(client, cfg, input.objectKey);
    const cp = new MultipartUploadCheckpoint();
    cp.uploadId = uploadId;
    cp.uploadIdHash = OSSDiagnosticFingerprint.uploadIdHash(uploadId);
    cp.bucketFp = OSSDiagnosticFingerprint.bucketFingerprint(cfg.bucketName);
    cp.objectKey = input.objectKey;
    cp.objectKeyFp = ObjectKeyPolicy.fingerprint(input.objectKey);
    cp.fileUuid = input.fileUuid;
    cp.localPath = input.localPath;
    cp.fileSize = input.contentLength;
    cp.fileMd5 = input.contentMd5Hex;
    cp.mimeType = input.contentType;
    cp.partSize = partSize;
    cp.totalParts = totalParts;
    cp.accountId = input.accountId;
    cp.generation = input.generation;
    cp.createdAt = Date.now();
    cp.updatedAt = cp.createdAt;
    cp.status = 'uploading';
    cp.policyVersion = 'multipart-v1';
    for (let n = 1; n <= totalParts; n++) {
      MultipartUploadService.findOrCreatePart(cp, n, partSize, input.contentLength);
    }
    await this.checkpointStore.save(cp);
    return cp;
  }

  private async uploadPartWithRetry(
    cfg: OSSRuntimeConfig,
    input: MultipartUploadInput,
    checkpoint: MultipartUploadCheckpoint,
    part: MultipartPartRecord,
    cancelToken?: CancelToken
  ): Promise<void> {
    const client = this.adapter.requireActiveClient();
    let attempt = 0;
    let lastErr: Object | undefined = undefined;
    while (attempt < 2) {
      attempt += 1;
      part.attempt = attempt;
      part.status = 'uploading';
      await this.checkpointStore.save(checkpoint);
      try {
        const etag = await this.adapter.uploadPart(
          client,
          cfg,
          input.objectKey,
          checkpoint.uploadId,
          part.partNumber,
          input.localPath,
          part.offset,
          part.length,
          attempt,
          cancelToken
        );
        part.etag = etag;
        part.etagHash = OSSDiagnosticFingerprint.etagHash(etag);
        part.status = 'succeeded';
        part.completedAt = Date.now();
        part.lastErrorCode = '';
        await this.checkpointStore.save(checkpoint);
        return;
      } catch (err) {
        lastErr = err as Object;
        part.status = 'failed';
        if (err instanceof FileTransferError) {
          part.lastErrorCode = err.code;
          part.lastRequestId = err.ossRequestId ?? '';
          const rcp = OSSErrorDecoder.isRcpTransportReason(err.requestValidationReason ?? '');
          await this.checkpointStore.save(checkpoint);
          if (rcp && attempt < 2) {
            continue;
          }
          throw err;
        }
        await this.checkpointStore.save(checkpoint);
        if (err instanceof Error) {
          throw err;
        }
        throw new FileTransferError(
          'multipartPartUploadFailed',
          'uploading',
          FileTransferL10n.text('file.transfer.error.multipart_part'),
          true
        );
      }
    }
    if (lastErr instanceof FileTransferError) {
      throw lastErr;
    }
    throw new FileTransferError(
      'multipartPartUploadFailed',
      'uploading',
      FileTransferL10n.text('file.transfer.error.multipart_part'),
      true
    );
  }

  private async tryAbort(
    cfg: OSSRuntimeConfig,
    objectKey: string,
    uploadId: string,
    reason: string,
    checkpoint?: MultipartUploadCheckpoint
  ): Promise<void> {
    if (uploadId.length === 0 || objectKey.length === 0) {
      return;
    }
    try {
      let client = this.adapter.tryActiveClient();
      if (!client) {
        this.adapter.createSession(cfg);
        client = this.adapter.requireActiveClient();
      }
      await this.adapter.abort(client, cfg, objectKey, uploadId, reason);
      if (checkpoint) {
        await this.checkpointStore.remove(checkpoint.fileUuid, checkpoint.accountId);
      }
    } catch (_e) {
      if (checkpoint) {
        checkpoint.pendingAbort = true;
        checkpoint.status = 'pending_abort';
        checkpoint.abortReason = reason;
        await this.checkpointStore.save(checkpoint);
      }
    }
  }

  private static validateCheckpoint(
    cp: MultipartUploadCheckpoint,
    input: MultipartUploadInput,
    cfg: OSSRuntimeConfig
  ): boolean {
    if (cp.checkpointVersion !== 'v1') {
      return false;
    }
    if (cp.uploadId.length === 0) {
      return false;
    }
    if (cp.fileMd5 !== input.contentMd5Hex || cp.fileSize !== input.contentLength) {
      return false;
    }
    if (cp.objectKey !== input.objectKey) {
      return false;
    }
    if (cp.accountId !== input.accountId) {
      return false;
    }
    if (cp.bucketFp !== OSSDiagnosticFingerprint.bucketFingerprint(cfg.bucketName)) {
      return false;
    }
    if (cp.generation > 0 && input.generation > 0 && cp.generation !== input.generation) {
      return false;
    }
    return true;
  }

  private static findOrCreatePart(
    cp: MultipartUploadCheckpoint,
    partNumber: number,
    partSize: number,
    fileSize: number
  ): MultipartPartRecord {
    for (let i = 0; i < cp.parts.length; i++) {
      if (cp.parts[i].partNumber === partNumber) {
        return cp.parts[i];
      }
    }
    const part = new MultipartPartRecord();
    part.partNumber = partNumber;
    part.offset = FileUploadMode.partOffset(partNumber, partSize);
    part.length = FileUploadMode.partLength(fileSize, partNumber, partSize);
    part.status = 'pending';
    cp.parts.push(part);
    return part;
  }
}

import { FileAPI } from '../../Projects/Core/Networking/API/File/FileAPI';
import { OSSRuntimeConfigStore } from '../../Projects/Core/OSS/OSSRuntimeConfigStore';
import { OSSSimpleUploadAdapter, OSSSimpleUploadInput } from '../../Projects/Core/OSS/OSSSimpleUploadAdapter';
import { OSSMultipartUploadAdapter } from '../../Projects/Core/OSS/OSSMultipartUploadAdapter';
import { OSSDiagnosticFingerprint } from '../../Projects/Core/OSS/OSSDiagnosticFingerprint';
import { OSSErrorDecoder } from '../../Projects/Core/OSS/OSSErrorDecoder';
import { FileCacheManager } from './FileCacheManager';
import { FileStorageDecode } from './FileStorageDecode';
import { FileHashUtil } from './FileHashUtil';
import { FileUploadMode } from './FileUploadMode';
import {
  FileUploadCheckpointStore,
  InMemoryFileUploadCheckpointStore
} from './FileUploadCheckpointStore';
import { MultipartUploadService } from './MultipartUploadService';
import { MultipartUploadInput } from './MultipartUploadModels';
import { ObjectKeyPolicy } from './ObjectKeyPolicy';
import { FileTransferL10n } from './FileTransferL10n';
import {
  CancelToken,
  DownloadProgressEvent,
  FileCacheRecord,
  FileDownloadOptions,
  FileDownloadUrlPayload,
  FileTransferError,
  FileTransferPhase,
  FileTransferSnapshot,
  FileUploadRequest,
  LocalFileHandle,
  ManagedFileRecord,
  stsAgeBucketOf
} from './FileStorageModels';
import { SupportNetworkError } from '../../Projects/Core/Networking/SupportNetworkModels';
import { Logger } from '../../Foundation/Logging/Logger';
import { LogModule } from '../../Foundation/Logging/LogModule';
import { LogFields } from '../../Foundation/Logging/LogEvent';
import { ErrorLogger } from '../../Foundation/Logging/ErrorLogger';

export type FileTransferObserver = (snapshot: FileTransferSnapshot) => void;

/**
 * 上传 / 下载 / 列表 / 绑定 / 删除的唯一门面。
 * Feature 不得绕过本服务直接调用 OSS SDK 或 FileAPI.register。
 * HOS-FILE-OSS-0008/0009：仅 simple PutObject / multipart 两条生产链路。
 */
export class FileTransferService {
  private readonly fileApi: FileAPI;
  private readonly stsStore: OSSRuntimeConfigStore;
  private readonly simpleUpload: OSSSimpleUploadAdapter;
  private readonly multipartUpload: MultipartUploadService;
  private readonly cache: FileCacheManager;
  private readonly getAccountId: () => number | undefined;
  private readonly getGeneration: () => number;
  private recoverPromise?: Promise<void>;
  private pendingDeletePromise?: Promise<void>;

  constructor(
    fileApi: FileAPI,
    stsStore: OSSRuntimeConfigStore,
    simpleUpload: OSSSimpleUploadAdapter,
    multipartAdapter: OSSMultipartUploadAdapter,
    cache: FileCacheManager,
    getAccountId: () => number | undefined,
    getGeneration: () => number,
    checkpointStore?: FileUploadCheckpointStore
  ) {
    this.fileApi = fileApi;
    this.stsStore = stsStore;
    this.simpleUpload = simpleUpload;
    this.multipartUpload = new MultipartUploadService(
      checkpointStore ?? new InMemoryFileUploadCheckpointStore(),
      multipartAdapter
    );
    this.cache = cache;
    this.getAccountId = getAccountId;
    this.getGeneration = getGeneration;
  }

  async upload(
    request: FileUploadRequest,
    observer?: FileTransferObserver,
    cancelToken?: CancelToken
  ): Promise<ManagedFileRecord> {
    const token = cancelToken ?? new CancelToken();
    const accountId = this.requireAccount(request.accountId);
    this.assertGeneration(request.generation, 'preparing');
    const transferId = request.transferId.length > 0 ? request.transferId : FileHashUtil.randomUuid();
    const fileUuid = FileHashUtil.randomUuid();
    const accountHash = FileHashUtil.accountIdHash(accountId);
    const emit = (phase: FileTransferPhase, extra?: PartialSnapshot): void => {
      if (!observer) {
        return;
      }
      const snap = new FileTransferSnapshot();
      snap.transferId = transferId;
      snap.accountIdHash = accountHash;
      snap.fileUuid = fileUuid;
      snap.phase = phase;
      snap.updatedAt = Date.now();
      if (extra) {
        snap.bytesSent = extra.bytesSent;
        snap.totalBytes = extra.totalBytes;
        snap.progress = extra.progress;
        if (extra.hasRemoteFileId) {
          snap.remoteFileId = extra.remoteFileId;
        }
        snap.retryable = extra.retryable;
        snap.safeMessage = extra.safeMessage;
      }
      observer(snap);
    };

    emit('preparing', FileTransferService.phaseProgress(0, 0));
    let objectKey = '';
    try {
      const staged = await this.cache.stageUpload(
        accountId,
        request.sourceUri,
        request.originalName,
        fileUuid,
        token
      );
      const mime = request.mimeType.length > 0 && request.mimeType !== 'application/octet-stream'
        ? request.mimeType
        : staged.mimeType;
      await this.cache.attachUploadContext(
        accountId,
        fileUuid,
        mime,
        request.businessType,
        request.businessId,
        request.isPublic
      );

      emit('cached', FileTransferService.phaseProgress(0.2, staged.fileSize));
      const stagedLog = new LogFields();
      stagedLog.operation = 'file.stage_upload';
      stagedLog.detail =
        `fileBytes=${staged.fileSize};sizeBucket=${OSSDiagnosticFingerprint.sizeBucket(staged.fileSize)};` +
        `mime=${staged.mimeType};nameBytes=${ObjectKeyPolicy.utf8ByteLength(staged.originalName)}`;
      Logger.info('file.stage.ok', LogModule.FILE, stagedLog);
      // 图片内容异常小：在 PUT 前阻断，避免与 RCP/网络失败混淆。
      if (FileTransferService.isSuspiciouslySmallImage(staged.mimeType, staged.fileSize)) {
        throw new FileTransferError(
          'sourceInvalid',
          'preparing',
          FileTransferL10n.text('file.transfer.error.source_invalid'),
          false
        );
      }

      emit('acquiringCredentials', FileTransferService.phaseProgress(0.4, staged.fileSize));
      this.stsStore.setAccountScope(accountId);
      let config = await this.stsStore.getForUpload();
      this.assertGeneration(request.generation, 'acquiringCredentials');
      token.throwIfCancelled('acquiringCredentials');

      // object key 在 STS 之后生成，以便对齐服务端 object_key_prefix。
      objectKey = ObjectKeyPolicy.makeValidatedKey(
        fileUuid,
        staged.originalName,
        Date.now(),
        config.objectKeyPrefix
      );

      emit('uploading', FileTransferService.phaseProgress(0.7, staged.fileSize));
      const transferIdHash = FileHashUtil.sha256HexOfString(transferId).substring(0, 16);
      const modeSel = FileUploadMode.select(staged.fileSize);
      const modeLog = new LogFields();
      modeLog.operation = 'file.upload';
      modeLog.detail = FileUploadMode.toLogDetail(modeSel);
      Logger.info('file.upload.mode_selected', LogModule.FILE, modeLog);

      try {
        if (modeSel.mode === 'multipart') {
          const mpInput = new MultipartUploadInput();
          mpInput.localPath = staged.localPath;
          mpInput.objectKey = objectKey;
          mpInput.contentType = mime;
          mpInput.contentLength = staged.fileSize;
          mpInput.contentMd5Hex = staged.fileMd5;
          mpInput.fileUuid = fileUuid;
          mpInput.accountId = accountId;
          mpInput.generation = request.generation;
          mpInput.transferIdHash = transferIdHash;
          mpInput.partSize = modeSel.partSize;
          mpInput.totalParts = modeSel.totalParts;
          await this.multipartUpload.upload(
            mpInput,
            config,
            token,
            (_phase: FileTransferPhase, bytesSent: number, totalBytes: number) => {
              const ratio = totalBytes > 0 ? bytesSent / totalBytes : 0;
              emit('uploading', FileTransferService.phaseProgress(0.7 + ratio * 0.2, totalBytes));
            }
          );
        } else {
          const uploadInput = new OSSSimpleUploadInput();
          uploadInput.localPath = staged.localPath;
          uploadInput.objectKey = objectKey;
          uploadInput.contentType = mime;
          uploadInput.contentLength = staged.fileSize;
          uploadInput.config = config;
          uploadInput.transferIdHash = transferIdHash;
          uploadInput.sizeBucket = OSSDiagnosticFingerprint.sizeBucket(staged.fileSize);
          uploadInput.stsAgeBucket = stsAgeBucketOf(config.expirationEpochSeconds, false);
          try {
            await this.simpleUpload.upload(uploadInput, token);
          } catch (ossErr) {
            if (ossErr instanceof FileTransferError &&
              ossErr.code === 'credentialsExpired' &&
              ossErr.transportRetryable) {
              const retryLog = new LogFields();
              retryLog.operation = 'oss.put_object';
              retryLog.retryCount = 1;
              retryLog.detail =
                `reason=credentialsExpired;stsRefreshed=true;transferHash=${transferIdHash};` +
                `mode=simple;policy=${OSSSimpleUploadAdapter.POLICY_VERSION}`;
              if (ossErr.ossRequestId) {
                retryLog.ossRequestId = ossErr.ossRequestId;
              }
              Logger.warn('oss.put.retrying', LogModule.FILE, retryLog);
              this.stsStore.invalidate();
              config = await this.stsStore.getForUpload();
              uploadInput.config = config;
              uploadInput.stsAgeBucket = stsAgeBucketOf(config.expirationEpochSeconds, true);
              uploadInput.retryAttempt = 0;
              await this.simpleUpload.upload(uploadInput, token);
            } else if (FileTransferService.isZeroStatusBypassCandidate(ossErr, config.allowZeroStatusBypass)) {
              this.logZeroStatusBypass(ossErr, transferIdHash, 'simple', accountHash);
            } else if (ossErr instanceof FileTransferError) {
              throw ossErr;
            } else if (ossErr instanceof Error) {
              throw ossErr;
            } else {
              throw new FileTransferError('ossTransientFailure', 'uploading', '上传失败', true);
            }
          }
        }
      } catch (ossErr) {
        if (ossErr instanceof FileTransferError &&
          ossErr.code === 'credentialsExpired' &&
          ossErr.transportRetryable &&
          modeSel.mode === 'multipart') {
          this.stsStore.invalidate();
          config = await this.stsStore.getForUpload();
          const mpInput = new MultipartUploadInput();
          mpInput.localPath = staged.localPath;
          mpInput.objectKey = objectKey;
          mpInput.contentType = mime;
          mpInput.contentLength = staged.fileSize;
          mpInput.contentMd5Hex = staged.fileMd5;
          mpInput.fileUuid = fileUuid;
          mpInput.accountId = accountId;
          mpInput.generation = request.generation;
          mpInput.transferIdHash = transferIdHash;
          mpInput.partSize = modeSel.partSize;
          mpInput.totalParts = modeSel.totalParts;
          await this.multipartUpload.upload(mpInput, config, token);
        } else if (FileTransferService.isZeroStatusBypassCandidate(ossErr, config.allowZeroStatusBypass)) {
          this.logZeroStatusBypass(ossErr, transferIdHash, modeSel.mode, accountHash);
        } else if (ossErr instanceof FileTransferError) {
          throw ossErr;
        } else if (ossErr instanceof Error) {
          throw ossErr;
        } else {
          throw new FileTransferError('ossTransientFailure', 'uploading', '上传失败', true);
        }
      }

      this.assertGeneration(request.generation, 'registering');
      token.throwIfCancelled('registering');
      emit('registering', FileTransferService.phaseProgress(0.9, staged.fileSize));

      const body = FileStorageDecode.toRegisterBody(
        fileUuid,
        staged.originalName,
        staged.fileSize,
        mime,
        objectKey,
        request.businessType,
        request.businessId,
        request.isPublic,
        staged.fileMd5
      );
      let record: ManagedFileRecord;
      try {
        record = await this.fileApi.register(body);
      } catch (regErr) {
        await this.cache.markUploadedUnregistered(accountId, fileUuid, objectKey);
        const pending = FileTransferService.phaseProgress(0.95, staged.fileSize);
        pending.retryable = true;
        pending.safeMessage = '已上传，等待保存';
        emit('uploadedUnregistered', pending);
        throw this.mapRegisterError(regErr as Object);
      }

      if (!FileStorageDecode.assertRegisterMatches(record, fileUuid, objectKey)) {
        await this.cache.markUploadedUnregistered(accountId, fileUuid, objectKey);
        throw new FileTransferError(
          'serverContractViolation',
          'registering',
          '登记结果不一致',
          true
        );
      }

      await this.cache.bindRemoteIdentity(accountId, fileUuid, record, objectKey);
      const done = FileTransferService.phaseProgress(1, staged.fileSize);
      done.hasRemoteFileId = true;
      done.remoteFileId = record.id;
      emit('completed', done);
      const uploadOk = new LogFields();
      uploadOk.detail = `上传完成 id=${record.id}`;
      Logger.info('file.upload.ok', LogModule.FILE, uploadOk);
      return record;
    } catch (err) {
      if (token.cancelled) {
        this.simpleUpload.cancelActive();
        this.multipartUpload.cancelActive();
        const cancelled = new PartialSnapshot();
        cancelled.retryable = true;
        cancelled.safeMessage = '已取消';
        emit('cancelled', cancelled);
        throw new FileTransferError('cancelled', 'cancelled', '已取消', true);
      }
      const mapped = this.normalizeError(err as Object, 'uploading');
      const failed = new PartialSnapshot();
      failed.retryable = mapped.userCanRetry;
      failed.safeMessage = mapped.safeMessage;
      emit('failed', failed);
      const failFields = new LogFields();
      failFields.operation = mapped.operation ?? 'file.upload';
      failFields.code = mapped.code;
      failFields.accountHash = accountHash;
      // D-03：仅把 SparkService ID 写入 requestId；OSS ID 写入 ossRequestId。
      if (mapped.requestId) {
        failFields.requestId = mapped.requestId;
      }
      if (mapped.ossRequestId) {
        failFields.ossRequestId = mapped.ossRequestId;
      }
      ErrorLogger.log('file.upload.failed', LogModule.FILE, mapped, undefined, failFields);
      throw mapped;
    }
  }

  /**
   * OSS 已成功但登记失败时：仅重试 register，不再 putObject。
   */
  async retryRegister(
    accountId: number,
    generation: number,
    fileUuid: string,
    originalName: string,
    fileSize: number,
    mimeType: string,
    objectKey: string,
    fileMd5: string,
    businessType: string,
    businessId: string,
    isPublic: boolean,
    observer?: FileTransferObserver
  ): Promise<ManagedFileRecord> {
    this.requireAccount(accountId);
    this.assertGeneration(generation, 'registering');
    const body = FileStorageDecode.toRegisterBody(
      fileUuid,
      originalName,
      fileSize,
      mimeType,
      objectKey,
      businessType,
      businessId,
      isPublic,
      fileMd5
    );
    if (observer) {
      const snap = new FileTransferSnapshot();
      snap.transferId = fileUuid;
      snap.accountIdHash = FileHashUtil.accountIdHash(accountId);
      snap.fileUuid = fileUuid;
      snap.phase = 'registering';
      snap.progress = 0.9;
      snap.updatedAt = Date.now();
      observer(snap);
    }
    const record = await this.fileApi.register(body);
    if (!FileStorageDecode.assertRegisterMatches(record, fileUuid, objectKey)) {
      throw new FileTransferError('serverContractViolation', 'registering', '登记结果不一致', true);
    }
    await this.cache.bindRemoteIdentity(accountId, fileUuid, record, objectKey);
    return record;
  }

  async download(
    record: ManagedFileRecord,
    options?: FileDownloadOptions,
    cancelToken?: CancelToken,
    observer?: FileTransferObserver
  ): Promise<LocalFileHandle> {
    const accountId = this.requireAccount(undefined);
    const token = cancelToken ?? new CancelToken();
    const opts = options ?? new FileDownloadOptions();
    this.assertGeneration(opts.generation, 'downloading');
    const expectedMd5 = opts.expectedMd5.length > 0 ? opts.expectedMd5 : record.fileMd5;
    const transferId = record.fileUuid.length > 0 ? record.fileUuid : `${record.id}`;
    const accountHash = FileHashUtil.accountIdHash(accountId);
    const emit = (phase: FileTransferPhase, extra?: PartialSnapshot): void => {
      if (!observer) {
        return;
      }
      const snap = new FileTransferSnapshot();
      snap.transferId = transferId;
      snap.accountIdHash = accountHash;
      snap.fileUuid = record.fileUuid;
      snap.phase = phase;
      snap.updatedAt = Date.now();
      if (extra) {
        snap.bytesSent = extra.bytesSent;
        snap.totalBytes = extra.totalBytes;
        snap.progress = extra.progress;
        if (extra.hasRemoteFileId) {
          snap.remoteFileId = extra.remoteFileId;
        }
        snap.retryable = extra.retryable;
        snap.safeMessage = extra.safeMessage;
      }
      observer(snap);
    };

    if (!opts.forceRefresh) {
      const cached = await this.cache.lookupReady(accountId, record.fileUuid, expectedMd5);
      if (cached) {
        this.assertGeneration(opts.generation, 'completed');
        const hit = FileTransferService.phaseProgress(1, cached.fileSize);
        hit.hasRemoteFileId = true;
        hit.remoteFileId = cached.remoteFileId;
        emit('completed', hit);
        const cacheHitLog = new LogFields();
        cacheHitLog.detail = `下载命中缓存 id=${record.id}`;
        Logger.info('file.download.cache_hit', LogModule.FILE, cacheHitLog);
        return cached;
      }
    }

    emit('downloading', FileTransferService.phaseProgress(0, record.fileSize));
    let urlPayload: FileDownloadUrlPayload;
    try {
      urlPayload = await this.fileApi.downloadUrl(record.id);
    } catch (err) {
      throw this.mapDownloadUrlError(err as Object);
    }
    if (!urlPayload.url || urlPayload.url.length === 0) {
      throw new FileTransferError('fileUnavailable', 'downloading', '下载地址无效', false);
    }

    const onProgress = (event: DownloadProgressEvent): void => {
      this.assertGeneration(opts.generation, 'downloading');
      if (!observer) {
        return;
      }
      const mid = new PartialSnapshot();
      mid.bytesSent = event.bytesReceived;
      mid.totalBytes = event.totalBytes > 0 ? event.totalBytes : record.fileSize;
      if (mid.totalBytes > 0) {
        mid.progress = Math.min(0.99, event.bytesReceived / mid.totalBytes);
      }
      emit('downloading', mid);
    };

    try {
      const handle = await this.cache.commitDownload(accountId, record, urlPayload.url, token, onProgress);
      this.assertGeneration(opts.generation, 'completed');
      const done = FileTransferService.phaseProgress(1, handle.fileSize);
      done.hasRemoteFileId = true;
      done.remoteFileId = handle.remoteFileId;
      emit('completed', done);
      return handle;
    } catch (err) {
      if (err instanceof FileTransferError && err.code === 'integrityMismatch') {
        const again = await this.fileApi.downloadUrl(record.id);
        const handle = await this.cache.commitDownload(accountId, record, again.url, token, onProgress);
        this.assertGeneration(opts.generation, 'completed');
        const done = FileTransferService.phaseProgress(1, handle.fileSize);
        done.hasRemoteFileId = true;
        done.remoteFileId = handle.remoteFileId;
        emit('completed', done);
        return handle;
      }
      const mapped = this.normalizeError(err as Object, 'downloading');
      const failed = new PartialSnapshot();
      failed.retryable = mapped.retryable;
      failed.safeMessage = mapped.safeMessage;
      emit('failed', failed);
      throw mapped;
    }
  }

  /** 对齐 iOS cachedURL：仅返回 ready 本地句柄。 */
  async cachedURL(record: ManagedFileRecord, expectedMd5: string = ''): Promise<LocalFileHandle | undefined> {
    const accountId = this.requireAccount(undefined);
    const md5 = expectedMd5.length > 0 ? expectedMd5 : record.fileMd5;
    return this.cache.lookupReady(accountId, record.fileUuid, md5);
  }

  /**
   * 用当前 STS bucket/endpoint 拼 virtual-hosted HTTPS（聊天展示用）。
   * 下载热路径仍必须走 download-url，不得用本 URL 直链拉对象。
   */
  publicHTTPSURLForObjectKey(objectKey: string): string | undefined {
    if (objectKey.length === 0) {
      return undefined;
    }
    const cfg = this.stsStore.peek();
    if (!cfg || !cfg.isComplete()) {
      return undefined;
    }
    let host = cfg.endpoint.trim();
    if (host.startsWith('https://')) {
      host = host.substring('https://'.length);
    } else if (host.startsWith('http://')) {
      host = host.substring('http://'.length);
    }
    while (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    if (host.startsWith(`${cfg.bucketName}.`)) {
      return `https://${host}/${FileTransferService.encodeObjectKey(objectKey)}`;
    }
    return `https://${cfg.bucketName}.${host}/${FileTransferService.encodeObjectKey(objectKey)}`;
  }

  async list(
    businessType?: string,
    businessId?: string,
    isPublic?: boolean
  ): Promise<ManagedFileRecord[]> {
    const accountId = this.getAccountId();
    const scope = accountId !== undefined ? `${accountId}` : 'anon';
    return this.fileApi.list(businessType, businessId, isPublic, scope);
  }

  async updateBusinessBinding(
    fileId: number,
    businessType: string,
    businessId: string,
    generation: number = 0
  ): Promise<ManagedFileRecord> {
    this.assertGeneration(generation, 'registering');
    return this.fileApi.updateBusinessBinding(fileId, businessType, businessId);
  }

  async delete(fileId: number, fileUuid?: string, generation: number = 0): Promise<void> {
    this.assertGeneration(generation, 'preparing');
    const accountId = this.getAccountId();
    try {
      await this.fileApi.remove(fileId);
    } catch (err) {
      if (accountId !== undefined) {
        await this.markPendingDelete(accountId, fileId, fileUuid);
      }
      throw this.normalizeError(err as Object, 'preparing');
    }
    if (accountId === undefined) {
      return;
    }
    if (fileUuid && fileUuid.length > 0) {
      await this.cache.remove(accountId, fileUuid);
      return;
    }
    const local = await this.cache.findByFileId(accountId, fileId);
    if (local) {
      await this.cache.remove(accountId, local.fileUuid);
    }
  }

  async retryPendingDeletes(accountId: number, generation: number = 0): Promise<void> {
    this.requireAccount(accountId);
    this.assertGeneration(generation, 'preparing');
    if (this.pendingDeletePromise) {
      return this.pendingDeletePromise;
    }
    this.pendingDeletePromise = this.retryPendingDeletesInternal(accountId, generation)
      .finally(() => {
        this.pendingDeletePromise = undefined;
      });
    return this.pendingDeletePromise;
  }

  /**
   * 登录/bootstrap 后：清理不完整 .part，并异步恢复 uploaded_unregistered。
   * 失败只打日志，不阻塞主 Tab。
   */
  async recoverAfterSignedIn(accountId: number, generation: number = 0): Promise<void> {
    if (this.recoverPromise) {
      return this.recoverPromise;
    }
    this.recoverPromise = this.recoverAfterSignedInInternal(accountId, generation)
      .finally(() => {
        this.recoverPromise = undefined;
      });
    return this.recoverPromise;
  }

  /** 回到前台：清理 .part + 恢复未登记；不重复冷启动。 */
  async onForegroundResume(): Promise<void> {
    const accountId = this.getAccountId();
    if (accountId === undefined || accountId <= 0) {
      return;
    }
    const generation = this.getGeneration();
    try {
      this.cache.removeIncompleteParts(accountId);
    } catch (err) {
      ErrorLogger.log('file.cache.part_cleanup_failed', LogModule.FILE, err as Object);
    }
    try {
      await this.recoverPendingRegistrations(accountId, generation);
    } catch (err) {
      ErrorLogger.log('file.register.recover_failed', LogModule.FILE, err as Object);
    }
    try {
      await this.retryPendingDeletes(accountId, generation);
    } catch (err) {
      ErrorLogger.log('file.delete.retry_failed', LogModule.FILE, err as Object);
    }
  }

  async clearAccount(accountId: number): Promise<void> {
    this.stsStore.invalidate();
    this.simpleUpload.cancelActive();
    this.multipartUpload.cancelActive();
    await this.cache.clearAccount(accountId);
  }

  resetRuntimeCredentials(): void {
    this.stsStore.invalidate();
    this.simpleUpload.cancelActive();
    this.multipartUpload.cancelActive();
  }

  private async recoverAfterSignedInInternal(accountId: number, generation: number): Promise<void> {
    try {
      this.cache.removeIncompleteParts(accountId);
    } catch (err) {
      ErrorLogger.log('file.cache.part_cleanup_failed', LogModule.FILE, err as Object);
    }
    try {
      await this.recoverPendingRegistrations(accountId, generation > 0 ? generation : this.getGeneration());
    } catch (err) {
      ErrorLogger.log('file.register.recover_failed', LogModule.FILE, err as Object);
    }
    try {
      await this.retryPendingDeletes(accountId, generation > 0 ? generation : this.getGeneration());
    } catch (err) {
      ErrorLogger.log('file.delete.retry_failed', LogModule.FILE, err as Object);
    }
  }

  private async recoverPendingRegistrations(accountId: number, generation: number): Promise<void> {
    this.assertGeneration(generation, 'registering');
    const pending = await this.cache.listByState(accountId, 'uploaded_unregistered');
    for (let i = 0; i < pending.length; i++) {
      const rec = pending[i];
      if (rec.objectKey.length === 0 || !this.cache.localFileExists(rec.localPath)) {
        continue;
      }
      try {
        await this.retryRegister(
          accountId,
          generation,
          rec.fileUuid,
          rec.originalName,
          rec.fileSize,
          rec.mimeType,
          rec.objectKey,
          rec.fileMd5,
          rec.businessType,
          rec.businessId,
          rec.isPublic
        );
        const fields = new LogFields();
        fields.detail = `登记恢复成功 uuid=${rec.fileUuid}`;
        Logger.info('file.register.recover_ok', LogModule.FILE, fields);
      } catch (err) {
        ErrorLogger.log('file.register.recover_item_failed', LogModule.FILE, err as Object);
      }
    }
  }

  private async retryPendingDeletesInternal(accountId: number, generation: number): Promise<void> {
    this.assertGeneration(generation, 'preparing');
    const pending = await this.cache.listByState(accountId, 'pending_delete');
    for (let i = 0; i < pending.length; i++) {
      const rec = pending[i];
      if (rec.fileId <= 0) {
        continue;
      }
      try {
        await this.fileApi.remove(rec.fileId);
        await this.cache.remove(accountId, rec.fileUuid);
      } catch (err) {
        ErrorLogger.log('file.delete.retry_item_failed', LogModule.FILE, err as Object);
      }
    }
  }

  private async markPendingDelete(
    accountId: number,
    fileId: number,
    fileUuid?: string
  ): Promise<void> {
    let rec: FileCacheRecord | undefined = undefined;
    if (fileUuid && fileUuid.length > 0) {
      rec = await this.cache.findCacheRecord(accountId, fileUuid);
    }
    if (!rec) {
      rec = await this.cache.findByFileId(accountId, fileId);
    }
    if (!rec) {
      return;
    }
    await this.cache.markState(accountId, rec.fileUuid, 'pending_delete');
  }

  private requireAccount(requestAccountId: number | undefined): number {
    const active = this.getAccountId();
    if (active === undefined || active <= 0) {
      throw new FileTransferError('unauthorized', 'preparing', '未登录', false);
    }
    if (requestAccountId !== undefined && requestAccountId > 0 && requestAccountId !== active) {
      throw new FileTransferError('generationMismatch', 'preparing', '账号已切换', false);
    }
    return active;
  }

  private assertGeneration(expected: number, stage: FileTransferPhase): void {
    if (expected > 0 && expected !== this.getGeneration()) {
      throw new FileTransferError('generationMismatch', stage, '会话已变更', false);
    }
  }

  private static phaseProgress(progress: number, totalBytes: number): PartialSnapshot {
    const p = new PartialSnapshot();
    p.progress = progress;
    p.totalBytes = totalBytes;
    return p;
  }

  /**
   * 零时代码放行：只针对 RCP 传输失败、未收到 HTTP 响应的场景。
   * 其余 4xx/5xx 或明确 OSS 错误仍然按失败处理。
   */
  static isZeroStatusBypassCandidate(error: Object, allowZeroStatusBypass: boolean = true): boolean {
    if (!allowZeroStatusBypass) {
      return false;
    }
    if (!(error instanceof FileTransferError)) {
      return false;
    }
    if (error.code !== 'ossTransientFailure') {
      return false;
    }
    if (error.httpStatus !== undefined && error.httpStatus !== 0) {
      return false;
    }
    if (error.transportRetryable !== true) {
      return false;
    }
    return OSSErrorDecoder.isRcpTransportReason(error.requestValidationReason ?? '');
  }

  private logZeroStatusBypass(
    error: FileTransferError,
    transferIdHash: string,
    mode: string,
    accountHash: string
  ): void {
    const fields = new LogFields();
    fields.operation = 'file.upload';
    fields.code = error.code;
    fields.accountHash = accountHash;
    fields.ossRequestId = error.ossRequestId;
    fields.detail =
      `decision=continue_as_success;mode=${mode};` +
      `reason=${error.requestValidationReason ?? 'unknown'};` +
      `httpStatus=${error.httpStatus ?? 0};retryable=${error.transportRetryable};` +
      `transferHash=${transferIdHash};` +
      `policy=${mode === 'multipart' ? 'multipart-v1' : OSSSimpleUploadAdapter.POLICY_VERSION}`;
    Logger.warn('file.upload.zero_status_bypassed', LogModule.FILE, fields);
  }

  private static encodeObjectKey(objectKey: string): string {
    const parts = objectKey.split('/');
    const encoded: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      encoded.push(encodeURIComponent(parts[i]));
    }
    return encoded.join('/');
  }

  private mapRegisterError(err: Object): FileTransferError {
    if (err instanceof FileTransferError) {
      return err;
    }
    if (err instanceof SupportNetworkError) {
      if (err.statusCode === 401 || err.kind === 'unauthenticated' || err.kind === 'refreshFailed') {
        return new FileTransferError('unauthorized', 'registering', '未授权', false, err.requestId, err.statusCode);
      }
      if (err.kind === 'transport') {
        return new FileTransferError(
          'registrationPending',
          'registering',
          '已上传，等待保存',
          true,
          err.requestId
        );
      }
      return new FileTransferError(
        'registrationPending',
        'registering',
        '已上传，等待保存',
        true,
        err.requestId,
        err.statusCode
      );
    }
    return new FileTransferError('registrationPending', 'registering', '已上传，等待保存', true);
  }

  private mapDownloadUrlError(err: Object): FileTransferError {
    if (err instanceof SupportNetworkError) {
      if (err.statusCode === 401) {
        return new FileTransferError('unauthorized', 'downloading', '未授权', false, err.requestId, 401);
      }
      if (err.statusCode === 403 || err.statusCode === 404 ||
        (err.backend && (err.backend.code === 4030 || err.backend.code === 4040))) {
        return new FileTransferError('fileUnavailable', 'downloading', '文件不可用', false, err.requestId, err.statusCode);
      }
      if (err.kind === 'transport') {
        return new FileTransferError('networkUnavailable', 'downloading', '网络不可用', true, err.requestId);
      }
    }
    return new FileTransferError('networkUnavailable', 'downloading', '获取下载地址失败', true);
  }

  private normalizeError(err: Object, fallbackStage: FileTransferPhase): FileTransferError {
    if (err instanceof FileTransferError) {
      return err;
    }
    if (err instanceof SupportNetworkError) {
      if (err.statusCode === 401 || err.kind === 'unauthenticated' || err.kind === 'refreshFailed') {
        return new FileTransferError('unauthorized', fallbackStage, '未授权', false, err.requestId, err.statusCode);
      }
      // STS / 业务配置错误不得伪装成网络临时失败。
      if (err.backend && (err.backend.code === 5001 || err.backend.code === 5002)) {
        return new FileTransferError(
          'ossConfigurationInvalid',
          fallbackStage === 'uploading' ? 'acquiringCredentials' : fallbackStage,
          FileTransferL10n.text('file.transfer.error.configuration'),
          false,
          err.requestId,
          err.statusCode
        );
      }
      if (err.kind === 'transport' || err.kind === 'cancelled') {
        return new FileTransferError(
          err.kind === 'cancelled' ? 'cancelled' : 'networkUnavailable',
          fallbackStage,
          err.kind === 'cancelled' ? '已取消' : '网络不可用',
          true,
          err.requestId
        );
      }
    }
    return new FileTransferError('localIoFailed', fallbackStage, '操作失败', true);
  }

  /**
   * 医疗相册图若缓存后 < 1KB，视为内容异常（非网络问题）。
   * 本次日志 sizeBucket=lt1m 不属于此范围。
   */
  private static isSuspiciouslySmallImage(mimeType: string, fileSize: number): boolean {
    if (fileSize <= 0 || fileSize >= 1024) {
      return false;
    }
    const mime = mimeType.toLowerCase();
    return mime.indexOf('image/') === 0 ||
      mime === 'application/octet-stream'; // 无名扩展时保守拦截极小文件
  }
}

class PartialSnapshot {
  bytesSent: number = 0;
  totalBytes: number = 0;
  progress: number = 0;
  remoteFileId: number = 0;
  hasRemoteFileId: boolean = false;
  retryable: boolean = false;
  safeMessage: string = '';
}

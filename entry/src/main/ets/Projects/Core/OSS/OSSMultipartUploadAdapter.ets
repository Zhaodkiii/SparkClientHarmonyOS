import Client, { FilePath } from '@aliyun/oss';
import { OSSRuntimeConfig } from './OSSRuntimeConfig';
import { OSSClientConfigNormalizer, OSSClientInitParams } from './OSSClientConfigNormalizer';
import { OSSErrorDecodeContext, OSSErrorDecoder } from './OSSErrorDecoder';
import { OSSDiagnosticFingerprint } from './OSSDiagnosticFingerprint';
import { OSSVendorSdkMeta } from './OSSVendorSdkMeta';
import {
  CancelToken,
  FileTransferError,
  FileTransferErrorDiagnostics
} from '../../../Core/FileStorage/FileStorageModels';
import { FileTransferL10n } from '../../../Core/FileStorage/FileTransferL10n';
import { ObjectKeyPolicy } from '../../../Core/FileStorage/ObjectKeyPolicy';
import { Logger } from '../../../Foundation/Logging/Logger';
import { LogModule } from '../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../Foundation/Logging/LogEvent';
import { ErrorLogger } from '../../../Foundation/Logging/ErrorLogger';
import { LogLevel } from '../../../Foundation/Logging/LogLevel';

/**
 * 官方 Multipart Upload 适配器（HOS-FILE-OSS-0008）。
 * initiate / uploadPart / listParts / complete / abort。
 * 不做业务登记；不做 appendObject。
 */
export class OSSMultipartUploadAdapter {
  private activeClient?: Client;
  private sessionClosed: boolean = true;

  createSession(cfg: OSSRuntimeConfig): Client {
    if (!cfg.isComplete() || cfg.securityToken.trim().length === 0) {
      throw new FileTransferError(
        'ossConfigurationInvalid',
        'acquiringCredentials',
        FileTransferL10n.text('file.transfer.error.configuration'),
        false
      );
    }
    const init = OSSClientConfigNormalizer.normalize(cfg.region, cfg.endpoint, cfg.bucketRegion);
    if (init.configurationIssue.length > 0 || !init.regionEndpointConsistent) {
      throw new FileTransferError(
        'ossConfigurationInvalid',
        'uploading',
        FileTransferL10n.text('file.transfer.error.configuration'),
        false
      );
    }
    this.closeActive();
    const client = OSSMultipartUploadAdapter.createClient(cfg, init);
    this.activeClient = client;
    this.sessionClosed = false;
    return client;
  }

  async initiate(
    client: Client,
    cfg: OSSRuntimeConfig,
    objectKey: string
  ): Promise<string> {
    ObjectKeyPolicy.assertKeyValid(objectKey);
    const started = Date.now();
    try {
      const res = await client.initiateMultipartUpload({
        bucket: cfg.bucketName,
        key: objectKey
      });
      const uploadId = OSSMultipartUploadAdapter.readUploadId(res as Object);
      if (uploadId.length === 0) {
        throw new FileTransferError(
          'multipartInitiateFailed',
          'uploading',
          FileTransferL10n.text('file.transfer.error.multipart_initiate'),
          true
        );
      }
      const ok = new LogFields();
      ok.operation = 'oss.multipart.initiate';
      ok.elapsedMs = Date.now() - started;
      ok.detail =
        `uploadIdHash=${OSSDiagnosticFingerprint.uploadIdHash(uploadId)};` +
        `keyFp=${ObjectKeyPolicy.fingerprint(objectKey)};` +
        `bucketFp=${OSSDiagnosticFingerprint.bucketFingerprint(cfg.bucketName)};` +
        `${OSSVendorSdkMeta.toLogDetail()}`;
      Logger.info('oss.multipart.initiated', LogModule.OSS, ok);
      return uploadId;
    } catch (err) {
      throw this.mapError(err as Object, 'multipartInitiateFailed', objectKey);
    }
  }

  /**
   * 官方推荐：FilePath + offset + length，不整文件读入内存。
   */
  async uploadPart(
    client: Client,
    cfg: OSSRuntimeConfig,
    objectKey: string,
    uploadId: string,
    partNumber: number,
    localPath: string,
    offset: number,
    length: number,
    attempt: number,
    cancelToken?: CancelToken
  ): Promise<string> {
    cancelToken?.throwIfCancelled('uploading');
    const uploadIdHash = OSSDiagnosticFingerprint.uploadIdHash(uploadId);
    const started = Date.now();
    const startLog = new LogFields();
    startLog.operation = 'oss.multipart.upload_part';
    startLog.detail =
      `uploadIdHash=${uploadIdHash};partNumber=${partNumber};` +
      `partSizeBucket=${OSSMultipartUploadAdapter.sizeBucket(length)};attempt=${attempt}`;
    Logger.info('oss.multipart.part.started', LogModule.OSS, startLog);
    try {
      const res = await client.uploadPart({
        bucket: cfg.bucketName,
        key: objectKey,
        uploadId: uploadId,
        partNumber: partNumber,
        data: new FilePath(localPath),
        length: length,
        offset: offset
      });
      const etag = OSSMultipartUploadAdapter.readEtag(res as Object);
      if (etag.length === 0) {
        throw new FileTransferError(
          'multipartPartIntegrityMismatch',
          'uploading',
          FileTransferL10n.text('file.transfer.error.multipart_part'),
          true
        );
      }
      const ok = new LogFields();
      ok.operation = 'oss.multipart.upload_part';
      ok.elapsedMs = Date.now() - started;
      ok.detail =
        `uploadIdHash=${uploadIdHash};partNumber=${partNumber};elapsedMs=${Date.now() - started};` +
        `etagPresent=true;etagHash=${OSSDiagnosticFingerprint.etagHash(etag)}`;
      Logger.info('oss.multipart.part.succeeded', LogModule.OSS, ok);
      return etag;
    } catch (err) {
      if (err instanceof FileTransferError) {
        throw err;
      }
      throw this.mapError(err as Object, 'multipartPartUploadFailed', objectKey, uploadIdHash, partNumber);
    }
  }

  async listParts(
    client: Client,
    cfg: OSSRuntimeConfig,
    objectKey: string,
    uploadId: string
  ): Promise<MultipartListedPart[]> {
    try {
      const res = await client.listParts({
        bucket: cfg.bucketName,
        key: objectKey,
        uploadId: uploadId
      });
      return OSSMultipartUploadAdapter.readListedParts(res as Object);
    } catch (err) {
      throw this.mapError(
        err as Object,
        'multipartListPartsFailed',
        objectKey,
        OSSDiagnosticFingerprint.uploadIdHash(uploadId)
      );
    }
  }

  async complete(
    client: Client,
    cfg: OSSRuntimeConfig,
    objectKey: string,
    uploadId: string,
    totalParts: number
  ): Promise<void> {
    const uploadIdHash = OSSDiagnosticFingerprint.uploadIdHash(uploadId);
    const started = Date.now();
    try {
      // 官方 completeAll：由服务端列举已上传 Part 并排序完成。
      await client.completeMultipartUpload({
        bucket: cfg.bucketName,
        key: objectKey,
        uploadId: uploadId,
        completeAll: true
      });
      const ok = new LogFields();
      ok.operation = 'oss.multipart.complete';
      ok.elapsedMs = Date.now() - started;
      ok.detail =
        `uploadIdHash=${uploadIdHash};totalParts=${totalParts};` +
        `keyFp=${ObjectKeyPolicy.fingerprint(objectKey)};` +
        `objectSizeBucket=n`;
      Logger.info('oss.multipart.completed', LogModule.OSS, ok);
    } catch (err) {
      throw this.mapError(err as Object, 'multipartCompleteFailed', objectKey, uploadIdHash);
    }
  }

  async abort(
    client: Client,
    cfg: OSSRuntimeConfig,
    objectKey: string,
    uploadId: string,
    reason: string
  ): Promise<void> {
    const uploadIdHash = OSSDiagnosticFingerprint.uploadIdHash(uploadId);
    try {
      await client.abortMultipartUpload({
        bucket: cfg.bucketName,
        key: objectKey,
        uploadId: uploadId
      });
      const ok = new LogFields();
      ok.operation = 'oss.multipart.abort';
      ok.detail = `uploadIdHash=${uploadIdHash};reason=${reason}`;
      Logger.info('oss.multipart.aborted', LogModule.OSS, ok);
    } catch (err) {
      throw this.mapError(err as Object, 'multipartAbortFailed', objectKey, uploadIdHash);
    }
  }

  closeActive(): void {
    if (this.activeClient) {
      this.closeClientOnce(this.activeClient);
    }
  }

  cancelActive(): void {
    this.closeActive();
  }

  requireActiveClient(): Client {
    if (!this.activeClient) {
      throw new FileTransferError(
        'ossTransientFailure',
        'uploading',
        FileTransferL10n.text('file.transfer.error.transient'),
        true
      );
    }
    return this.activeClient;
  }

  tryActiveClient(): Client | undefined {
    return this.activeClient;
  }

  private mapError(
    err: Object,
    fallbackCode:
      | 'multipartInitiateFailed'
      | 'multipartPartUploadFailed'
      | 'multipartPartIntegrityMismatch'
      | 'multipartListPartsFailed'
      | 'multipartCompleteFailed'
      | 'multipartAbortFailed',
    objectKey: string,
    uploadIdHash: string = '',
    partNumber: number = 0
  ): FileTransferError {
    if (err instanceof FileTransferError) {
      return err;
    }
    const ctx = new OSSErrorDecodeContext();
    ctx.objectKeyFingerprint = ObjectKeyPolicy.fingerprint(objectKey);
    ctx.transportPolicyVersion = 'multipart-v1';
    const mapped = OSSErrorDecoder.decode(err, undefined, ctx);
    if (!OSSErrorDecoder.isRcpTransportReason(mapped.requestValidationReason ?? '')) {
      const typed = new FileTransferError(
        fallbackCode,
        'uploading',
        OSSMultipartUploadAdapter.messageForCode(fallbackCode),
        mapped.userCanRetry
      );
      const diag = new FileTransferErrorDiagnostics();
      diag.operation = 'oss.multipart';
      diag.objectKeyFingerprint = ctx.objectKeyFingerprint;
      diag.transportPolicyVersion = 'multipart-v1';
      diag.transportRetryable = mapped.transportRetryable;
      diag.userCanRetry = mapped.userCanRetry;
      if (mapped.ossCode) {
        diag.ossCode = mapped.ossCode;
      }
      if (mapped.ossEc) {
        diag.ossEc = mapped.ossEc;
      }
      if (mapped.ossRequestId) {
        diag.ossRequestId = mapped.ossRequestId;
      }
      if (mapped.httpStatus !== undefined) {
        diag.httpStatus = mapped.httpStatus;
      }
      if (mapped.requestValidationReason) {
        diag.requestValidationReason = mapped.requestValidationReason;
      }
      const fail = new LogFields();
      fail.operation = 'oss.multipart';
      fail.code = fallbackCode;
      fail.detail =
        `uploadIdHash=${uploadIdHash.length > 0 ? uploadIdHash : 'n'};` +
        `partNumber=${partNumber > 0 ? partNumber : 'n'};` +
        `fallback=${fallbackCode};mapped=${mapped.code}`;
      ErrorLogger.log('oss.multipart.failed', LogModule.OSS, typed.withDiagnostics(diag), LogLevel.ERROR, fail);
      return typed.withDiagnostics(diag);
    }
    const fail = new LogFields();
    fail.operation = 'oss.multipart';
    fail.code = mapped.code;
    fail.detail =
      `uploadIdHash=${uploadIdHash.length > 0 ? uploadIdHash : 'n'};` +
      `partNumber=${partNumber > 0 ? partNumber : 'n'};` +
      `reason=${mapped.requestValidationReason ?? ''};errorLayer=rcp`;
    ErrorLogger.log('oss.multipart.failed', LogModule.OSS, mapped, LogLevel.ERROR, fail);
    return mapped;
  }

  private static messageForCode(code: string): string {
    switch (code) {
      case 'multipartInitiateFailed':
        return FileTransferL10n.text('file.transfer.error.multipart_initiate');
      case 'multipartCompleteFailed':
        return FileTransferL10n.text('file.transfer.error.multipart_complete');
      case 'multipartAbortFailed':
        return FileTransferL10n.text('file.transfer.error.multipart_abort');
      case 'multipartListPartsFailed':
        return FileTransferL10n.text('file.transfer.error.multipart_list');
      case 'multipartPartIntegrityMismatch':
        return FileTransferL10n.text('file.transfer.error.multipart_integrity');
      default:
        return FileTransferL10n.text('file.transfer.error.multipart_part');
    }
  }

  private static createClient(cfg: OSSRuntimeConfig, init: OSSClientInitParams): Client {
    if (init.endpoint.length > 0) {
      return new Client({
        accessKeyId: cfg.accessKeyId,
        accessKeySecret: cfg.accessKeySecret,
        securityToken: cfg.securityToken,
        region: init.region,
        endpoint: init.endpoint,
        cname: init.cname,
        secure: init.secure
      });
    }
    return new Client({
      accessKeyId: cfg.accessKeyId,
      accessKeySecret: cfg.accessKeySecret,
      securityToken: cfg.securityToken,
      region: init.region,
      secure: true
    });
  }

  private closeClientOnce(client: Client): void {
    try {
      client.requestHandler.getSession().close();
    } catch (_e) {
      // idempotent
    }
    if (this.activeClient === client) {
      this.activeClient = undefined;
    }
    this.sessionClosed = true;
  }

  private static readUploadId(res: Object): string {
    try {
      const rec = res as Record<string, Object | string>;
      const data = rec['data'] as Record<string, string> | undefined;
      if (data && typeof data['uploadId'] === 'string') {
        return data['uploadId'];
      }
    } catch (_e) {
      // ignore
    }
    return '';
  }

  private static readEtag(res: Object): string {
    try {
      const rec = res as Record<string, Object>;
      const orig = rec['origRes'] as Record<string, Object> | undefined;
      if (!orig) {
        return '';
      }
      const headers = orig['headers'] as Record<string, string> | undefined;
      if (!headers) {
        return '';
      }
      const keys = Object.keys(headers);
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i];
        if (k.toLowerCase() === 'etag') {
          let v = headers[k].trim();
          if (v.indexOf('"') === 0 && v.lastIndexOf('"') === v.length - 1 && v.length >= 2) {
            v = v.substring(1, v.length - 1);
          }
          return v;
        }
      }
    } catch (_e) {
      // ignore
    }
    return '';
  }

  private static readListedParts(res: Object): MultipartListedPart[] {
    const out: MultipartListedPart[] = [];
    try {
      const rec = res as Record<string, Object>;
      const data = rec['data'] as Record<string, Object> | undefined;
      if (!data) {
        return out;
      }
      const parts = data['part'];
      if (!(parts instanceof Array)) {
        return out;
      }
      for (let i = 0; i < parts.length; i++) {
        const p = parts[i] as Record<string, Object | string | number>;
        const item = new MultipartListedPart();
        item.partNumber = Number(p['partNumber'] ?? 0);
        item.etag = `${p['eTag'] ?? p['etag'] ?? ''}`;
        item.size = Number(p['size'] ?? 0);
        out.push(item);
      }
    } catch (_e) {
      // ignore
    }
    return out;
  }

  private static sizeBucket(bytes: number): string {
    if (bytes <= 0) {
      return '0';
    }
    if (bytes < 1024 * 1024) {
      return 'lt1m';
    }
    if (bytes < 5 * 1024 * 1024) {
      return 'lt5m';
    }
    if (bytes < 10 * 1024 * 1024) {
      return 'lt10m';
    }
    return 'gte10m';
  }
}

export class MultipartListedPart {
  partNumber: number = 0;
  etag: string = '';
  size: number = 0;
}

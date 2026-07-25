import Client from '@aliyun/oss';
import { fileIo as fs } from '@kit.CoreFileKit';
import { OSSRuntimeConfig } from './OSSRuntimeConfig';
import { OSSClientConfigNormalizer, OSSClientInitParams } from './OSSClientConfigNormalizer';
import { OSSErrorDecodeContext, OSSErrorDecoder } from './OSSErrorDecoder';
import { OSSDiagnosticFingerprint } from './OSSDiagnosticFingerprint';
import { OSSVendorSdkMeta } from './OSSVendorSdkMeta';
import {
  CancelToken,
  ContentTypeCategory,
  FileTransferError,
  FileTransferErrorDiagnostics,
  FileTransferPhase,
  StsAgeBucket,
  contentTypeCategoryOf
} from '../../../Core/FileStorage/FileStorageModels';
import { FileUploadMode } from '../../../Core/FileStorage/FileUploadMode';
import { ObjectKeyPolicy } from '../../../Core/FileStorage/ObjectKeyPolicy';
import { FileTransferL10n } from '../../../Core/FileStorage/FileTransferL10n';
import { Logger } from '../../../Foundation/Logging/Logger';
import { LogModule } from '../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../Foundation/Logging/LogEvent';
import { ErrorLogger } from '../../../Foundation/Logging/ErrorLogger';
import { LogLevel } from '../../../Foundation/Logging/LogLevel';

/** Simple PutObject 输入（HOS-FILE-OSS-0008/0009）。无旧 policy 字段。 */
export class OSSSimpleUploadInput {
  localPath: string = '';
  objectKey: string = '';
  contentType: string = 'application/octet-stream';
  contentLength: number = 0;
  config: OSSRuntimeConfig = new OSSRuntimeConfig();
  transferIdHash: string = '';
  stsAgeBucket: StsAgeBucket = 'unknown';
  sizeBucket: string = '';
  /** 0=首次；1=同模式有限重试（不换 payload）。 */
  retryAttempt: number = 0;
}

/**
 * 官方 PutObject 简单上传（HOS-FILE-OSS-0008/0009）。
 * 唯一生产 PutObject 入口；禁止 append / multipart / 旧 policy fallback。
 * 策略固定：ArrayBuffer + 显式 Content-Length；不发 Content-MD5 / Content-Type header。
 */
export class OSSSimpleUploadAdapter {
  static readonly POLICY_VERSION: string = 'simple-v1';
  private activeClient?: Client;

  async upload(
    input: OSSSimpleUploadInput,
    cancelToken?: CancelToken,
    onApproxProgress?: (phase: FileTransferPhase) => void
  ): Promise<void> {
    const initialKeyFp = input.objectKey.length > 0
      ? ObjectKeyPolicy.fingerprint(input.objectKey)
      : 'empty';
    this.logStage('oss.put.validation_started', input, undefined, initialKeyFp,
      `localPathPresent=${input.localPath.length > 0};objectKeyBytes=${input.objectKey.length};` +
      `contentLength=${input.contentLength};contentTypeCategory=${contentTypeCategoryOf(input.contentType)};` +
      `hasAccessKeyId=${input.config.accessKeyId.trim().length > 0};` +
      `hasAccessKeySecret=${input.config.accessKeySecret.trim().length > 0};` +
      `hasSecurityToken=${input.config.securityToken.trim().length > 0}`);
    cancelToken?.throwIfCancelled('uploading');
    const cfg = input.config;
    if (!cfg.isComplete() || cfg.securityToken.trim().length === 0) {
      throw new FileTransferError(
        cfg.isComplete() ? 'ossConfigurationInvalid' : 'credentialsExpired',
        'acquiringCredentials',
        cfg.isComplete()
          ? FileTransferL10n.text('file.transfer.error.configuration')
          : '凭证无效',
        !cfg.isComplete()
      );
    }
    ObjectKeyPolicy.assertKeyValid(input.objectKey);
    if (input.contentLength <= 0 ||
      input.contentLength > FileUploadMode.SIMPLE_THRESHOLD_BYTES ||
      input.localPath.length === 0) {
      throw new FileTransferError(
        'sourceInvalid',
        'uploading',
        FileTransferL10n.text('file.transfer.error.source_invalid'),
        false
      );
    }

    const init = OSSClientConfigNormalizer.normalize(cfg.region, cfg.endpoint, cfg.bucketRegion);
    const category: ContentTypeCategory = contentTypeCategoryOf(input.contentType);
    const keyFp = ObjectKeyPolicy.fingerprint(input.objectKey);
    this.logStage('oss.put.validation_succeeded', input, init, keyFp,
      `contentLength=${input.contentLength};contentTypeCategory=${category};` +
      `sizeBucket=${input.sizeBucket.length > 0 ? input.sizeBucket : FileUploadMode.sizeBucket(input.contentLength)};` +
      `objectKeyBytes=${input.objectKey.length};bucketFp=${OSSDiagnosticFingerprint.bucketFingerprint(cfg.bucketName)}`);
    this.logStage('oss.put.config_snapshot', input, init, keyFp,
      `${OSSClientConfigNormalizer.toLogDetail(init)};` +
      `configuredEndpointBytes=${cfg.endpoint.length};configuredRegionBytes=${cfg.region.length};` +
      `bucketRegionBytes=${cfg.bucketRegion.length};bucketFp=${OSSDiagnosticFingerprint.bucketFingerprint(cfg.bucketName)}`);

    if (init.configurationIssue.length > 0 || !init.regionEndpointConsistent) {
      this.logStarted(input, init, category, keyFp);
      const cfgErr = new FileTransferError(
        'ossConfigurationInvalid',
        'uploading',
        FileTransferL10n.text('file.transfer.error.configuration'),
        false
      );
      const diag = new FileTransferErrorDiagnostics();
      diag.operation = 'oss.put_object';
      diag.transportRetryable = false;
      diag.userCanRetry = false;
      diag.requestValidationReason = 'endpointConfig';
      diag.objectKeyFingerprint = keyFp;
      diag.transportPolicyVersion = OSSSimpleUploadAdapter.POLICY_VERSION;
      cfgErr.withDiagnostics(diag);
      throw cfgErr;
    }

    this.logStarted(input, init, category, keyFp);
    this.logTargetResolved(input, init, keyFp);
    try {
      await this.putOnce(input, init, category, keyFp, cancelToken, onApproxProgress);
    } catch (firstErr) {
      if (!(firstErr instanceof FileTransferError)) {
        if (firstErr instanceof Error) {
          throw firstErr;
        }
        throw new FileTransferError(
          'ossTransientFailure',
          'uploading',
          FileTransferL10n.text('file.transfer.error.transient'),
          true
        );
      }
      const isRcp = OSSErrorDecoder.isRcpTransportReason(firstErr.requestValidationReason ?? '');
      // 同模式仅重试一次；不切换 payload / 不升级 multipart。
      if (!isRcp || input.retryAttempt > 0) {
        this.logStage('oss.put.retry_decision', input, init, keyFp,
          `decision=stop;eligible=false;reason=${!isRcp ? 'not_retryable_transport' : 'max_attempt_reached'};` +
          `currentAttempt=${input.retryAttempt};nextAttempt=none;maxAttempts=1`);
        throw firstErr;
      }
      const retryLog = new LogFields();
      retryLog.operation = 'oss.put_object';
      retryLog.retryCount = 1;
      retryLog.detail =
        `reason=${firstErr.requestValidationReason};retry=freshClientSamePayload;` +
        `mode=simple;policy=${OSSSimpleUploadAdapter.POLICY_VERSION};` +
        `transferHash=${OSSSimpleUploadAdapter.transferHash(input)};` +
        `currentAttempt=${input.retryAttempt};nextAttempt=1;maxAttempts=1;` +
        `samePayload=true;sameTarget=true`;
      Logger.warn('oss.put.retrying', LogModule.OSS, retryLog);
      this.logStage('oss.put.retry_decision', input, init, keyFp,
        `decision=retry;eligible=true;reason=${firstErr.requestValidationReason};` +
        `currentAttempt=${input.retryAttempt};nextAttempt=1;maxAttempts=1;samePayload=true;sameTarget=true`);
      const retry = OSSSimpleUploadAdapter.cloneInput(input);
      retry.retryAttempt = 1;
      this.logStarted(retry, init, category, keyFp);
      try {
        await this.putOnce(retry, init, category, keyFp, cancelToken, onApproxProgress);
      } catch (retryErr) {
        this.logStage('oss.put.retry_decision', retry, init, keyFp,
          `decision=stop;eligible=false;reason=retry_attempt_failed;currentAttempt=1;nextAttempt=none;maxAttempts=1`);
        if (retryErr instanceof FileTransferError) {
          throw retryErr;
        }
        if (retryErr instanceof Error) {
          throw retryErr;
        }
        throw new FileTransferError(
          'ossTransientFailure',
          'uploading',
          FileTransferL10n.text('file.transfer.error.transient'),
          true
        );
      }
    }
  }

  cancelActive(): void {
    this.closeActive();
  }

  private async putOnce(
    input: OSSSimpleUploadInput,
    init: OSSClientInitParams,
    category: ContentTypeCategory,
    keyFp: string,
    cancelToken?: CancelToken,
    onApproxProgress?: (phase: FileTransferPhase) => void
  ): Promise<void> {
    const cfg = input.config;
    const clientCreateStartedAt = Date.now();
    this.logStage('oss.put.client_create_started', input, init, keyFp,
      `client=aliyun-oss;targetHost=${OSSSimpleUploadAdapter.effectiveEndpointHost(init)};` +
      `endpointMode=${init.actualEndpointMode};secure=${init.endpoint.length > 0 ? init.secure : true};` +
      `cname=${init.endpoint.length > 0 ? init.cname : false}`);
    const client = this.createClient(cfg, init);
    this.activeClient = client;
    this.logClientCreated(input, init, keyFp);
    this.logStage('oss.put.client_create_finished', input, init, keyFp,
      `elapsedMs=${Date.now() - clientCreateStartedAt};clientReady=true`);
    const startedAt = Date.now();
    try {
      if (onApproxProgress) {
        onApproxProgress('uploading');
      }
      cancelToken?.throwIfCancelled('uploading');
      const fileReadStartedAt = Date.now();
      this.logStage('oss.put.file_read_started', input, init, keyFp,
        `localPathPresent=${input.localPath.length > 0};expectedBytes=${input.contentLength}`);
      const data = OSSSimpleUploadAdapter.readFileToArrayBuffer(input.localPath, input.contentLength);
      this.logStage('oss.put.file_read_succeeded', input, init, keyFp,
        `elapsedMs=${Date.now() - fileReadStartedAt};actualBytes=${data.byteLength};expectedBytes=${input.contentLength};` +
        `bytesMatch=${data.byteLength === input.contentLength}`);
      const prepared = new LogFields();
      prepared.operation = 'oss.put_object';
      prepared.detail =
        `targetHost=${OSSSimpleUploadAdapter.effectiveEndpointHost(init)};` +
        `targetSource=${init.endpoint.length > 0 ? 'serverEndpoint' : 'sdkRegionDerived'};` +
        `payloadType=ArrayBuffer;payloadBytes=${data.byteLength};` +
        `contentLength=${input.contentLength};contentTypeHeader=omitted;contentMd5=omitted;` +
        `retryAttempt=${input.retryAttempt};keyFp=${keyFp};` +
        `transferHash=${OSSSimpleUploadAdapter.transferHash(input)};bucketFp=${OSSDiagnosticFingerprint.bucketFingerprint(cfg.bucketName)}`;
      Logger.info('oss.put.request_prepared', LogModule.OSS, prepared);
      this.logStage('oss.put.request_started', input, init, keyFp,
        `payloadType=ArrayBuffer;payloadBytes=${data.byteLength};contentLength=${input.contentLength};` +
        `contentTypeHeader=omitted;contentMd5=omitted;clientAgeMs=${Date.now() - startedAt}`);
      await client.putObject({
        bucket: cfg.bucketName,
        key: input.objectKey,
        data: data,
        contentLength: input.contentLength
      });
      cancelToken?.throwIfCancelled('uploading');
      this.logStage('oss.put.request_succeeded', input, init, keyFp,
        `elapsedMs=${Date.now() - startedAt};httpStatus=2xx;responseBody=not_logged`);
      const ok = new LogFields();
      ok.operation = 'oss.put_object';
      ok.elapsedMs = Date.now() - startedAt;
      ok.detail =
        `mode=simple;policy=${OSSSimpleUploadAdapter.POLICY_VERSION};` +
        `contentTypeCategory=${category};keyFp=${keyFp};` +
        `fileBytes=${input.contentLength};retryAttempt=${input.retryAttempt};` +
        `bucketFp=${OSSDiagnosticFingerprint.bucketFingerprint(cfg.bucketName)};` +
        `${OSSClientConfigNormalizer.toLogDetail(init)};${OSSVendorSdkMeta.toLogDetail()}`;
      Logger.info('oss.put.succeeded', LogModule.OSS, ok);
    } catch (err) {
      if (err instanceof FileTransferError) {
        throw err;
      }
      const ctx = new OSSErrorDecodeContext();
      ctx.contentTypeCategory = category;
      ctx.objectKeyFingerprint = keyFp;
      ctx.stsAgeBucket = input.stsAgeBucket;
      ctx.hasContentMd5 = false;
      ctx.transportPolicyVersion = OSSSimpleUploadAdapter.POLICY_VERSION;
      const mapped = OSSErrorDecoder.decode(err as Object, cancelToken, ctx);
      if (!mapped.requestValidationReason) {
        mapped.requestValidationReason = 'unknown';
      }
      const errMsg = OSSErrorDecoder.readStringField(err as Object, 'message');
      const errCode = OSSErrorDecoder.readCodeField(err as Object);
      const isRcp = OSSErrorDecoder.isRcpTransportReason(mapped.requestValidationReason);
      const mappedOssRequestId = mapped.ossRequestId ?? '';
      const mappedOssCode = mapped.ossCode ?? '';
      this.logStage('oss.put.raw_error', input, init, keyFp,
        `rawCode=${errCode.length > 0 ? errCode : 'n'};rawMessage=${OSSSimpleUploadAdapter.safeRcpMsg(errMsg)};` +
        `mappedLayer=${isRcp ? 'rcp' : 'oss'};elapsedMs=${Date.now() - startedAt}`);
      this.logStage('oss.put.error_decoded', input, init, keyFp,
        `mappedCode=${mapped.code};reason=${mapped.requestValidationReason ?? 'unknown'};` +
        `transportRetryable=${mapped.transportRetryable};userCanRetry=${mapped.userCanRetry};` +
        `httpStatus=${mapped.httpStatus ?? 0};hasOssRequestId=${mappedOssRequestId.length > 0};` +
        `hasOssCode=${mappedOssCode.length > 0};elapsedMs=${Date.now() - startedAt}`);
      const fail = new LogFields();
      fail.operation = 'oss.put_object';
      fail.elapsedMs = Date.now() - startedAt;
      fail.code = mapped.code;
      if (!isRcp && mapped.ossRequestId) {
        fail.ossRequestId = mapped.ossRequestId;
      }
      fail.detail =
        `mode=simple;policy=${OSSSimpleUploadAdapter.POLICY_VERSION};` +
        `errorLayer=${isRcp ? 'rcp' : 'oss'};` +
        `httpStatus=${mapped.httpStatus ?? 0};` +
        `ossCode=${isRcp ? '' : (mapped.ossCode ?? '')};` +
        `rcpCode=${isRcp ? (errCode.length > 0 ? errCode : (mapped.ossCode ?? 'n')) : 'n'};` +
        `reason=${mapped.requestValidationReason ?? 'unknown'};` +
        `rcpMsg=${OSSSimpleUploadAdapter.safeRcpMsg(errMsg)};` +
        `retryAttempt=${input.retryAttempt};keyFp=${keyFp};` +
        `fileBytes=${input.contentLength};` +
        `targetHost=${OSSSimpleUploadAdapter.effectiveEndpointHost(init)};` +
        `targetSource=${init.endpoint.length > 0 ? 'serverEndpoint' : 'sdkRegionDerived'};` +
        `${OSSClientConfigNormalizer.toLogDetail(init)};${OSSVendorSdkMeta.toLogDetail()}`;
      ErrorLogger.log('oss.put.failed', LogModule.OSS, mapped, LogLevel.ERROR, fail);
      throw mapped;
    } finally {
      this.closeClientOnce(client, input, init, keyFp);
    }
  }

  private logStarted(
    input: OSSSimpleUploadInput,
    init: OSSClientInitParams,
    category: ContentTypeCategory,
    keyFp: string
  ): void {
    const started = new LogFields();
    started.operation = 'oss.put_object';
    started.detail =
      `mode=simple;policy=${OSSSimpleUploadAdapter.POLICY_VERSION};` +
      `contentTypeCategory=${category};` +
      `sizeBucket=${input.sizeBucket.length > 0 ? input.sizeBucket : FileUploadMode.sizeBucket(input.contentLength)};` +
      `fileBytes=${input.contentLength};keyFp=${keyFp};stsAge=${input.stsAgeBucket};` +
      `retryAttempt=${input.retryAttempt};` +
      `bucketFp=${OSSDiagnosticFingerprint.bucketFingerprint(input.config.bucketName)};` +
      `${OSSClientConfigNormalizer.toLogDetail(init)};${OSSVendorSdkMeta.toLogDetail()}` +
      (input.transferIdHash.length > 0
        ? `;transferHash=${input.transferIdHash.substring(0, 16)}`
        : '');
    Logger.info('oss.put.started', LogModule.OSS, started);
  }

  private createClient(cfg: OSSRuntimeConfig, init: OSSClientInitParams): Client {
    if (init.endpoint.length > 0) {
      const client = new Client({
        accessKeyId: cfg.accessKeyId,
        accessKeySecret: cfg.accessKeySecret,
        securityToken: cfg.securityToken,
        region: init.region,
        endpoint: init.endpoint,
        cname: init.cname,
        secure: init.secure
      });
      return client;
    }
    const client = new Client({
      accessKeyId: cfg.accessKeyId,
      accessKeySecret: cfg.accessKeySecret,
      securityToken: cfg.securityToken,
      region: init.region,
      secure: true
    });
    return client;
  }

  private logTargetResolved(
    input: OSSSimpleUploadInput,
    init: OSSClientInitParams,
    keyFp: string
  ): void {
    const fields = new LogFields();
    fields.operation = 'oss.put_object';
    fields.detail =
      `targetHost=${OSSSimpleUploadAdapter.effectiveEndpointHost(init)};` +
      `targetSource=${init.endpoint.length > 0 ? 'serverEndpoint' : 'sdkRegionDerived'};` +
      `region=${init.region};endpointMode=${init.actualEndpointMode};` +
      `endpointOmitted=${init.endpointOmitted};secure=${init.secure};cname=${init.cname};` +
      `endpointBytes=${init.endpoint.length};fileBytes=${input.contentLength};keyFp=${keyFp}`;
    fields.detail += `;transferHash=${OSSSimpleUploadAdapter.transferHash(input)};` +
      `configuredEndpointAlias=${init.configuredEndpointAlias};derivedEndpointAlias=${init.derivedEndpointAlias};` +
      `signatureRegionAlias=${init.signatureRegionAlias};bucketRegionAlias=${init.bucketRegionAlias}`;
    Logger.info('oss.put.target_resolved', LogModule.OSS, fields);
  }

  private logClientCreated(
    input: OSSSimpleUploadInput,
    init: OSSClientInitParams,
    keyFp: string
  ): void {
    const fields = new LogFields();
    fields.operation = 'oss.put_object';
    fields.detail =
      `client=aliyun-oss;targetHost=${OSSSimpleUploadAdapter.effectiveEndpointHost(init)};` +
      `targetSource=${init.endpoint.length > 0 ? 'serverEndpoint' : 'sdkRegionDerived'};` +
      `region=${init.region};endpointMode=${init.actualEndpointMode};` +
      `secure=${init.endpoint.length > 0 ? init.secure : true};cname=${init.endpoint.length > 0 ? init.cname : false};` +
      `fileBytes=${input.contentLength};keyFp=${keyFp}`;
    fields.detail += `;transferHash=${OSSSimpleUploadAdapter.transferHash(input)}`;
    Logger.info('oss.put.client_created', LogModule.OSS, fields);
  }

  private closeActive(): void {
    if (this.activeClient) {
      this.closeClientOnce(this.activeClient);
    }
  }

  private closeClientOnce(
    client: Client,
    input?: OSSSimpleUploadInput,
    init?: OSSClientInitParams,
    keyFp: string = 'n'
  ): void {
    if (input && init) {
      this.logStage('oss.put.session_close_started', input, init, keyFp,
        'session=active;closeRequested=true');
    }
    let closeResult = 'closed';
    try {
      client.requestHandler.getSession().close();
    } catch (_e) {
      closeResult = 'close_failed';
    }
    const fields = new LogFields();
    fields.operation = 'oss.put_object';
    fields.detail = `session=${closeResult};transferHash=${input ? OSSSimpleUploadAdapter.transferHash(input) : 'n'};` +
      `targetHost=${init ? OSSSimpleUploadAdapter.effectiveEndpointHost(init) : 'n'}`;
    Logger.info('oss.put.session_closed', LogModule.OSS, fields);
    if (this.activeClient === client) {
      this.activeClient = undefined;
    }
  }

  private static effectiveEndpointHost(init: OSSClientInitParams): string {
    if (init.endpoint.length > 0) {
      return OSSClientConfigNormalizer.hostOf(init.endpoint);
    }
    if (init.region.length > 0) {
      return `${init.region}.aliyuncs.com`;
    }
    return 'empty';
  }

  private static transferHash(input: OSSSimpleUploadInput): string {
    return input.transferIdHash.length > 0 ? input.transferIdHash.substring(0, 16) : 'n';
  }

  private logStage(
    event: string,
    input: OSSSimpleUploadInput,
    init: OSSClientInitParams | undefined,
    keyFp: string,
    detail: string
  ): void {
    const fields = new LogFields();
    fields.operation = 'oss.put_object';
    fields.detail =
      `transferHash=${OSSSimpleUploadAdapter.transferHash(input)};` +
      `retryAttempt=${input.retryAttempt};keyFp=${keyFp};` +
      `targetHost=${init ? OSSSimpleUploadAdapter.effectiveEndpointHost(init) : 'unresolved'};` +
      detail;
    Logger.info(event, LogModule.OSS, fields);
  }

  private static cloneInput(input: OSSSimpleUploadInput): OSSSimpleUploadInput {
    const next = new OSSSimpleUploadInput();
    next.localPath = input.localPath;
    next.objectKey = input.objectKey;
    next.contentType = input.contentType;
    next.contentLength = input.contentLength;
    next.config = input.config;
    next.transferIdHash = input.transferIdHash;
    next.stsAgeBucket = input.stsAgeBucket;
    next.sizeBucket = input.sizeBucket;
    next.retryAttempt = input.retryAttempt;
    return next;
  }

  private static readFileToArrayBuffer(localPath: string, expectedLength: number): ArrayBuffer {
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
      const buf = new ArrayBuffer(expectedLength);
      const read = fs.readSync(file.fd, buf);
      if (read !== expectedLength) {
        throw new FileTransferError(
          'sourceInvalid',
          'uploading',
          FileTransferL10n.text('file.transfer.error.source_invalid'),
          false
        );
      }
      return buf;
    } catch (e) {
      if (e instanceof FileTransferError) {
        throw e;
      }
      throw new FileTransferError(
        'localIoFailed',
        'uploading',
        FileTransferL10n.text('file.transfer.error.source_invalid'),
        false
      );
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (_closeErr) {
          // ignore
        }
      }
    }
  }

  private static safeRcpMsg(message: string): string {
    const trimmed = message.trim();
    if (trimmed.length === 0) {
      return 'n';
    }
    const lower = trimmed.toLowerCase();
    if (lower.indexOf('failure when receiving') >= 0) {
      return 'peer_receive_fail';
    }
    if (lower.indexOf('server returned nothing') >= 0 || lower.indexOf('no headers') >= 0) {
      return 'server_returned_nothing';
    }
    if (lower.indexOf('timeout') >= 0) {
      return 'timeout';
    }
    if (trimmed.length <= 40) {
      return trimmed.replace(/\s+/g, '_');
    }
    return `${trimmed.substring(0, 40).replace(/\s+/g, '_')}…`;
  }
}

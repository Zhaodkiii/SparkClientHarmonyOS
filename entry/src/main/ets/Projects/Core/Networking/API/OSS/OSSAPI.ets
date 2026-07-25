import { NetworkRequest, NetworkStrategy, RetryConfig, SupportNetworkError } from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { SupportAPIResponseDecoder } from '../Common/SupportAPIResponseDecoder';
import { OSSRuntimeConfig } from '../../../OSS/OSSRuntimeConfig';
import { OSSSTSConfigValidator } from '../../../OSS/OSSSTSConfigValidator';
import { FileTransferError } from '../../../../../Core/FileStorage/FileStorageModels';
import { FileTransferL10n } from '../../../../../Core/FileStorage/FileTransferL10n';

/**
 * 对齐 iOS SparkOSSAPI：GET /api/v1/oss/sts/credentials/
 * 解码失败 / 契约不完整 → FileTransferError(ossConfigurationInvalid)。
 */
export class OSSAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  async credentials(accountScope: string = 'anon'): Promise<OSSRuntimeConfig> {
    const op = new CacheableSupportNetworkOperation(
      'OSS.STS',
      'OSSAPI',
      new NetworkRequest(
        'GET',
        '/api/v1/oss/sts/credentials/',
        new NetworkStrategy(
          true,
          false,
          `oss.sts.${accountScope}`,
          true,
          'high',
          RetryConfig.defaultConfig()
        )
      )
    );
    try {
      return await this.configuration.executeDecoded(op, (data) => OSSAPI.decodeCredentials(data));
    } catch (err) {
      throw OSSAPI.mapAcquireError(err as Object);
    }
  }

  private static decodeCredentials(data: Object | null): OSSRuntimeConfig {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const cfg = new OSSRuntimeConfig();
    cfg.accessKeyId = SupportAPIResponseDecoder.strAny(obj, ['accessKeyId', 'access_key_id'], '');
    cfg.accessKeySecret = SupportAPIResponseDecoder.strAny(obj, ['accessKeySecret', 'access_key_secret'], '');
    cfg.securityToken = SupportAPIResponseDecoder.strAny(obj, ['securityToken', 'security_token'], '');
    cfg.expirationEpochSeconds = OSSAPI.parseExpiration(obj);
    cfg.bucketName = SupportAPIResponseDecoder.strAny(obj, ['bucketName', 'bucket_name'], '');
    cfg.region = SupportAPIResponseDecoder.strAny(obj, ['region'], '');
    cfg.endpoint = SupportAPIResponseDecoder.strAny(obj, ['endpoint'], '');
    cfg.bucketRegion = SupportAPIResponseDecoder.strAny(
      obj,
      ['bucketRegion', 'bucket_region'],
      ''
    );
    cfg.objectKeyPrefix = SupportAPIResponseDecoder.strAny(
      obj,
      ['objectKeyPrefix', 'object_key_prefix'],
      ''
    );
    cfg.configVersion = SupportAPIResponseDecoder.strAny(
      obj,
      ['configVersion', 'config_version'],
      ''
    );
    cfg.signatureVersion = SupportAPIResponseDecoder.strAny(
      obj,
      ['signatureVersion', 'signature_version'],
      ''
    );
    cfg.endpointType = SupportAPIResponseDecoder.strAny(
      obj,
      ['endpointType', 'endpoint_type'],
      ''
    );
    if (!cfg.isComplete()) {
      throw OSSSTSConfigValidator.toError('incomplete');
    }
    const check = OSSSTSConfigValidator.validate(cfg);
    if (!check.ok) {
      throw OSSSTSConfigValidator.toError(
        check.reason.length > 0 ? check.reason : 'regionEndpointMismatch'
      );
    }
    return cfg;
  }

  private static mapAcquireError(err: Object): FileTransferError {
    if (err instanceof FileTransferError) {
      return err;
    }
    if (err instanceof SupportNetworkError) {
      if (err.statusCode === 401 || err.kind === 'unauthenticated' || err.kind === 'refreshFailed') {
        return new FileTransferError(
          'unauthorized',
          'acquiringCredentials',
          FileTransferL10n.text('file.transfer.error.unauthorized'),
          false,
          err.requestId,
          err.statusCode
        );
      }
      if (OSSAPI.isServerConfigurationError(err)) {
        return OSSSTSConfigValidator.toError('serverConfigInvalid', err.requestId);
      }
      if (err.kind === 'transport' || err.kind === 'cancelled') {
        return new FileTransferError(
          err.kind === 'cancelled' ? 'cancelled' : 'networkUnavailable',
          'acquiringCredentials',
          err.kind === 'cancelled' ? '' : FileTransferL10n.text('file.transfer.error.network'),
          true,
          err.requestId,
          err.statusCode
        );
      }
      if (err.kind === 'decoding' || err.kind === 'invalidResponse') {
        return OSSSTSConfigValidator.toError('decodeFailed', err.requestId);
      }
      return new FileTransferError(
        'networkUnavailable',
        'acquiringCredentials',
        FileTransferL10n.text('file.transfer.error.network'),
        true,
        err.requestId,
        err.statusCode
      );
    }
    if (err instanceof Error && err.message === 'incomplete_sts_response') {
      return OSSSTSConfigValidator.toError('incomplete');
    }
    return OSSSTSConfigValidator.toError('unknown');
  }

  /** 服务端明确的 OSS 配置错误（若未来返回对应 code）。 */
  private static isServerConfigurationError(err: SupportNetworkError): boolean {
    if (!err.backend) {
      return false;
    }
    const code = err.backend.code;
    if (code === 5001) {
      return true;
    }
    const msg = (err.backend.message ?? '').toLowerCase();
    return msg.indexOf('oss_configuration') >= 0 ||
      msg.indexOf('configuration_invalid') >= 0 ||
      (msg.indexOf('region') >= 0 && msg.indexOf('endpoint') >= 0);
  }

  private static parseExpiration(
    obj: Record<string, Object | string | number | boolean | null>
  ): number {
    const raw = obj['expiration'] ?? obj['expirationEpochSeconds'] ?? obj['expiration_epoch_seconds'];
    if (typeof raw === 'number' && Number.isFinite(raw)) {
      return raw > 1e12 ? Math.floor(raw / 1000) : Math.floor(raw);
    }
    if (typeof raw === 'string' && raw.length > 0) {
      const asNum = Number(raw);
      if (!Number.isNaN(asNum)) {
        return asNum > 1e12 ? Math.floor(asNum / 1000) : Math.floor(asNum);
      }
      const ms = Date.parse(raw);
      if (!Number.isNaN(ms)) {
        return Math.floor(ms / 1000);
      }
    }
    return 0;
  }
}

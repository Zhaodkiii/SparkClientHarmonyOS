/**
 * STS 运行时配置契约校验（HOS-FILE-OSS-0005）。
 * 只校验、阻断与诊断；不得替服务器修正 Region/Endpoint。
 */
import { OSSClientConfigNormalizer, OSSClientInitParams } from './OSSClientConfigNormalizer';
import { OSSRuntimeConfig } from './OSSRuntimeConfig';
import { FileTransferError, FileTransferErrorDiagnostics } from '../../../Core/FileStorage/FileStorageModels';
import { FileTransferL10n } from '../../../Core/FileStorage/FileTransferL10n';

export class OSSSTSConfigValidationResult {
  ok: boolean = false;
  reason: string = '';
  init: OSSClientInitParams = new OSSClientInitParams();
}

export class OSSSTSConfigValidator {
  /**
   * 完整性 + Region/Endpoint/BucketRegion 一致性。
   * 不修改 cfg 字段；冲突时 ok=false。
   */
  static validate(cfg: OSSRuntimeConfig): OSSSTSConfigValidationResult {
    const out = new OSSSTSConfigValidationResult();
    if (!cfg.isComplete()) {
      out.ok = false;
      out.reason = 'incomplete';
      return out;
    }

    // 官方 STS 模式必须 SecurityToken；生产上传一律走 STS，构造 Client 前阻断空 token。
    if (cfg.securityToken.trim().length === 0) {
      out.ok = false;
      out.reason = 'missingSecurityToken';
      return out;
    }

    const sig = cfg.signatureVersion.trim().toLowerCase();
    if (sig.length > 0 && sig !== 'v4' && sig !== 'oss4' && sig !== '4') {
      out.ok = false;
      out.reason = 'unsupportedSignature';
      return out;
    }

    const host = OSSClientConfigNormalizer.hostOf(cfg.endpoint);
    const isCustom = OSSClientConfigNormalizer.isCustomDomain(host);
    const endpointType = cfg.endpointType.trim().toLowerCase();
    if (isCustom && endpointType.length > 0 && endpointType !== 'custom') {
      out.ok = false;
      out.reason = 'customEndpointUnspecified';
      return out;
    }

    const init = OSSClientConfigNormalizer.normalize(cfg.region, cfg.endpoint, cfg.bucketRegion);
    out.init = init;
    if (init.configurationIssue.length > 0 || !init.regionEndpointConsistent) {
      out.ok = false;
      out.reason = init.configurationIssue.length > 0
        ? init.configurationIssue
        : 'regionEndpointMismatch';
      return out;
    }

    // bucket_region 若下发，必须与 region 同地域（已由 normalizer 冲突检测覆盖）。
    out.ok = true;
    out.reason = '';
    return out;
  }

  /** 契约失败 → FileTransferError（stage=acquiringCredentials）。 */
  static toError(
    reason: string,
    backendRequestId?: string
  ): FileTransferError {
    const err = new FileTransferError(
      'ossConfigurationInvalid',
      'acquiringCredentials',
      FileTransferL10n.text('file.transfer.error.configuration'),
      false,
      backendRequestId
    );
    const diag = new FileTransferErrorDiagnostics();
    diag.operation = 'oss.sts.credentials';
    diag.transportRetryable = false;
    diag.userCanRetry = false;
    diag.requestValidationReason = reason.length > 0 ? reason : 'endpointConfig';
    if (backendRequestId && backendRequestId.length > 0) {
      diag.requestId = backendRequestId;
    }
    return err.withDiagnostics(diag);
  }

  static safeLogDetail(cfg: OSSRuntimeConfig, init: OSSClientInitParams, reason: string = ''): string {
    let detail =
      `configVersion=${OSSSTSConfigValidator.alias(cfg.configVersion, 32)};` +
      `signatureVersion=${OSSSTSConfigValidator.alias(
        cfg.signatureVersion.length > 0 ? cfg.signatureVersion : 'default',
        16
      )};` +
      `roleMode=${cfg.securityToken.length > 0 ? 'STS' : 'static'};` +
      `objectKeyPrefixAlias=${OSSSTSConfigValidator.prefixAlias(cfg.objectKeyPrefix)};` +
      OSSClientConfigNormalizer.toLogDetail(init);
    if (reason.length > 0) {
      detail = `${detail};reason=${reason}`;
    }
    return detail;
  }

  private static prefixAlias(prefix: string): string {
    const p = prefix.trim();
    if (p.length === 0) {
      return 'default';
    }
    if (p.indexOf('SparkClient') === 0) {
      return 'SparkClient';
    }
    return 'custom';
  }

  private static alias(value: string, max: number): string {
    const v = value.trim();
    if (v.length === 0) {
      return 'empty';
    }
    if (v.length <= max) {
      return v;
    }
    return `${v.substring(0, max)}…`;
  }
}

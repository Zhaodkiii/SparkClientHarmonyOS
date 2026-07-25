import { describe, it, expect } from '@ohos/hypium';
import { OSSErrorDecoder } from '../../../main/ets/Projects/Core/OSS/OSSErrorDecoder';
import { OSSClientConfigNormalizer } from '../../../main/ets/Projects/Core/OSS/OSSClientConfigNormalizer';
import { OSSSTSConfigValidator } from '../../../main/ets/Projects/Core/OSS/OSSSTSConfigValidator';
import { OSSRuntimeConfig } from '../../../main/ets/Projects/Core/OSS/OSSRuntimeConfig';
import { FileTransferErrorLocalizer } from '../../../main/ets/Core/FileStorage/FileTransferErrorLocalizer';
import { FileTransferError } from '../../../main/ets/Core/FileStorage/FileStorageModels';
import { FileUploadMode } from '../../../main/ets/Core/FileStorage/FileUploadMode';
import { OSSSimpleUploadAdapter } from '../../../main/ets/Projects/Core/OSS/OSSSimpleUploadAdapter';
import { ObjectKeyPolicy } from '../../../main/ets/Core/FileStorage/ObjectKeyPolicy';
import { FileHashUtil } from '../../../main/ets/Core/FileStorage/FileHashUtil';
import { Logger } from '../../../main/ets/Foundation/Logging/Logger';
import { LogLevel } from '../../../main/ets/Foundation/Logging/LogLevel';
import { ErrorLogger } from '../../../main/ets/Foundation/Logging/ErrorLogger';
import { LogModule } from '../../../main/ets/Foundation/Logging/LogModule';
import { LogFields } from '../../../main/ets/Foundation/Logging/LogEvent';

class FakeSdkError {
  status?: number;
  requestId?: string;
  code?: string;
  ec?: string;
  message: string = '';
  name: string = 'RequestError';
}

function completeConfig(
  region: string,
  endpoint: string,
  bucketRegion: string = ''
): OSSRuntimeConfig {
  const cfg = new OSSRuntimeConfig();
  cfg.accessKeyId = 'STS.TEST';
  cfg.accessKeySecret = 'secret';
  cfg.securityToken = 'token';
  cfg.expirationEpochSeconds = Math.floor(Date.now() / 1000) + 3600;
  cfg.bucketName = 'test-bucket';
  cfg.region = region;
  cfg.endpoint = endpoint;
  cfg.bucketRegion = bucketRegion;
  cfg.configVersion = 'oss-test-v1';
  cfg.signatureVersion = 'v4';
  return cfg;
}

export default function ossErrorDecoderTest() {
  describe('OSS_HOS_FILE_OSS_0005', () => {
    it('validates_matching_sts_contract', 0, () => {
      const cfg = completeConfig(
        'cn-beijing',
        'https://oss-cn-beijing.aliyuncs.com',
        'cn-beijing'
      );
      const check = OSSSTSConfigValidator.validate(cfg);
      expect(check.ok).assertEqual(true);
      expect(check.init.region).assertEqual('oss-cn-beijing');
      expect(check.init.regionEndpointConsistent).assertEqual(true);
      expect(check.init.endpointOmitted).assertEqual(true);
    });

    it('rejects_shanghai_beijing_conflict_at_sts_validate', 0, () => {
      const cfg = completeConfig(
        'cn-shanghai',
        'https://oss-cn-beijing.aliyuncs.com',
        ''
      );
      const check = OSSSTSConfigValidator.validate(cfg);
      expect(check.ok).assertEqual(false);
      expect(check.reason.length > 0).assertTrue();
      const err = OSSSTSConfigValidator.toError(check.reason);
      expect(err.code).assertEqual('ossConfigurationInvalid');
      expect(err.stage).assertEqual('acquiringCredentials');
      expect(err.userCanRetry).assertEqual(false);
      expect(err.transportRetryable).assertEqual(false);
    });

    it('rejects_bucket_region_mismatch', 0, () => {
      const cfg = completeConfig(
        'cn-beijing',
        'https://oss-cn-beijing.aliyuncs.com',
        'cn-shanghai'
      );
      const check = OSSSTSConfigValidator.validate(cfg);
      expect(check.ok).assertEqual(false);
    });

    it('rejects_unsupported_signature_version', 0, () => {
      const cfg = completeConfig(
        'cn-beijing',
        'https://oss-cn-beijing.aliyuncs.com',
        'cn-beijing'
      );
      cfg.signatureVersion = 'v1';
      const check = OSSSTSConfigValidator.validate(cfg);
      expect(check.ok).assertEqual(false);
      expect(check.reason).assertEqual('unsupportedSignature');
    });

    it('normalizer_still_blocks_put_preflight_conflict', 0, () => {
      const init = OSSClientConfigNormalizer.normalize(
        'cn-shanghai',
        'https://oss-cn-beijing.aliyuncs.com',
        ''
      );
      expect(init.regionEndpointConsistent).assertEqual(false);
      expect(init.configurationIssue).assertEqual('endpointConfig');
    });

    it('object_key_respects_server_prefix', 0, () => {
      const key = ObjectKeyPolicy.makeValidatedKey(
        FileHashUtil.randomUuid(),
        'a.jpg',
        Date.now(),
        'SparkClient/'
      );
      expect(key.indexOf('SparkClient/') === 0).assertTrue();
      // fingerprint 中的 keyBytes 是 object key 长度，不是文件内容大小。
      expect(ObjectKeyPolicy.fingerprint(key).indexOf('keyBytes=') >= 0).assertTrue();
    });

    it('access_denied_is_not_user_retryable', 0, () => {
      const err = new FakeSdkError();
      err.status = 403;
      err.code = 'AccessDenied';
      err.ec = '0003-00001403';
      const mapped = OSSErrorDecoder.decode(err as Object);
      expect(mapped.code).assertEqual('ossAccessDenied');
      expect(mapped.userCanRetry).assertEqual(false);
    });

    it('localizer_configuration_invalid_returns_to_picking', 0, () => {
      const err = new FileTransferError(
        'ossConfigurationInvalid',
        'acquiringCredentials',
        '上传服务配置异常，请稍后再试。',
        false
      );
      err.userCanRetry = false;
      const presentation = FileTransferErrorLocalizer.present(err);
      expect(presentation.primaryAction).assertEqual('returnToPicking');
      expect(presentation.retryable).assertEqual(false);
    });

    it('production_mode_log_uses_simple_multipart_v1', 0, () => {
      const small = FileUploadMode.select(500 * 1024);
      const large = FileUploadMode.select(9 * 1024 * 1024);
      expect(small.mode).assertEqual('simple');
      expect(large.mode).assertEqual('multipart');
      expect(FileUploadMode.toLogDetail(small).indexOf('mode=simple;policy=simple-v1') === 0).assertTrue();
      expect(FileUploadMode.toLogDetail(large).indexOf('policy=multipart-v1') >= 0).assertTrue();
      expect(OSSSimpleUploadAdapter.POLICY_VERSION).assertEqual('simple-v1');
    });

    it('rcp_peer_receive_maps_to_peerReceiveFailed', 0, () => {
      const err = new FakeSdkError();
      err.status = 0;
      err.code = '1007900056';
      err.message = 'Failure when receiving data from the peer';
      const mapped = OSSErrorDecoder.decode(err as Object);
      expect(mapped.code).assertEqual('ossTransientFailure');
      expect(mapped.requestValidationReason).assertEqual('peerReceiveFailed');
      expect(mapped.userCanRetry).assertEqual(true);
      expect(mapped.safeMessage.indexOf('网络连接不稳定') >= 0).assertTrue();
    });

    it('rejects_missing_security_token_at_sts_validate', 0, () => {
      const cfg = completeConfig(
        'cn-beijing',
        'https://oss-cn-beijing.aliyuncs.com',
        'cn-beijing'
      );
      cfg.securityToken = '';
      const check = OSSSTSConfigValidator.validate(cfg);
      expect(check.ok).assertEqual(false);
      expect(check.reason).assertEqual('missingSecurityToken');
    });

    it('error_logger_keeps_oss_id_separate', 0, () => {
      const lines: string[] = [];
      Logger.setCaptureSinkForTests((line: string, _level: LogLevel) => {
        lines.push(line);
      });
      try {
        const err = new FileTransferError(
          'ossConfigurationInvalid',
          'acquiringCredentials',
          '上传服务配置异常，请稍后再试。',
          false
        );
        err.requestId = 'BACKEND-1';
        const extra = new LogFields();
        extra.requestId = 'BACKEND-1';
        extra.detail = 'reason=regionEndpointMismatch';
        ErrorLogger.log('oss.sts.failed', LogModule.OSS, err, LogLevel.ERROR, extra);
        const joined = lines.join('\n');
        expect(joined.indexOf('"requestId":"BACKEND-1"') >= 0).assertTrue();
      } finally {
        Logger.resetForTests();
      }
    });

    it('incomplete_config_fails_isComplete', 0, () => {
      const cfg = new OSSRuntimeConfig();
      cfg.accessKeyId = 'x';
      expect(cfg.isComplete()).assertEqual(false);
    });
  });
}

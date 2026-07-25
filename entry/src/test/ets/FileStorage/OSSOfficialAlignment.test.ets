import { describe, it, expect } from '@ohos/hypium';
import { OSSErrorDecoder } from '../../../main/ets/Projects/Core/OSS/OSSErrorDecoder';
import { OSSClientConfigNormalizer } from '../../../main/ets/Projects/Core/OSS/OSSClientConfigNormalizer';
import { OSSSTSConfigValidator } from '../../../main/ets/Projects/Core/OSS/OSSSTSConfigValidator';
import { OSSRuntimeConfig } from '../../../main/ets/Projects/Core/OSS/OSSRuntimeConfig';
import { OSSVendorSdkMeta } from '../../../main/ets/Projects/Core/OSS/OSSVendorSdkMeta';
import { OSSDiagnosticFingerprint } from '../../../main/ets/Projects/Core/OSS/OSSDiagnosticFingerprint';
import { OSSSimpleUploadAdapter } from '../../../main/ets/Projects/Core/OSS/OSSSimpleUploadAdapter';
import { FileUploadMode } from '../../../main/ets/Core/FileStorage/FileUploadMode';
import { FileTransferErrorLocalizer } from '../../../main/ets/Core/FileStorage/FileTransferErrorLocalizer';
import { FileTransferService } from '../../../main/ets/Core/FileStorage/FileTransferService';
import { FileTransferError } from '../../../main/ets/Core/FileStorage/FileStorageModels';

class FakeSdkError {
  status?: number;
  requestId?: string;
  code?: string;
  ec?: string;
  message: string = '';
  name: string = 'RequestError';
}

function completeConfig(): OSSRuntimeConfig {
  const cfg = new OSSRuntimeConfig();
  cfg.accessKeyId = 'STS.TEST';
  cfg.accessKeySecret = 'secret';
  cfg.securityToken = 'token';
  cfg.expirationEpochSeconds = Math.floor(Date.now() / 1000) + 3600;
  cfg.bucketName = 'test-bucket';
  cfg.region = 'cn-beijing';
  cfg.endpoint = 'https://oss-cn-beijing.aliyuncs.com';
  cfg.bucketRegion = 'cn-beijing';
  cfg.configVersion = 'oss-test-v1';
  cfg.signatureVersion = 'v4';
  return cfg;
}

export default function ossOfficialAlignmentTest() {
  describe('OSS_HOS_FILE_OSS_0007_0009', () => {
    it('vendor_sdk_meta_marks_beta_not_admitted', 0, () => {
      expect(OSSVendorSdkMeta.PACKAGE_NAME).assertEqual('@aliyun/oss');
      expect(OSSVendorSdkMeta.VERSION).assertEqual('2.0.0-beta.1');
      expect(OSSVendorSdkMeta.PRODUCTION_ADMITTED).assertEqual(false);
      expect(OSSVendorSdkMeta.COMPATIBLE_API_MIN).assertEqual(12);
      const detail = OSSVendorSdkMeta.toLogDetail();
      expect(detail.indexOf('sdkVer=2.0.0-beta.1') >= 0).assertTrue();
      expect(detail.indexOf('sdkProductionAdmitted=false') >= 0).assertTrue();
    });

    it('sts_requires_security_token', 0, () => {
      const cfg = completeConfig();
      cfg.securityToken = '';
      const check = OSSSTSConfigValidator.validate(cfg);
      expect(check.ok).assertEqual(false);
      expect(check.reason).assertEqual('missingSecurityToken');
    });

    it('standard_public_client_uses_server_endpoint', 0, () => {
      const cfg = completeConfig();
      const init = OSSClientConfigNormalizer.normalize(cfg.region, cfg.endpoint, cfg.bucketRegion);
      expect(init.configurationIssue.length).assertEqual(0);
      expect(init.regionEndpointConsistent).assertTrue();
      expect(init.region).assertEqual('oss-cn-beijing');
      expect(init.secure).assertEqual(true);
      expect(init.cname).assertEqual(false);
      expect(init.endpointOmitted).assertFalse();
      expect(init.actualEndpointMode).assertEqual('explicit');
      expect(init.endpoint).assertEqual('https://oss-cn-beijing.aliyuncs.com');
    });

    it('production_modes_only_simple_and_multipart', 0, () => {
      const simple = FileUploadMode.select(1024);
      const multipart = FileUploadMode.select(9 * 1024 * 1024);
      expect(simple.mode).assertEqual('simple');
      expect(multipart.mode).assertEqual('multipart');
      expect(FileUploadMode.toLogDetail(simple).indexOf('mode=simple;policy=simple-v1') === 0).assertTrue();
      expect(FileUploadMode.toLogDetail(multipart).indexOf('policy=multipart-v1') >= 0).assertTrue();
      expect(OSSSimpleUploadAdapter.POLICY_VERSION).assertEqual('simple-v1');
    });

    it('bucket_fingerprint_stable_and_secret_free', 0, () => {
      const a = OSSDiagnosticFingerprint.bucketFingerprint('test-bucket');
      const b = OSSDiagnosticFingerprint.bucketFingerprint('test-bucket');
      expect(a).assertEqual(b);
      expect(a.indexOf('v1:') === 0).assertTrue();
      expect(a.indexOf('test-bucket') < 0).assertTrue();
    });

    it('rcp_1007900052_maps_to_serverReturnedNothing', 0, () => {
      const err = new FakeSdkError();
      err.status = 0;
      err.code = '1007900052';
      err.message = 'Server returned nothing (no headers, no data)';
      const mapped = OSSErrorDecoder.decode(err as Object);
      expect(mapped.code).assertEqual('ossTransientFailure');
      expect(mapped.requestValidationReason).assertEqual('serverReturnedNothing');
      expect(mapped.httpStatus === undefined || mapped.httpStatus === 0).assertTrue();
      expect(!mapped.ossRequestId || mapped.ossRequestId.length === 0).assertTrue();
      expect(mapped.userCanRetry).assertEqual(true);
      expect(OSSErrorDecoder.isRcpTransportReason('serverReturnedNothing')).assertTrue();
    });

    it('rcp_does_not_forge_oss_ec_or_request_id', 0, () => {
      const err = new FakeSdkError();
      err.status = 0;
      err.code = '1007900056';
      err.message = 'Failure when receiving data from the peer';
      err.requestId = '';
      err.ec = '';
      const mapped = OSSErrorDecoder.decode(err as Object);
      expect(mapped.requestValidationReason).assertEqual('peerReceiveFailed');
      expect(!mapped.ossEc || mapped.ossEc.length === 0).assertTrue();
      expect(!mapped.ossRequestId || mapped.ossRequestId.length === 0).assertTrue();
    });

    it('zero_status_rcp_transient_can_continue_as_success', 0, () => {
      const err = new FileTransferError(
        'ossTransientFailure',
        'uploading',
        '上传失败',
        true
      );
      err.httpStatus = 0;
      err.requestValidationReason = 'peerReceiveFailed';
      err.transportRetryable = true;
      expect(FileTransferService.isZeroStatusBypassCandidate(err)).assertEqual(true);
    });

    it('undefined_http_status_rcp_transient_can_continue_as_success', 0, () => {
      const err = new FileTransferError(
        'ossTransientFailure',
        'uploading',
        '上传失败',
        true
      );
      err.requestValidationReason = 'peerReceiveFailed';
      err.transportRetryable = true;
      expect(FileTransferService.isZeroStatusBypassCandidate(err)).assertEqual(true);
    });

    it('zero_status_bypass_can_be_disabled', 0, () => {
      const err = new FileTransferError(
        'ossTransientFailure',
        'uploading',
        '上传失败',
        true
      );
      err.requestValidationReason = 'peerReceiveFailed';
      err.transportRetryable = true;
      expect(FileTransferService.isZeroStatusBypassCandidate(err, false)).assertEqual(false);
    });

    it('oss_access_denied_keeps_request_id_and_ec', 0, () => {
      const err = new FakeSdkError();
      err.status = 403;
      err.code = 'AccessDenied';
      err.ec = '0003-00001403';
      err.requestId = 'OSS-REQ-1';
      const mapped = OSSErrorDecoder.decode(err as Object);
      expect(mapped.code).assertEqual('ossAccessDenied');
      expect(mapped.ossRequestId).assertEqual('OSS-REQ-1');
      expect(mapped.ossEc).assertEqual('0003-00001403');
      expect(mapped.httpStatus).assertEqual(403);
      expect(OSSErrorDecoder.isRcpTransportReason(mapped.requestValidationReason ?? '')).assertEqual(false);
    });

    it('localizer_uses_rcp_copy_for_serverReturnedNothing', 0, () => {
      const err = new FakeSdkError();
      err.status = 0;
      err.code = '1007900052';
      err.message = 'Server returned nothing (no headers, no data)';
      const mapped = OSSErrorDecoder.decode(err as Object);
      const presentation = FileTransferErrorLocalizer.present(mapped);
      expect(presentation.message.indexOf('网络连接不稳定') >= 0).assertTrue();
      expect(presentation.message.indexOf('1007900052') < 0).assertTrue();
    });

    it('vendor_meta_log_marks_beta_gate', 0, () => {
      const detail = OSSVendorSdkMeta.toLogDetail();
      expect(detail.indexOf('sdkVer=') >= 0).assertTrue();
      expect(detail.indexOf('sdkProductionAdmitted=false') >= 0).assertTrue();
    });

    it('normalizer_cname_only_for_custom_endpoint', 0, () => {
      const custom = OSSClientConfigNormalizer.normalize(
        'oss-cn-beijing',
        'https://cdn.example.com',
        'oss-cn-beijing'
      );
      expect(custom.actualEndpointMode).assertEqual('custom');
      expect(custom.cname).assertEqual(true);
      const std = OSSClientConfigNormalizer.normalize(
        'cn-beijing',
        'https://oss-cn-beijing.aliyuncs.com',
        'cn-beijing'
      );
      expect(std.cname).assertEqual(false);
      expect(std.endpointOmitted).assertEqual(false);
      expect(std.actualEndpointMode).assertEqual('explicit');
      expect(std.endpoint).assertEqual('https://oss-cn-beijing.aliyuncs.com');
    });
  });
}

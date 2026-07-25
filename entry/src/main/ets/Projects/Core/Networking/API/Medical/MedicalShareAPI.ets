import { NetworkRequest, NetworkStrategy, RetryConfig } from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { SupportAPIResponseDecoder } from '../Common/SupportAPIResponseDecoder';

/** 创建分享响应。对齐 iOS `SparkMedicalShareAPI.CreateShareResponse`。 */
export class MedicalShareCreateResponse {
  shareCode: string = '';
  shareUrl: string = '';
  businessType: string = '';
  businessId: number = 0;
  expiresAt: string = '';
  status: string = '';

  static fromJson(data: Object | null): MedicalShareCreateResponse {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const out = new MedicalShareCreateResponse();
    out.shareCode = SupportAPIResponseDecoder.strAny(obj, ['share_code', 'shareCode'], '');
    out.shareUrl = SupportAPIResponseDecoder.strAny(obj, ['share_url', 'shareUrl'], '');
    out.businessType = SupportAPIResponseDecoder.strAny(obj, ['business_type', 'businessType'], '');
    out.businessId = SupportAPIResponseDecoder.numAny(obj, ['business_id', 'businessId'], 0);
    out.expiresAt = SupportAPIResponseDecoder.strAny(obj, ['expires_at', 'expiresAt'], '');
    out.status = SupportAPIResponseDecoder.str(obj, 'status', '');
    return out;
  }
}

/**
 * 公开 Web 分享 API。对齐 iOS `SparkMedicalShareAPI`。
 */
export class SparkMedicalShareAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  async createShare(businessType: string, businessID: number): Promise<MedicalShareCreateResponse> {
    const body: Record<string, string | number> = {};
    body['businessType'] = businessType;
    body['businessId'] = businessID;
    const strategy = new NetworkStrategy(
      true,
      false,
      `medical.share.create.${businessType}.${businessID}`,
      false,
      'high',
      RetryConfig.disabled()
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.Share.Create',
      'SparkMedicalShareAPI',
      new NetworkRequest('POST', '/api/v1/medical/shares/', strategy, [], {}, body)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) =>
      MedicalShareCreateResponse.fromJson(data)
    );
  }
}

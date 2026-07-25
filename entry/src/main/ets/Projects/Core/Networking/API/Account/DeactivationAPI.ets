import { NetworkRequest, NetworkStrategy, RetryConfig } from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { SupportAPIResponseDecoder } from '../Common/SupportAPIResponseDecoder';

/** 注销验证载荷：otp 通道；huawei 字段预留 */
export class DeactivationVerificationPayload {
  kind: string = ''; // phone | email | huawei
  otpId: string = '';
  code: string = '';
  /** 预留：未来 Account Kit */
  identityToken: string = '';
  authorizationCode: string = '';
  userIdentifier: string = '';

  static phone(otpId: string, code: string): DeactivationVerificationPayload {
    const p = new DeactivationVerificationPayload();
    p.kind = 'phone';
    p.otpId = otpId;
    p.code = code;
    return p;
  }

  static email(otpId: string, code: string): DeactivationVerificationPayload {
    const p = new DeactivationVerificationPayload();
    p.kind = 'email';
    p.otpId = otpId;
    p.code = code;
    return p;
  }

  toRecord(): Record<string, Object> {
    const body: Record<string, Object> = {};
    body['type'] = this.kind;
    if (this.kind === 'phone' || this.kind === 'email') {
      body['otp_id'] = this.otpId;
      body['code'] = this.code;
    }
    if (this.kind === 'huawei') {
      body['identity_token'] = this.identityToken;
      if (this.authorizationCode.length > 0) {
        body['authorization_code'] = this.authorizationCode;
      }
      body['user_identifier'] = this.userIdentifier;
    }
    return body;
  }
}

export class DeactivationRequest {
  reason?: string;
  immediateDeactivation: boolean = true;
  countdownHours?: number;
  dataRetentionDays: number = 30;
  anonymizePersonalData: boolean = true;
  deleteRelatedData: boolean = true;
  verification?: DeactivationVerificationPayload;
}

export class AccountDeactivationSubmissionResponse {
  deactivationId: number = 0;
  state: string = '';
  scheduledAt?: string;
  immediateDeactivation?: boolean;
  countdownHours?: number;
}

export class DeactivationAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  async submit(request: DeactivationRequest): Promise<AccountDeactivationSubmissionResponse> {
    const body: Record<string, Object> = {};
    body['immediateDeactivation'] = request.immediateDeactivation;
    body['dataRetentionDays'] = request.dataRetentionDays;
    body['anonymizePersonalData'] = request.anonymizePersonalData;
    body['deleteRelatedData'] = request.deleteRelatedData;
    if (request.reason !== undefined && request.reason.length > 0) {
      body['reason'] = request.reason;
    }
    if (request.countdownHours !== undefined) {
      body['countdownHours'] = request.countdownHours;
    }
    if (request.verification !== undefined) {
      body['verification'] = request.verification.toRecord();
    }
    const op = new CacheableSupportNetworkOperation(
      'Account.Deactivation',
      'DeactivationAPI',
      new NetworkRequest(
        'POST',
        '/api/v1/deactivation/',
        new NetworkStrategy(true, false, undefined, false, 'normal', RetryConfig.disabled()),
        [],
        {},
        body
      )
    );
    return this.configuration.executeDecoded(op, (data) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      const r = new AccountDeactivationSubmissionResponse();
      r.deactivationId = SupportAPIResponseDecoder.num(obj, 'deactivationId');
      r.state = SupportAPIResponseDecoder.str(obj, 'state');
      r.scheduledAt = SupportAPIResponseDecoder.optStr(obj, 'scheduledAt');
      r.immediateDeactivation = SupportAPIResponseDecoder.optBool(obj, 'immediateDeactivation');
      r.countdownHours = SupportAPIResponseDecoder.optNum(obj, 'countdownHours');
      return r;
    });
  }
}

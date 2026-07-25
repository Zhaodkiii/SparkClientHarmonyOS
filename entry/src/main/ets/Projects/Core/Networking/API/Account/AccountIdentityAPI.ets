import { NetworkRequest, NetworkStrategy, QueryItem, RetryConfig } from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { SupportAPIResponseDecoder } from '../Common/SupportAPIResponseDecoder';

export class IdentityStatusDTO {
  provider: string = '';
  bound: boolean = false;
  maskedValue: string = '';
  modifiable: boolean = false;
  bindable: boolean = false;
}

export class IdentityListResult {
  accountId: number = 0;
  bundleId: string = '';
  identityScope: string = '';
  identities: IdentityStatusDTO[] = [];
}

export class VerificationRequestResult {
  otpId?: string;
  expiresIn?: number;
  provider?: string;
  ready?: boolean;
}

export class VerificationTicketResult {
  verificationTicket: string = '';
  expiresIn: number = 0;
}

/** POST identity-verification/request */
export class IdentityVerificationRequestBody {
  provider: string;
  purpose: string;
  bundleId: string;
  deviceId: string;

  constructor(provider: string, purpose: string, bundleId: string, deviceId: string) {
    this.provider = provider;
    this.purpose = purpose;
    this.bundleId = bundleId;
    this.deviceId = deviceId;
  }

  toRecord(): Record<string, Object> {
    const body: Record<string, Object> = {};
    body['provider'] = this.provider;
    body['purpose'] = this.purpose;
    body['bundle_id'] = this.bundleId;
    body['device_id'] = this.deviceId;
    return body;
  }
}

/** POST identity-verification/verify */
export class VerifyIdentityRequest {
  provider: string;
  purpose: string;
  otpId: string = '';
  code: string = '';
  bundleId: string = '';
  deviceId: string = '';

  constructor(provider: string, purpose: string) {
    this.provider = provider;
    this.purpose = purpose;
  }

  static phoneOtp(
    purpose: string,
    otpId: string,
    code: string,
    bundleId: string,
    deviceId: string
  ): VerifyIdentityRequest {
    const r = new VerifyIdentityRequest('phone', purpose);
    r.otpId = otpId;
    r.code = code;
    r.bundleId = bundleId;
    r.deviceId = deviceId;
    return r;
  }

  static emailOtp(
    purpose: string,
    otpId: string,
    code: string,
    bundleId: string,
    deviceId: string
  ): VerifyIdentityRequest {
    const r = new VerifyIdentityRequest('email', purpose);
    r.otpId = otpId;
    r.code = code;
    r.bundleId = bundleId;
    r.deviceId = deviceId;
    return r;
  }

  toRecord(): Record<string, Object> {
    const body: Record<string, Object> = {};
    body['provider'] = this.provider;
    body['purpose'] = this.purpose;
    body['otp_id'] = this.otpId;
    body['code'] = this.code;
    body['bundle_id'] = this.bundleId;
    body['device_id'] = this.deviceId;
    return body;
  }
}

/** POST identities/bind */
export class BindIdentityRequest {
  provider: string;
  verificationTicket: string;
  target: string = '';
  otpId: string = '';
  code: string = '';
  bundleId: string = '';
  deviceId: string = '';

  constructor(provider: string, verificationTicket: string) {
    this.provider = provider;
    this.verificationTicket = verificationTicket;
  }

  static phone(
    ticket: string,
    target: string,
    otpId: string,
    code: string,
    bundleId: string,
    deviceId: string
  ): BindIdentityRequest {
    const r = new BindIdentityRequest('phone', ticket);
    r.target = target;
    r.otpId = otpId;
    r.code = code;
    r.bundleId = bundleId;
    r.deviceId = deviceId;
    return r;
  }

  static email(
    ticket: string,
    target: string,
    otpId: string,
    code: string,
    bundleId: string,
    deviceId: string
  ): BindIdentityRequest {
    const r = new BindIdentityRequest('email', ticket);
    r.target = target;
    r.otpId = otpId;
    r.code = code;
    r.bundleId = bundleId;
    r.deviceId = deviceId;
    return r;
  }

  toRecord(): Record<string, Object> {
    const body: Record<string, Object> = {};
    body['provider'] = this.provider;
    body['verification_ticket'] = this.verificationTicket;
    body['target'] = this.target;
    body['otp_id'] = this.otpId;
    body['code'] = this.code;
    body['bundle_id'] = this.bundleId;
    body['device_id'] = this.deviceId;
    return body;
  }
}

/** POST identities/change */
export class ChangeIdentityRequest {
  provider: string;
  verificationTicket: string;
  newTarget: string;
  newOtpId: string;
  newCode: string;
  bundleId: string;
  deviceId: string;

  constructor(
    provider: string,
    verificationTicket: string,
    newTarget: string,
    newOtpId: string,
    newCode: string,
    bundleId: string,
    deviceId: string
  ) {
    this.provider = provider;
    this.verificationTicket = verificationTicket;
    this.newTarget = newTarget;
    this.newOtpId = newOtpId;
    this.newCode = newCode;
    this.bundleId = bundleId;
    this.deviceId = deviceId;
  }

  toRecord(): Record<string, Object> {
    const body: Record<string, Object> = {};
    body['provider'] = this.provider;
    body['verification_ticket'] = this.verificationTicket;
    body['new_target'] = this.newTarget;
    body['new_otp_id'] = this.newOtpId;
    body['new_code'] = this.newCode;
    body['bundle_id'] = this.bundleId;
    body['device_id'] = this.deviceId;
    return body;
  }
}

function mapIdentityList(data: Object | null): IdentityListResult {
  const obj = SupportAPIResponseDecoder.asRecord(data);
  const r = new IdentityListResult();
  r.accountId = SupportAPIResponseDecoder.num(obj, 'accountId') || SupportAPIResponseDecoder.num(obj, 'account_id');
  r.bundleId = SupportAPIResponseDecoder.str(obj, 'bundleId') || SupportAPIResponseDecoder.str(obj, 'bundle_id');
  r.identityScope =
    SupportAPIResponseDecoder.str(obj, 'identityScope') || SupportAPIResponseDecoder.str(obj, 'identity_scope');
  const list = obj['identities'];
  if (Array.isArray(list)) {
    const arr = list as Object[];
    for (let i = 0; i < arr.length; i++) {
      const item = SupportAPIResponseDecoder.asRecord(arr[i]);
      const dto = new IdentityStatusDTO();
      dto.provider = SupportAPIResponseDecoder.str(item, 'provider');
      dto.bound = SupportAPIResponseDecoder.bool(item, 'bound');
      dto.maskedValue =
        SupportAPIResponseDecoder.str(item, 'maskedValue') || SupportAPIResponseDecoder.str(item, 'masked_value');
      dto.modifiable = SupportAPIResponseDecoder.bool(item, 'modifiable');
      dto.bindable = SupportAPIResponseDecoder.bool(item, 'bindable');
      r.identities.push(dto);
    }
  }
  return r;
}

export class AccountIdentityAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  async listIdentities(bundleId: string): Promise<IdentityListResult> {
    const op = new CacheableSupportNetworkOperation(
      'Account.ListIdentities',
      'AccountIdentityAPI',
      new NetworkRequest(
        'GET',
        '/api/v1/accounts/identities/',
        new NetworkStrategy(true, false, undefined, true),
        [new QueryItem('bundle_id', bundleId)]
      )
    );
    return this.configuration.executeDecoded(op, mapIdentityList);
  }

  async requestVerification(body: IdentityVerificationRequestBody): Promise<VerificationRequestResult> {
    const op = new CacheableSupportNetworkOperation(
      'Account.RequestVerification',
      'AccountIdentityAPI',
      new NetworkRequest(
        'POST',
        '/api/v1/accounts/identity-verification/request/',
        new NetworkStrategy(true),
        [],
        {},
        body.toRecord()
      )
    );
    return this.configuration.executeDecoded(op, (data) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      const r = new VerificationRequestResult();
      r.otpId = SupportAPIResponseDecoder.optStr(obj, 'otpId') ?? SupportAPIResponseDecoder.optStr(obj, 'otp_id');
      r.expiresIn =
        SupportAPIResponseDecoder.optNum(obj, 'expiresIn') ?? SupportAPIResponseDecoder.optNum(obj, 'expires_in');
      r.provider = SupportAPIResponseDecoder.optStr(obj, 'provider');
      r.ready = SupportAPIResponseDecoder.optBool(obj, 'ready');
      return r;
    });
  }

  async verifyAndIssueTicket(body: VerifyIdentityRequest): Promise<VerificationTicketResult> {
    const op = new CacheableSupportNetworkOperation(
      'Account.VerifyTicket',
      'AccountIdentityAPI',
      new NetworkRequest(
        'POST',
        '/api/v1/accounts/identity-verification/verify/',
        new NetworkStrategy(true),
        [],
        {},
        body.toRecord()
      )
    );
    return this.configuration.executeDecoded(op, (data) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      const r = new VerificationTicketResult();
      r.verificationTicket =
        SupportAPIResponseDecoder.str(obj, 'verificationTicket') ||
        SupportAPIResponseDecoder.str(obj, 'verification_ticket');
      r.expiresIn =
        SupportAPIResponseDecoder.num(obj, 'expiresIn') || SupportAPIResponseDecoder.num(obj, 'expires_in');
      return r;
    });
  }

  async bindIdentity(body: BindIdentityRequest): Promise<IdentityListResult> {
    const op = new CacheableSupportNetworkOperation(
      'Account.BindIdentity',
      'AccountIdentityAPI',
      new NetworkRequest(
        'POST',
        '/api/v1/accounts/identities/bind/',
        new NetworkStrategy(true, false, undefined, false, 'normal', RetryConfig.disabled()),
        [],
        {},
        body.toRecord()
      )
    );
    return this.configuration.executeDecoded(op, mapIdentityList);
  }

  async changeIdentity(body: ChangeIdentityRequest): Promise<IdentityListResult> {
    const op = new CacheableSupportNetworkOperation(
      'Account.ChangeIdentity',
      'AccountIdentityAPI',
      new NetworkRequest(
        'POST',
        '/api/v1/accounts/identities/change/',
        new NetworkStrategy(true, false, undefined, false, 'normal', RetryConfig.disabled()),
        [],
        {},
        body.toRecord()
      )
    );
    return this.configuration.executeDecoded(op, mapIdentityList);
  }
}

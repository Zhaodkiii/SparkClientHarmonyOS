export type AccountIdentityProvider = 'phone' | 'email' | 'huawei';

export class AccountIdentityProviders {
  static readonly ALL: AccountIdentityProvider[] = ['phone', 'email', 'huawei'];

  static parse(raw: string): AccountIdentityProvider | undefined {
    const key = raw.trim().toLowerCase();
    if (key === 'phone' || key === 'email' || key === 'huawei') {
      return key;
    }
    if (key === 'apple') {
      return 'huawei';
    }
    return undefined;
  }

  static title(provider: AccountIdentityProvider): string {
    if (provider === 'phone') {
      return '手机号';
    }
    if (provider === 'email') {
      return '邮箱';
    }
    return 'Huawei 账号';
  }

  static isComingSoon(provider: AccountIdentityProvider): boolean {
    return provider === 'huawei';
  }
}

export class AccountIdentityStatus {
  provider: AccountIdentityProvider;
  bound: boolean;
  maskedValue: string;
  modifiable: boolean;
  bindable: boolean;

  constructor(
    provider: AccountIdentityProvider,
    bound: boolean,
    maskedValue: string,
    modifiable: boolean,
    bindable: boolean
  ) {
    this.provider = provider;
    this.bound = bound;
    this.maskedValue = maskedValue;
    this.modifiable = modifiable;
    this.bindable = bindable;
  }
}

export class AccountIdentityList {
  accountId: number;
  bundleId: string;
  identityScope: string;
  identities: AccountIdentityStatus[];

  constructor(
    accountId: number,
    bundleId: string,
    identityScope: string,
    identities: AccountIdentityStatus[]
  ) {
    this.accountId = accountId;
    this.bundleId = bundleId;
    this.identityScope = identityScope;
    this.identities = identities;
  }
}

export type AccountIdentityPurpose = 'bind_identity' | 'change_identity';

export class AccountIdentityOperation {
  provider: AccountIdentityProvider;
  purpose: AccountIdentityPurpose;

  constructor(provider: AccountIdentityProvider, purpose: AccountIdentityPurpose) {
    this.provider = provider;
    this.purpose = purpose;
  }

  static bind(provider: AccountIdentityProvider): AccountIdentityOperation {
    return new AccountIdentityOperation(provider, 'bind_identity');
  }

  static change(provider: AccountIdentityProvider): AccountIdentityOperation {
    return new AccountIdentityOperation(provider, 'change_identity');
  }

  targetOtpScene(): string {
    return this.purpose === 'bind_identity' ? 'identity_bind' : 'identity_change';
  }
}

export class VerificationTicket {
  ticket: string;
  expiresIn: number;

  constructor(ticket: string, expiresIn: number) {
    this.ticket = ticket;
    this.expiresIn = expiresIn;
  }
}

/** 再验证请求结果：OTP 或（未来）Huawei ready */
export class IdentityVerificationRequestResult {
  kind: string = ''; // 'otp' | 'huaweiReady'
  otpId: string = '';
  expiresIn: number = 0;

  static otp(otpId: string, expiresIn: number): IdentityVerificationRequestResult {
    const r = new IdentityVerificationRequestResult();
    r.kind = 'otp';
    r.otpId = otpId;
    r.expiresIn = expiresIn;
    return r;
  }

  static huaweiReady(): IdentityVerificationRequestResult {
    const r = new IdentityVerificationRequestResult();
    r.kind = 'huaweiReady';
    return r;
  }
}

export class AccountIdentityReauthProof {
  kind: string = ''; // phone | email
  otpId: string = '';
  code: string = '';

  static phone(otpId: string, code: string): AccountIdentityReauthProof {
    const p = new AccountIdentityReauthProof();
    p.kind = 'phone';
    p.otpId = otpId;
    p.code = code;
    return p;
  }

  static email(otpId: string, code: string): AccountIdentityReauthProof {
    const p = new AccountIdentityReauthProof();
    p.kind = 'email';
    p.otpId = otpId;
    p.code = code;
    return p;
  }
}

export class AccountIdentityBindProof {
  kind: string = '';
  target: string = '';
  otpId: string = '';
  code: string = '';

  static phone(target: string, otpId: string, code: string): AccountIdentityBindProof {
    const p = new AccountIdentityBindProof();
    p.kind = 'phone';
    p.target = target;
    p.otpId = otpId;
    p.code = code;
    return p;
  }

  static email(target: string, otpId: string, code: string): AccountIdentityBindProof {
    const p = new AccountIdentityBindProof();
    p.kind = 'email';
    p.target = target;
    p.otpId = otpId;
    p.code = code;
    return p;
  }
}

export class LockedPhoneTarget {
  countryCode: string;
  nationalNumber: string;
  e164: string;
  displayValue: string;

  constructor(countryCode: string, nationalNumber: string, e164: string, displayValue?: string) {
    this.countryCode = countryCode;
    this.nationalNumber = nationalNumber;
    this.e164 = e164;
    this.displayValue = displayValue ?? `${countryCode} ${nationalNumber}`;
  }
}

export class AccountVerificationRequestContext {
  channelKind: string; // phone | email
  maskedTarget: string;
  otpId: string;
  expiresIn: number;

  constructor(channelKind: string, maskedTarget: string, otpId: string, expiresIn: number) {
    this.channelKind = channelKind;
    this.maskedTarget = maskedTarget;
    this.otpId = otpId;
    this.expiresIn = expiresIn;
  }
}

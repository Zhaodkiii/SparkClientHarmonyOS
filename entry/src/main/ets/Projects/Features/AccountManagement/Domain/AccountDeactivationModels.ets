export class AccountDeactivationOptions {
  reason: string = '';
  immediateDeactivation: boolean = true;
  countdownHours: number = 24;
  dataRetentionDays: number = 30;
  anonymizePersonalData: boolean = true;
  deleteRelatedData: boolean = true;
}

export class AccountVerificationChannel {
  kind: string; // phone | email | huawei
  /** 完整目标（仅内存，发码用）；UI 用 displayMasked */
  fullTarget: string;
  displayMasked: string;

  constructor(kind: string, fullTarget: string = '', displayMasked: string = '') {
    this.kind = kind;
    this.fullTarget = fullTarget;
    this.displayMasked = displayMasked.length > 0 ? displayMasked : fullTarget;
  }

  static phone(fullTarget: string, displayMasked?: string): AccountVerificationChannel {
    return new AccountVerificationChannel('phone', fullTarget, displayMasked ?? fullTarget);
  }

  static email(fullTarget: string, displayMasked?: string): AccountVerificationChannel {
    return new AccountVerificationChannel('email', fullTarget, displayMasked ?? fullTarget);
  }

  static huawei(): AccountVerificationChannel {
    return new AccountVerificationChannel('huawei', '', '');
  }

  title(): string {
    if (this.kind === 'phone') {
      return '手机短信验证';
    }
    if (this.kind === 'email') {
      return '邮箱验证';
    }
    return 'Huawei 账号验证';
  }
}

export class AccountDeactivationVerification {
  kind: string = ''; // phone | email
  otpId: string = '';
  code: string = '';

  static phone(otpId: string, code: string): AccountDeactivationVerification {
    const v = new AccountDeactivationVerification();
    v.kind = 'phone';
    v.otpId = otpId;
    v.code = code;
    return v;
  }

  static email(otpId: string, code: string): AccountDeactivationVerification {
    const v = new AccountDeactivationVerification();
    v.kind = 'email';
    v.otpId = otpId;
    v.code = code;
    return v;
  }
}

export class AccountDeactivationSubmission {
  deactivationId: number;
  state: string;
  scheduledAt?: string;
  immediateDeactivation?: boolean;
  countdownHours?: number;

  constructor(deactivationId: number, state: string) {
    this.deactivationId = deactivationId;
    this.state = state;
  }
}

export type AccountManagementErrorKind =
  | 'missingSession'
  | 'unsupportedChannel'
  | 'missingProof'
  | 'huaweiComingSoon'
  | 'unknown';

export class AccountManagementError extends Error {
  kind: AccountManagementErrorKind;

  constructor(kind: AccountManagementErrorKind, message: string) {
    super(message);
    this.name = 'AccountManagementError';
    this.kind = kind;
  }

  static missingSession(): AccountManagementError {
    return new AccountManagementError('missingSession', '当前登录会话不可用');
  }

  static unsupportedChannel(): AccountManagementError {
    return new AccountManagementError('unsupportedChannel', '当前验证方式暂不支持');
  }

  static missingProof(): AccountManagementError {
    return new AccountManagementError('missingProof', '请先完成身份验证');
  }

  static huaweiComingSoon(): AccountManagementError {
    return new AccountManagementError('huaweiComingSoon', '即将支持');
  }
}

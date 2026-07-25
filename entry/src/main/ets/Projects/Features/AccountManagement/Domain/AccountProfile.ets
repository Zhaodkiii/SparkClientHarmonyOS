import { UserSession, SignInMethod } from '../../../Core/Domain/Entities/UserSession';

/**
 * 账户资料：来自本地 UserSession，不发网络。
 */
export class AccountProfile {
  accountId: number;
  displayName: string;
  contact: string;
  signInMethod: SignInMethod;
  signedInAtMs: number;
  isPro: boolean;
  isDeviceAccount: boolean;

  constructor(
    accountId: number,
    displayName: string,
    contact: string,
    signInMethod: SignInMethod,
    signedInAtMs: number,
    isPro: boolean,
    isDeviceAccount: boolean
  ) {
    this.accountId = accountId;
    this.displayName = displayName;
    this.contact = contact;
    this.signInMethod = signInMethod;
    this.signedInAtMs = signedInAtMs;
    this.isPro = isPro;
    this.isDeviceAccount = isDeviceAccount;
  }

  static fromSession(session: UserSession): AccountProfile {
    let contact = session.email;
    if (contact.length === 0 && (session.signInMethod === 'phone' || session.signInMethod === 'email')) {
      contact = session.displayName;
    }
    return new AccountProfile(
      session.accountId,
      session.displayName,
      contact,
      session.signInMethod,
      session.signedInAtMs,
      session.isPro,
      session.isDeviceAccount
    );
  }

  get email(): string | undefined {
    if (this.contact.indexOf('@') >= 0) {
      return this.contact;
    }
    return undefined;
  }

  signInMethodDescription(): string {
    if (this.signInMethod === 'phone') {
      return '手机号验证码';
    }
    if (this.signInMethod === 'email') {
      return '邮箱验证码';
    }
    if (this.signInMethod === 'huawei') {
      return 'Huawei 账号';
    }
    if (this.signInMethod === 'device') {
      return '游客模式';
    }
    if (this.signInMethod === 'apple') {
      return 'Apple 登录';
    }
    return `${this.signInMethod}`;
  }

  displayTitle(): string {
    if (this.displayName.length > 0) {
      return this.displayName;
    }
    if (this.contact.length > 0) {
      return this.contact;
    }
    return '未命名账号';
  }
}

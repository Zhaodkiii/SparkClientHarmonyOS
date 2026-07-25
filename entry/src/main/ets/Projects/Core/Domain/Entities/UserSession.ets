import { AuthenticatedUserContext, CurrentSessionResult } from '../../Networking/API/Auth/AuthAPI';
import { PhoneOTPVerifyResult } from '../../Networking/API/Auth/OTPAPI';

export type SignInMethod = 'device' | 'apple' | 'google' | 'phone' | 'email' | 'huawei' | string;

/**
 * 领域会话模型：不含 Token / deviceSecret。
 */
export class UserSession {
  accountId: number;
  email: string;
  displayName: string;
  signedInAtMs: number;
  signInMethod: SignInMethod;
  isPro: boolean;
  isNewUser: boolean;
  isDeviceAccount: boolean;

  constructor(
    accountId: number,
    signInMethod: SignInMethod = 'device',
    email: string = '',
    displayName: string = '',
    signedInAtMs: number = Date.now(),
    isPro: boolean = false,
    isNewUser: boolean = false,
    isDeviceAccount: boolean = false
  ) {
    this.accountId = accountId;
    this.email = email;
    this.displayName = displayName;
    this.signedInAtMs = signedInAtMs;
    this.signInMethod = signInMethod;
    this.isPro = isPro;
    this.isNewUser = isNewUser;
    this.isDeviceAccount = isDeviceAccount;
  }

  static fromAuthContext(ctx: AuthenticatedUserContext, signedInAtMs?: number): UserSession {
    return new UserSession(
      ctx.userId,
      ctx.signInMethod ?? (ctx.isDeviceAccount ? 'device' : 'phone'),
      ctx.email ?? '',
      ctx.displayName ?? '',
      signedInAtMs ?? Date.now(),
      ctx.isPro,
      ctx.isNewUser,
      ctx.isDeviceAccount
    );
  }

  static fromCurrentSession(remote: CurrentSessionResult, local?: UserSession): UserSession {
    const signedInAtMs = local?.signedInAtMs ?? Date.now();
    return new UserSession(
      remote.userId,
      remote.signInMethod ?? local?.signInMethod ?? 'device',
      remote.email ?? local?.email ?? '',
      remote.displayName ?? local?.displayName ?? '',
      signedInAtMs,
      remote.isPro ?? local?.isPro ?? false,
      remote.isNewUser !== undefined ? remote.isNewUser : (local?.isNewUser ?? false),
      remote.isDeviceAccount !== undefined ? remote.isDeviceAccount : (local?.isDeviceAccount ?? false)
    );
  }

  static fromPhoneOTP(result: PhoneOTPVerifyResult): UserSession {
    return new UserSession(
      result.userId,
      result.signInMethod ?? 'phone',
      '',
      result.displayName ?? result.phoneNumber ?? '',
      Date.now(),
      result.isPro ?? false,
      result.isNewUser ?? false,
      result.isDeviceAccount ?? false
    );
  }

  static fromPlain(obj: Record<string, Object | string | number | boolean | undefined>): UserSession | undefined {
    const accountRaw = obj['accountId'] ?? obj['userId'] ?? obj['user_id'] ?? obj['account_id'];
    const accountId = Number(accountRaw);
    if (!accountId || Number.isNaN(accountId)) {
      return undefined;
    }
    const methodRaw = `${obj['signInMethod'] ?? obj['sign_in_method'] ?? 'device'}`;
    return new UserSession(
      accountId,
      methodRaw,
      `${obj['email'] ?? ''}`,
      `${obj['displayName'] ?? obj['display_name'] ?? ''}`,
      Number(obj['signedInAtMs'] ?? obj['signed_in_at_ms'] ?? Date.now()),
      obj['isPro'] === true || obj['is_pro'] === true,
      obj['isNewUser'] === true || obj['is_new_user'] === true,
      obj['isDeviceAccount'] === true || obj['is_device_account'] === true
    );
  }

  toPlain(): Record<string, string | number | boolean> {
    const out: Record<string, string | number | boolean> = {};
    out['accountId'] = this.accountId;
    out['email'] = this.email;
    out['displayName'] = this.displayName;
    out['signedInAtMs'] = this.signedInAtMs;
    out['signInMethod'] = this.signInMethod;
    out['isPro'] = this.isPro;
    out['isNewUser'] = this.isNewUser;
    out['isDeviceAccount'] = this.isDeviceAccount;
    return out;
  }
}

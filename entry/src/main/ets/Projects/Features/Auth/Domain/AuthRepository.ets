import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { OTPRequestResponse } from '../../../Core/Networking/API/Auth/OTPAPI';

/**
 * 认证领域仓储契约（ArkTS 用 abstract class，避免结构类型限制）。
 */
export abstract class AuthRepository {
  abstract signInWithDevice(): Promise<UserSession>;

  abstract requestPhoneOTP(phoneNumber: string, scene?: string): Promise<OTPRequestResponse>;

  abstract signInWithPhoneOTP(otpId: string, phoneNumber: string, code: string): Promise<UserSession>;

  abstract restoreSession(): Promise<UserSession | undefined>;

  abstract signOut(): Promise<void>;

  abstract clearLocalSession(): Promise<void>;
}

import { AccountIdentityOperation } from '../Domain/AccountIdentityModels';
import { AccountVerificationChannel } from '../Domain/AccountDeactivationModels';
import { LockedPhoneTarget } from '../Domain/AccountIdentityModels';

export type IdentityFlowPhase =
  | 'idle'
  | 'choosingReauth'
  | 'reauthOTP'
  | 'enteringTarget'
  | 'targetOTP'
  | 'submitting'
  | 'completed'
  | 'failed'
  | 'comingSoon';

/**
 * 身份绑定/换绑状态机（Huawei 走 comingSoon，不进入 OTP）。
 */
export class AccountIdentityFlowState {
  phase: IdentityFlowPhase = 'idle';
  operation?: AccountIdentityOperation;
  reauthChannel?: AccountVerificationChannel;
  reauthOtpId: string = '';
  verificationTicket: string = '';
  targetOtpId: string = '';
  lockedPhone?: LockedPhoneTarget;
  lockedEmail: string = '';
  lockedEmailDisplay: string = '';
  errorMessage: string = '';

  static idle(): AccountIdentityFlowState {
    return new AccountIdentityFlowState();
  }

  isOverlayPresented(): boolean {
    return this.phase !== 'idle';
  }

  reset(): void {
    this.phase = 'idle';
    this.operation = undefined;
    this.reauthChannel = undefined;
    this.reauthOtpId = '';
    this.verificationTicket = '';
    this.targetOtpId = '';
    this.lockedPhone = undefined;
    this.lockedEmail = '';
    this.lockedEmailDisplay = '';
    this.errorMessage = '';
  }
}

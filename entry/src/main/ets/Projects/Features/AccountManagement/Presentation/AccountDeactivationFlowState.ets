import {
  AccountDeactivationSubmission,
  AccountDeactivationVerification,
  AccountVerificationChannel
} from '../Domain/AccountDeactivationModels';

export type DeactivationFlowPhase =
  | 'idle'
  | 'chooseVerification'
  | 'enteringOTP'
  | 'finalConfirmation'
  | 'submitting'
  | 'completed'
  | 'failed'
  | 'comingSoon';

export class AccountDeactivationFlowState {
  phase: DeactivationFlowPhase = 'idle';
  channel?: AccountVerificationChannel;
  otpId: string = '';
  verification?: AccountDeactivationVerification;
  submission?: AccountDeactivationSubmission;
  errorMessage: string = '';

  static idle(): AccountDeactivationFlowState {
    return new AccountDeactivationFlowState();
  }

  isOverlayPresented(): boolean {
    return this.phase !== 'idle' && this.phase !== 'completed';
  }

  reset(): void {
    this.phase = 'idle';
    this.channel = undefined;
    this.otpId = '';
    this.verification = undefined;
    this.submission = undefined;
    this.errorMessage = '';
  }
}

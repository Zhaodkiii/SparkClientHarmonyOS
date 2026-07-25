/** 登录页待续接动作（协议同意后执行）。 */
export type PendingLoginAction = 'none' | 'huawei' | 'phone' | 'device';

export type LegalDocumentType = 'terms' | 'privacy' | 'health' | 'permissions';

/**
 * 登录 UI 瞬时状态（不含 Token / OTP 明文长期存储）。
 */
export class AuthUiState {
  legalAccepted: boolean = false;
  legalAcceptedVersion: string = '';
  pendingAction: PendingLoginAction = 'none';
  busy: boolean = false;
  otpRequesting: boolean = false;
  errorText: string = '';
  showLegalPrompt: boolean = false;
  showRegionPicker: boolean = false;
  phoneLocalNumber: string = '';
  otpCode: string = '';
  otpId: string = '';
  otpCountdownSec: number = 0;

  static readonly LEGAL_VERSION: string = '2026.07.1';
}

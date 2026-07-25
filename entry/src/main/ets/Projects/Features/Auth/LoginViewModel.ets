import { AppContainer } from '../../../App/AppContainer';
import { AuthUiState, PendingLoginAction } from './AuthUiState';
import { PhoneRegion } from './PhoneRegion';
import { BackendErrorLocalizer } from '../../Core/Networking/BackendErrorLocalizer';
import { SupportNetworkError } from '../../Core/Networking/SupportNetworkModels';
import { ErrorLogger } from '../../../Foundation/Logging/ErrorLogger';
import { LogModule } from '../../../Foundation/Logging/LogModule';
import { UserSession } from '../../Core/Domain/Entities/UserSession';
import { OTPRequestResponse } from '../../Core/Networking/API/Auth/OTPAPI';

/**
 * 登录 UI 编排：协议门禁、游客/OTP UseCase、倒计时；不直连 HTTP。
 * 行为对齐 iOS LoginViewModel（华为账号占位替代 Apple）。
 */
export class LoginViewModel {
  readonly state: AuthUiState = new AuthUiState();
  selectedRegion: PhoneRegion = PhoneRegion.china();
  private countdownTimer?: number;
  private onChanged?: () => void;

  /** 对应 iOS isLoading */
  get isLoading(): boolean {
    return this.state.busy;
  }

  setOnChanged(cb: () => void): void {
    this.onChanged = cb;
  }

  private notify(): void {
    if (this.onChanged) {
      this.onChanged();
    }
  }

  async loadLegalAccepted(): Promise<void> {
    const container: AppContainer | undefined = AppContainer.shared();
    if (!container) {
      return;
    }
    this.state.legalAccepted = await container.legalStore.isAccepted();
    if (this.state.legalAccepted) {
      this.state.legalAcceptedVersion = AuthUiState.LEGAL_VERSION;
    }
    this.notify();
  }

  /**
   * 尝试发起登录入口动作；未同意协议则打开半屏并返回 false。
   */
  requestAction(action: PendingLoginAction): boolean {
    if (action === 'none') {
      return false;
    }
    if (!this.state.legalAccepted) {
      this.state.pendingAction = action;
      this.state.showLegalPrompt = true;
      this.notify();
      return false;
    }
    this.state.pendingAction = action;
    this.notify();
    return true;
  }

  dismissLegalPrompt(): void {
    this.state.showLegalPrompt = false;
    this.state.pendingAction = 'none';
    this.state.legalAccepted = false;
    this.state.legalAcceptedVersion = '';
    this.notify();
    const container: AppContainer | undefined = AppContainer.shared();
    if (container) {
      container.legalStore.revoke().catch(() => {
        // ignore
      });
    }
  }

  async acceptLegalAndContinue(): Promise<PendingLoginAction> {
    const container: AppContainer | undefined = AppContainer.shared();
    if (container) {
      await container.legalStore.accept();
    }
    this.state.legalAccepted = true;
    this.state.legalAcceptedVersion = AuthUiState.LEGAL_VERSION;
    this.state.showLegalPrompt = false;
    const action = this.state.pendingAction;
    this.notify();
    return action;
  }

  setLegalCheckbox(accepted: boolean): void {
    this.state.legalAccepted = accepted;
    this.notify();
    if (accepted) {
      const container: AppContainer | undefined = AppContainer.shared();
      if (container) {
        container.legalStore.accept().catch(() => {
          // ignore
        });
      }
    }
  }

  showComingSoon(): void {
    this.state.errorText = '即将支持';
    const container: AppContainer | undefined = AppContainer.shared();
    if (container) {
      container.notificationClient.info('即将支持', undefined, 'auth.coming_soon');
    }
    this.notify();
  }

  async signInWithDevice(): Promise<UserSession | undefined> {
    const container: AppContainer | undefined = AppContainer.shared();
    if (!container || this.state.busy) {
      return undefined;
    }
    this.state.busy = true;
    this.state.errorText = '';
    this.notify();
    try {
      const session: UserSession = await container.signInWithDevice.execute();
      container.sessionStore.enterSignedIn(session);
      return session;
    } catch (err) {
      ErrorLogger.log('auth.device_login_failed', LogModule.AUTH, err as Object);
      const text = this.mapError(err as Object);
      this.state.errorText = text;
      this.publishAuthError(text);
      return undefined;
    } finally {
      this.state.busy = false;
      this.state.pendingAction = 'none';
      this.notify();
    }
  }

  /**
   * 对应 iOS sendOTP(phoneNumber:isResend:)；入参可为本地号或已含区号号码。
   * 本地页仍优先走 requestOtp(localNumber)。
   */
  async sendOTP(phoneNumber: string, isResend: boolean = false): Promise<OTPRequestResponse | undefined> {
    const digits = phoneNumber.replace(/[^\d+]/g, '');
    let local = digits;
    const dial = this.selectedRegion.dialCode;
    if (digits.startsWith(`+${dial}`)) {
      local = digits.substring(dial.length + 1);
    } else if (digits.startsWith(dial) && digits.length > dial.length + 5) {
      local = digits.substring(dial.length);
    }
    if (isResend) {
      this.state.otpCountdownSec = 0;
    }
    return this.requestOtp(local);
  }

  /** 对应 iOS phoneLogin(phoneNumber:verificationCode:otpId:) */
  async phoneLogin(phoneNumber: string, verificationCode: string, otpId: string): Promise<UserSession | undefined> {
    if (otpId.length > 0) {
      this.state.otpId = otpId;
    }
    const digits = phoneNumber.replace(/[^\d+]/g, '');
    const dial = this.selectedRegion.dialCode;
    if (digits.startsWith(`+${dial}`)) {
      this.state.phoneLocalNumber = digits.substring(dial.length + 1).replace(/[^\d]/g, '');
    } else if (digits.startsWith(dial) && digits.length > dial.length + 5) {
      this.state.phoneLocalNumber = digits.substring(dial.length).replace(/[^\d]/g, '');
    } else {
      this.state.phoneLocalNumber = digits.replace(/[^\d]/g, '');
    }
    return this.verifyOtp(verificationCode);
  }

  async requestOtp(localNumber: string): Promise<OTPRequestResponse | undefined> {
    const container: AppContainer | undefined = AppContainer.shared();
    if (!container || this.state.busy || this.state.otpRequesting) {
      return undefined;
    }
    if (!PhoneRegion.isPhoneReady(localNumber)) {
      this.state.errorText = '请输入有效手机号';
      this.publishAuthWarning('请输入有效手机号');
      this.notify();
      return undefined;
    }
    this.state.busy = true;
    this.state.otpRequesting = true;
    this.state.errorText = '';
    this.state.phoneLocalNumber = localNumber.replace(/[^\d]/g, '');
    this.notify();
    try {
      const e164: string = this.selectedRegion.toE164(this.state.phoneLocalNumber);
      const resp: OTPRequestResponse = await container.requestPhoneOTP.execute(e164, 'login');
      this.state.otpId = resp.otpId;
      container.notificationClient.success('验证码已发送', undefined, 'auth.otp_sent');
      this.startCountdown(60);
      return resp;
    } catch (err) {
      ErrorLogger.log('auth.otp_request_failed', LogModule.AUTH, err as Object);
      const text = this.mapError(err as Object);
      this.state.errorText = text;
      this.publishAuthError(text);
      return undefined;
    } finally {
      this.state.otpRequesting = false;
      this.state.busy = false;
      this.notify();
    }
  }

  async resendOtp(): Promise<void> {
    if (this.state.otpCountdownSec > 0 || this.state.otpRequesting) {
      return;
    }
    await this.requestOtp(this.state.phoneLocalNumber);
  }

  async verifyOtp(code: string): Promise<UserSession | undefined> {
    const container: AppContainer | undefined = AppContainer.shared();
    if (!container || this.state.busy) {
      return undefined;
    }
    const digits = code.replace(/[^\d]/g, '');
    if (digits.length < 6) {
      this.state.errorText = '请输入 6 位验证码';
      this.publishAuthWarning('请输入 6 位验证码');
      this.notify();
      return undefined;
    }
    if (!this.state.otpId) {
      this.state.errorText = '请先获取验证码';
      this.publishAuthWarning('请先获取验证码');
      this.notify();
      return undefined;
    }
    this.state.busy = true;
    this.state.errorText = '';
    this.notify();
    try {
      const e164: string = this.selectedRegion.toE164(this.state.phoneLocalNumber);
      const session: UserSession = await container.signInWithPhoneOTP.execute(this.state.otpId, e164, digits);
      container.sessionStore.enterSignedIn(session);
      this.stopCountdown();
      return session;
    } catch (err) {
      ErrorLogger.log('auth.otp_verify_failed', LogModule.AUTH, err as Object);
      const text = this.mapError(err as Object);
      this.state.errorText = text;
      this.publishAuthError(text);
      return undefined;
    } finally {
      this.state.busy = false;
      this.notify();
    }
  }

  maskedPhone(): string {
    const d = this.state.phoneLocalNumber;
    if (d.length < 7) {
      return `+${this.selectedRegion.dialCode} ${d}`;
    }
    const head = d.substring(0, 3);
    const tail = d.substring(d.length - 4);
    return `+${this.selectedRegion.dialCode} ${head}****${tail}`;
  }

  startCountdown(seconds: number): void {
    this.stopCountdown();
    this.state.otpCountdownSec = seconds;
    this.notify();
    this.scheduleTick();
  }

  private scheduleTick(): void {
    this.countdownTimer = setTimeout(() => {
      if (this.state.otpCountdownSec <= 1) {
        this.state.otpCountdownSec = 0;
        this.countdownTimer = undefined;
        this.notify();
        return;
      }
      this.state.otpCountdownSec -= 1;
      this.notify();
      this.scheduleTick();
    }, 1000) as number;
  }

  stopCountdown(): void {
    if (this.countdownTimer !== undefined) {
      clearTimeout(this.countdownTimer);
      this.countdownTimer = undefined;
    }
  }

  dispose(): void {
    this.stopCountdown();
  }

  private mapError(err: Object): string {
    if (err instanceof SupportNetworkError) {
      return BackendErrorLocalizer.localize(err.backend, err.statusCode);
    }
    return BackendErrorLocalizer.unknown();
  }

  private publishAuthError(message: string): void {
    const container: AppContainer | undefined = AppContainer.shared();
    if (container) {
      container.notificationClient.error(message, undefined, 'auth.error');
    }
  }

  private publishAuthWarning(message: string): void {
    const container: AppContainer | undefined = AppContainer.shared();
    if (container) {
      container.notificationClient.warning(message, undefined, 'auth.warning');
    }
  }
}

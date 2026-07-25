import { AppContainer } from '../../../../App/AppContainer';
import { AppSessionStore } from '../../../../App/AppSessionStore';
import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { NotificationClient } from '../../../Core/Notification/Application/NotificationClient';
import { BackendErrorLocalizer } from '../../../Core/Networking/BackendErrorLocalizer';
import { SupportNetworkError } from '../../../Core/Networking/SupportNetworkModels';
import { ErrorLogger } from '../../../../Foundation/Logging/ErrorLogger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { PhoneRegion } from '../../Auth/PhoneRegion';
import { LoadAccountProfileUseCase } from '../Application/LoadAccountProfileUseCase';
import { LoadAccountIdentitiesUseCase } from '../Application/LoadAccountIdentitiesUseCase';
import { RequestIdentityVerificationUseCase } from '../Application/RequestIdentityVerificationUseCase';
import { VerifyIdentityVerificationUseCase } from '../Application/VerifyIdentityVerificationUseCase';
import { BindAccountIdentityUseCase } from '../Application/BindAccountIdentityUseCase';
import { ChangeAccountIdentityUseCase } from '../Application/ChangeAccountIdentityUseCase';
import { RequestTargetOTPUseCase } from '../Application/RequestTargetOTPUseCase';
import { RequestAccountVerificationUseCase } from '../Application/RequestAccountVerificationUseCase';
import { SubmitAccountDeactivationUseCase } from '../Application/SubmitAccountDeactivationUseCase';
import { SignOutUseCase } from '../../Auth/Application/SignOutUseCase';
import { AccountProfile } from '../Domain/AccountProfile';
import {
  AccountIdentityBindProof,
  AccountIdentityList,
  AccountIdentityOperation,
  AccountIdentityProvider,
  AccountIdentityProviders,
  AccountIdentityReauthProof,
  AccountIdentityStatus,
  LockedPhoneTarget
} from '../Domain/AccountIdentityModels';
import {
  AccountDeactivationOptions,
  AccountDeactivationVerification,
  AccountVerificationChannel
} from '../Domain/AccountDeactivationModels';
import { AccountManagementError } from '../Domain/AccountManagementError';
import { AccountIdentityFlowState } from './AccountIdentityFlowState';
import { AccountDeactivationFlowState } from './AccountDeactivationFlowState';

export class AccountManagementViewModel {
  profile?: AccountProfile;
  identityList?: AccountIdentityList;
  identityFlow: AccountIdentityFlowState = AccountIdentityFlowState.idle();
  deactivationFlow: AccountDeactivationFlowState = AccountDeactivationFlowState.idle();
  options: AccountDeactivationOptions = new AccountDeactivationOptions();
  isLoadingProfile: boolean = false;
  isLoadingIdentities: boolean = false;
  isSigningOut: boolean = false;
  isRequestingReauthOTP: boolean = false;
  isRequestingTargetOTP: boolean = false;
  isSubmittingIdentity: boolean = false;
  errorMessage: string = '';
  otpCode: string = '';
  identityReauthOTPCode: string = '';
  identityTargetOTPCode: string = '';
  identityTargetEmail: string = '';
  identityTargetPhoneLocal: string = '';
  identityTargetRegion: PhoneRegion = PhoneRegion.china();
  confirmationPhraseInput: string = '';
  showAdvancedOptions: boolean = false;
  identityResendCountdown: number = 0;
  deactivationResendCountdown: number = 0;

  private readonly loadProfile: LoadAccountProfileUseCase;
  private readonly loadIdentities: LoadAccountIdentitiesUseCase;
  private readonly requestIdentityVerification: RequestIdentityVerificationUseCase;
  private readonly verifyIdentityVerification: VerifyIdentityVerificationUseCase;
  private readonly bindIdentity: BindAccountIdentityUseCase;
  private readonly changeIdentity: ChangeAccountIdentityUseCase;
  private readonly requestTargetOTP: RequestTargetOTPUseCase;
  private readonly requestAccountVerification: RequestAccountVerificationUseCase;
  private readonly submitDeactivation: SubmitAccountDeactivationUseCase;
  private readonly signOutUseCase: SignOutUseCase;
  private readonly sessionStore: AppSessionStore;
  private readonly notification: NotificationClient;
  private onChanged?: () => void;
  private loadGeneration: number = 0;
  private identityCountdownTimer?: number;
  private deactivationCountdownTimer?: number;
  private onLocalNavClear?: () => void;

  constructor(
    loadProfile: LoadAccountProfileUseCase,
    loadIdentities: LoadAccountIdentitiesUseCase,
    requestIdentityVerification: RequestIdentityVerificationUseCase,
    verifyIdentityVerification: VerifyIdentityVerificationUseCase,
    bindIdentity: BindAccountIdentityUseCase,
    changeIdentity: ChangeAccountIdentityUseCase,
    requestTargetOTP: RequestTargetOTPUseCase,
    requestAccountVerification: RequestAccountVerificationUseCase,
    submitDeactivation: SubmitAccountDeactivationUseCase,
    signOutUseCase: SignOutUseCase,
    sessionStore: AppSessionStore,
    notification: NotificationClient
  ) {
    this.loadProfile = loadProfile;
    this.loadIdentities = loadIdentities;
    this.requestIdentityVerification = requestIdentityVerification;
    this.verifyIdentityVerification = verifyIdentityVerification;
    this.bindIdentity = bindIdentity;
    this.changeIdentity = changeIdentity;
    this.requestTargetOTP = requestTargetOTP;
    this.requestAccountVerification = requestAccountVerification;
    this.submitDeactivation = submitDeactivation;
    this.signOutUseCase = signOutUseCase;
    this.sessionStore = sessionStore;
    this.notification = notification;
  }

  setOnChanged(cb: () => void): void {
    this.onChanged = cb;
  }

  setOnLocalNavClear(cb: () => void): void {
    this.onLocalNavClear = cb;
  }

  private notify(): void {
    if (this.onChanged) {
      this.onChanged();
    }
  }

  private currentSession(): UserSession | undefined {
    return this.sessionStore.session;
  }

  requiredConfirmationPhrase(): string {
    return '删除我的账户';
  }

  confirmationMatches(): boolean {
    const input = this.confirmationPhraseInput.trim();
    return input === '删除我的账户' || input === 'Delete my account';
  }

  async load(): Promise<void> {
    const session = this.currentSession();
    const gen = this.sessionStore.generation;
    this.loadGeneration = gen;
    this.isLoadingProfile = true;
    this.isLoadingIdentities = true;
    this.errorMessage = '';
    const startedAt = Date.now();
    const startFields = new LogFields();
    startFields.operation = 'account.load';
    startFields.detail =
      `gen=${gen} hasSession=${session !== undefined} accountId=${session !== undefined ? session.accountId : -1}`;
    Logger.info('account.load.start', LogModule.AUTH, startFields);
    this.notify();
    try {
      const profile = await this.loadProfile.execute(session);
      if (gen !== this.sessionStore.generation || gen !== this.loadGeneration) {
        const stale = new LogFields();
        stale.operation = 'account.load';
        stale.detail = `phase=after_profile gen=${gen} storeGen=${this.sessionStore.generation} loadGen=${this.loadGeneration}`;
        Logger.warn('account.load.stale', LogModule.AUTH, stale);
        return;
      }
      this.profile = profile;
      this.isLoadingProfile = false;
      const profileFields = new LogFields();
      profileFields.operation = 'account.load';
      profileFields.elapsedMs = Date.now() - startedAt;
      profileFields.detail = `signInMethod=${profile.signInMethod}`;
      Logger.info('account.load.profile_ok', LogModule.AUTH, profileFields);
      this.notify();

      const beginIdentities = new LogFields();
      beginIdentities.operation = 'account.load';
      beginIdentities.detail = `gen=${gen}`;
      Logger.info('account.load.identities_begin', LogModule.AUTH, beginIdentities);
      const identities = await this.loadIdentities.execute(session);
      if (gen !== this.sessionStore.generation || gen !== this.loadGeneration) {
        const stale = new LogFields();
        stale.operation = 'account.load';
        stale.detail = `phase=after_identities gen=${gen} storeGen=${this.sessionStore.generation} loadGen=${this.loadGeneration}`;
        Logger.warn('account.load.stale', LogModule.AUTH, stale);
        return;
      }
      this.identityList = identities;
      const okFields = new LogFields();
      okFields.operation = 'account.load';
      okFields.elapsedMs = Date.now() - startedAt;
      okFields.detail =
        `count=${identities.identities.length} scope=${identities.identityScope} providers=${AccountManagementViewModel.identityProvidersSummary(identities)}`;
      Logger.info('account.load.identities_ok', LogModule.AUTH, okFields);
    } catch (err) {
      if (gen !== this.sessionStore.generation || gen !== this.loadGeneration) {
        const stale = new LogFields();
        stale.operation = 'account.load';
        stale.detail = `phase=catch gen=${gen} storeGen=${this.sessionStore.generation} loadGen=${this.loadGeneration}`;
        Logger.warn('account.load.stale', LogModule.AUTH, stale);
        return;
      }
      this.errorMessage = this.localizeError(err as Object);
      ErrorLogger.log('account.load.failed', LogModule.AUTH, err as Object);
      this.notification.error(this.errorMessage, undefined, 'account.load');
    } finally {
      // 与 iOS defer 对齐：本轮 load 结束必须收尾 loading，避免 generation 提前 return 后永久卡在「正在加载」
      if (gen === this.loadGeneration) {
        this.isLoadingProfile = false;
        this.isLoadingIdentities = false;
        const done = new LogFields();
        done.operation = 'account.load';
        done.elapsedMs = Date.now() - startedAt;
        done.detail =
          `hasProfile=${this.profile !== undefined} hasList=${this.identityList !== undefined} listCount=${this.identityList !== undefined ? this.identityList.identities.length : -1} error=${this.errorMessage.length > 0}`;
        Logger.info('account.load.finished', LogModule.AUTH, done);
        this.notify();
      } else {
        const skip = new LogFields();
        skip.operation = 'account.load';
        skip.detail = `finally_skipped gen=${gen} loadGen=${this.loadGeneration}`;
        Logger.info('account.load.finished_skipped', LogModule.AUTH, skip);
      }
    }
  }

  private static identityProvidersSummary(list: AccountIdentityList): string {
    const parts: string[] = [];
    for (let i = 0; i < list.identities.length; i++) {
      const item = list.identities[i];
      parts.push(`${item.provider}:${item.bound ? 'bound' : 'unbound'}`);
    }
    return parts.join(',');
  }

  availableDeactivationChannels(): AccountVerificationChannel[] {
    const channels: AccountVerificationChannel[] = [];
    const profile = this.profile;
    if (!profile) {
      return channels;
    }
    if (profile.signInMethod === 'phone' && profile.contact.length > 0) {
      channels.push(AccountVerificationChannel.phone(profile.contact));
    } else if (profile.signInMethod === 'email' && profile.contact.length > 0) {
      channels.push(AccountVerificationChannel.email(profile.contact));
    } else if (profile.signInMethod === 'huawei') {
      channels.push(AccountVerificationChannel.huawei());
    }
    // 身份列表中已绑定的 phone/email 也可作验证（完整值缺失时仅展示 ComingSoon / 用 contact）
    if (channels.length === 0 && profile.email !== undefined) {
      channels.push(AccountVerificationChannel.email(profile.email));
    }
    return channels;
  }

  availableReauthChannels(): AccountVerificationChannel[] {
    const channels: AccountVerificationChannel[] = [];
    const list = this.identityList;
    if (!list) {
      return channels;
    }
    for (let i = 0; i < list.identities.length; i++) {
      const status = list.identities[i];
      if (!status.bound) {
        continue;
      }
      if (status.provider === 'phone') {
        // 再验证发码走 identity-verification/request，无需完整号码；display 用脱敏
        channels.push(AccountVerificationChannel.phone('', status.maskedValue));
      } else if (status.provider === 'email') {
        channels.push(AccountVerificationChannel.email('', status.maskedValue));
      } else if (status.provider === 'huawei') {
        channels.push(AccountVerificationChannel.huawei());
      }
    }
    return channels;
  }

  beginBind(provider: AccountIdentityProvider): void {
    if (AccountIdentityProviders.isComingSoon(provider)) {
      this.notification.info('即将支持', undefined, 'account.huawei');
      this.identityFlow.reset();
      this.identityFlow.phase = 'comingSoon';
      this.identityFlow.operation = AccountIdentityOperation.bind(provider);
      this.notify();
      return;
    }
    this.clearIdentityInputs();
    this.identityFlow.reset();
    this.identityFlow.phase = 'choosingReauth';
    this.identityFlow.operation = AccountIdentityOperation.bind(provider);
    this.notify();
  }

  beginChange(provider: AccountIdentityProvider): void {
    if (AccountIdentityProviders.isComingSoon(provider)) {
      this.notification.info('即将支持', undefined, 'account.huawei');
      this.identityFlow.reset();
      this.identityFlow.phase = 'comingSoon';
      this.identityFlow.operation = AccountIdentityOperation.change(provider);
      this.notify();
      return;
    }
    this.clearIdentityInputs();
    this.identityFlow.reset();
    this.identityFlow.phase = 'choosingReauth';
    this.identityFlow.operation = AccountIdentityOperation.change(provider);
    this.notify();
  }

  cancelIdentityFlow(): void {
    this.stopIdentityCountdown();
    this.clearIdentityInputs();
    this.identityFlow.reset();
    this.notify();
  }

  dismissIdentityComingSoon(): void {
    this.cancelIdentityFlow();
  }

  async selectReauthChannel(channel: AccountVerificationChannel): Promise<void> {
    const op = this.identityFlow.operation;
    if (!op || this.isRequestingReauthOTP) {
      return;
    }
    if (channel.kind === 'huawei') {
      this.notification.info('即将支持', undefined, 'account.huawei');
      return;
    }
    const provider = channel.kind as AccountIdentityProvider;
    this.isRequestingReauthOTP = true;
    this.errorMessage = '';
    this.notify();
    try {
      const result = await this.requestIdentityVerification.execute(
        provider,
        op.purpose,
        this.currentSession()
      );
      if (result.kind === 'huaweiReady') {
        this.notification.info('即将支持', undefined, 'account.huawei');
        return;
      }
      this.identityFlow.phase = 'reauthOTP';
      this.identityFlow.reauthChannel = channel;
      this.identityFlow.reauthOtpId = result.otpId;
      this.identityReauthOTPCode = '';
      this.startIdentityCountdown(result.expiresIn > 0 ? Math.min(result.expiresIn, 60) : 60);
    } catch (err) {
      this.handleIdentityError(err as Object);
    } finally {
      this.isRequestingReauthOTP = false;
      this.notify();
    }
  }

  async submitReauthOTP(): Promise<void> {
    const op = this.identityFlow.operation;
    const channel = this.identityFlow.reauthChannel;
    if (!op || !channel || this.identityReauthOTPCode.length < 6 || this.isSubmittingIdentity) {
      return;
    }
    const provider = channel.kind as AccountIdentityProvider;
    let proof: AccountIdentityReauthProof;
    if (provider === 'phone') {
      proof = AccountIdentityReauthProof.phone(this.identityFlow.reauthOtpId, this.identityReauthOTPCode);
    } else {
      proof = AccountIdentityReauthProof.email(this.identityFlow.reauthOtpId, this.identityReauthOTPCode);
    }
    this.isSubmittingIdentity = true;
    this.notify();
    try {
      const ticket = await this.verifyIdentityVerification.execute(
        provider,
        op.purpose,
        proof,
        this.currentSession()
      );
      this.identityFlow.verificationTicket = ticket.ticket;
      this.identityFlow.phase = 'enteringTarget';
      this.identityReauthOTPCode = '';
      this.stopIdentityCountdown();
    } catch (err) {
      this.handleIdentityError(err as Object);
    } finally {
      this.isSubmittingIdentity = false;
      this.notify();
    }
  }

  canRequestTargetOTP(): boolean {
    if (this.isRequestingTargetOTP) {
      return false;
    }
    if (this.identityFlow.phase !== 'enteringTarget' || !this.identityFlow.operation) {
      return false;
    }
    const provider = this.identityFlow.operation.provider;
    if (provider === 'phone') {
      return PhoneRegion.isPhoneReady(this.identityTargetPhoneLocal);
    }
    if (provider === 'email') {
      return this.identityTargetEmail.indexOf('@') > 0;
    }
    return false;
  }

  async requestIdentityTargetOTP(): Promise<void> {
    const op = this.identityFlow.operation;
    if (!op || !this.canRequestTargetOTP()) {
      return;
    }
    let target = '';
    let lockedPhone: LockedPhoneTarget | undefined = undefined;
    let lockedEmail = '';
    if (op.provider === 'phone') {
      const e164 = this.identityTargetRegion.toE164(this.identityTargetPhoneLocal);
      lockedPhone = new LockedPhoneTarget(
        `+${this.identityTargetRegion.dialCode}`,
        this.identityTargetPhoneLocal.replace(/[^\d]/g, ''),
        e164
      );
      target = e164;
    } else {
      lockedEmail = this.identityTargetEmail.trim().toLowerCase();
      target = lockedEmail;
    }
    this.isRequestingTargetOTP = true;
    this.notify();
    try {
      const ctx = await this.requestTargetOTP.execute(op.provider, target, op, this.currentSession());
      this.identityFlow.phase = 'targetOTP';
      this.identityFlow.targetOtpId = ctx.otpId;
      this.identityFlow.lockedPhone = lockedPhone;
      this.identityFlow.lockedEmail = lockedEmail;
      this.identityFlow.lockedEmailDisplay = lockedEmail;
      this.identityTargetOTPCode = '';
      this.startIdentityCountdown(ctx.expiresIn > 0 ? Math.min(ctx.expiresIn, 60) : 60);
    } catch (err) {
      this.handleIdentityError(err as Object);
    } finally {
      this.isRequestingTargetOTP = false;
      this.notify();
    }
  }

  async submitIdentityTargetOTP(): Promise<void> {
    const op = this.identityFlow.operation;
    const ticket = this.identityFlow.verificationTicket;
    if (!op || ticket.length === 0 || this.identityTargetOTPCode.length < 6 || this.isSubmittingIdentity) {
      return;
    }
    this.isSubmittingIdentity = true;
    this.identityFlow.phase = 'submitting';
    this.notify();
    try {
      let list: AccountIdentityList;
      if (op.purpose === 'bind_identity') {
        let proof: AccountIdentityBindProof;
        if (op.provider === 'phone' && this.identityFlow.lockedPhone) {
          proof = AccountIdentityBindProof.phone(
            this.identityFlow.lockedPhone.e164,
            this.identityFlow.targetOtpId,
            this.identityTargetOTPCode
          );
        } else {
          proof = AccountIdentityBindProof.email(
            this.identityFlow.lockedEmail,
            this.identityFlow.targetOtpId,
            this.identityTargetOTPCode
          );
        }
        list = await this.bindIdentity.execute(op.provider, ticket, proof, this.currentSession());
      } else {
        const newTarget =
          op.provider === 'phone' && this.identityFlow.lockedPhone
            ? this.identityFlow.lockedPhone.e164
            : this.identityFlow.lockedEmail;
        list = await this.changeIdentity.execute(
          op.provider,
          ticket,
          newTarget,
          this.identityFlow.targetOtpId,
          this.identityTargetOTPCode,
          this.currentSession()
        );
      }
      this.identityList = list;
      this.identityFlow.phase = 'completed';
      this.notification.success(
        op.purpose === 'bind_identity' ? '绑定成功' : '修改成功',
        undefined,
        'account.identity'
      );
      this.stopIdentityCountdown();
      this.clearIdentityInputs();
    } catch (err) {
      this.identityFlow.phase = 'failed';
      this.identityFlow.errorMessage = this.localizeError(err as Object);
      this.notification.error(this.identityFlow.errorMessage, undefined, 'account.identity');
    } finally {
      this.isSubmittingIdentity = false;
      this.notify();
    }
  }

  beginDeactivation(): void {
    this.otpCode = '';
    this.confirmationPhraseInput = '';
    this.deactivationFlow.reset();
    this.deactivationFlow.phase = 'chooseVerification';
    const fields = new LogFields();
    fields.operation = 'account.deactivation';
    fields.detail = `phase=${this.deactivationFlow.phase} channels=${this.availableDeactivationChannels().length}`;
    Logger.info('account.deactivation.begin', LogModule.AUTH, fields);
    this.notify();
  }

  cancelDeactivation(): void {
    this.stopDeactivationCountdown();
    this.otpCode = '';
    this.confirmationPhraseInput = '';
    this.deactivationFlow.reset();
    this.notify();
  }

  async selectDeactivationChannel(channel: AccountVerificationChannel): Promise<void> {
    if (channel.kind === 'huawei') {
      this.notification.info('即将支持', undefined, 'account.huawei');
      this.deactivationFlow.phase = 'comingSoon';
      this.notify();
      return;
    }
    try {
      const ctx = await this.requestAccountVerification.execute(channel, this.currentSession());
      this.deactivationFlow.phase = 'enteringOTP';
      this.deactivationFlow.channel = channel;
      this.deactivationFlow.otpId = ctx.otpId;
      this.otpCode = '';
      this.startDeactivationCountdown(ctx.expiresIn > 0 ? Math.min(ctx.expiresIn, 60) : 60);
    } catch (err) {
      const msg = this.localizeError(err as Object);
      this.deactivationFlow.phase = 'failed';
      this.deactivationFlow.errorMessage = msg;
      this.notification.error(msg, undefined, 'account.deactivation');
    }
    this.notify();
  }

  proceedDeactivationOTP(): void {
    const channel = this.deactivationFlow.channel;
    if (!channel || this.otpCode.length < 6) {
      return;
    }
    let verification: AccountDeactivationVerification;
    if (channel.kind === 'phone') {
      verification = AccountDeactivationVerification.phone(this.deactivationFlow.otpId, this.otpCode);
    } else {
      verification = AccountDeactivationVerification.email(this.deactivationFlow.otpId, this.otpCode);
    }
    this.deactivationFlow.verification = verification;
    this.deactivationFlow.phase = 'finalConfirmation';
    this.confirmationPhraseInput = '';
    this.stopDeactivationCountdown();
    this.notify();
  }

  async confirmDeactivation(): Promise<void> {
    const verification = this.deactivationFlow.verification;
    if (!verification || !this.confirmationMatches() || this.deactivationFlow.phase === 'submitting') {
      return;
    }
    this.deactivationFlow.phase = 'submitting';
    this.notify();
    try {
      const submission = await this.submitDeactivation.execute(
        this.options,
        verification,
        this.currentSession()
      );
      this.deactivationFlow.submission = submission;
      this.deactivationFlow.phase = 'completed';
      this.notification.success('账号已注销', undefined, 'account.deactivation');
      await this.forceLocalSignOut();
    } catch (err) {
      this.deactivationFlow.phase = 'failed';
      this.deactivationFlow.errorMessage = this.localizeError(err as Object);
      this.notification.error(this.deactivationFlow.errorMessage, undefined, 'account.deactivation');
      this.notify();
    }
  }

  async confirmSignOut(): Promise<void> {
    if (this.isSigningOut) {
      return;
    }
    this.isSigningOut = true;
    this.notify();
    try {
      await this.signOutUseCase.execute();
    } catch (err) {
      ErrorLogger.log('auth.logout_failed', LogModule.AUTH, err as Object);
      this.notification.error(this.localizeError(err as Object), undefined, 'account.sign_out');
    } finally {
      await this.forceLocalSignOut();
      this.isSigningOut = false;
      this.notify();
    }
  }

  private async forceLocalSignOut(): Promise<void> {
    if (this.onLocalNavClear) {
      this.onLocalNavClear();
    }
    const container = AppContainer.shared();
    container?.lifecycle.onLocalSignOut();
    this.sessionStore.signOut();
  }

  private clearIdentityInputs(): void {
    this.identityReauthOTPCode = '';
    this.identityTargetOTPCode = '';
    this.identityTargetEmail = '';
    this.identityTargetPhoneLocal = '';
    this.identityTargetRegion = PhoneRegion.china();
  }

  private handleIdentityError(err: Object | Error | string): void {
    const msg = this.localizeError(err as Object);
    if (err instanceof AccountManagementError && err.kind === 'huaweiComingSoon') {
      this.notification.info('即将支持', undefined, 'account.huawei');
      return;
    }
    this.identityFlow.phase = 'failed';
    this.identityFlow.errorMessage = msg;
    this.notification.error(msg, undefined, 'account.identity');
  }

  private localizeError(err: Object | Error | string): string {
    if (err instanceof AccountManagementError) {
      return err.message;
    }
    if (err instanceof SupportNetworkError) {
      return BackendErrorLocalizer.localize(err.backend, err.statusCode);
    }
    if (err instanceof Error) {
      return err.message;
    }
    if (typeof err === 'string') {
      return err;
    }
    return BackendErrorLocalizer.unknown();
  }

  private startIdentityCountdown(seconds: number): void {
    this.stopIdentityCountdown();
    this.identityResendCountdown = seconds;
    this.identityCountdownTimer = setInterval(() => {
      if (this.identityResendCountdown <= 1) {
        this.identityResendCountdown = 0;
        this.stopIdentityCountdown();
      } else {
        this.identityResendCountdown -= 1;
      }
      this.notify();
    }, 1000) as number;
  }

  private stopIdentityCountdown(): void {
    if (this.identityCountdownTimer !== undefined) {
      clearInterval(this.identityCountdownTimer);
      this.identityCountdownTimer = undefined;
    }
    this.identityResendCountdown = 0;
  }

  private startDeactivationCountdown(seconds: number): void {
    this.stopDeactivationCountdown();
    this.deactivationResendCountdown = seconds;
    this.deactivationCountdownTimer = setInterval(() => {
      if (this.deactivationResendCountdown <= 1) {
        this.deactivationResendCountdown = 0;
        this.stopDeactivationCountdown();
      } else {
        this.deactivationResendCountdown -= 1;
      }
      this.notify();
    }, 1000) as number;
  }

  private stopDeactivationCountdown(): void {
    if (this.deactivationCountdownTimer !== undefined) {
      clearInterval(this.deactivationCountdownTimer);
      this.deactivationCountdownTimer = undefined;
    }
    this.deactivationResendCountdown = 0;
  }

  identityStatusTitle(status: AccountIdentityStatus): string {
    return AccountIdentityProviders.title(status.provider);
  }
}

import { SupportBackend } from '../../../../Core/Networking/SupportBackend';
import { DeviceCredentialStore } from '../../../../Foundation/Security/DeviceCredentialStore';
import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { PhoneOTPRequest, EmailOTPRequest } from '../../../Core/Networking/API/Auth/OTPAPI';
import {
  IdentityVerificationRequestBody,
  VerifyIdentityRequest,
  BindIdentityRequest,
  ChangeIdentityRequest,
  IdentityListResult
} from '../../../Core/Networking/API/Account/AccountIdentityAPI';
import {
  DeactivationRequest,
  DeactivationVerificationPayload
} from '../../../Core/Networking/API/Account/DeactivationAPI';
import { AccountManagementRepository } from '../Domain/AccountManagementRepository';
import { AccountProfile } from '../Domain/AccountProfile';
import { AccountManagementError } from '../Domain/AccountManagementError';
import {
  AccountIdentityBindProof,
  AccountIdentityList,
  AccountIdentityOperation,
  AccountIdentityProvider,
  AccountIdentityProviders,
  AccountIdentityReauthProof,
  AccountIdentityStatus,
  AccountVerificationRequestContext,
  IdentityVerificationRequestResult,
  VerificationTicket
} from '../Domain/AccountIdentityModels';
import {
  AccountDeactivationOptions,
  AccountDeactivationSubmission,
  AccountDeactivationVerification,
  AccountVerificationChannel
} from '../Domain/AccountDeactivationModels';
import { ErrorLogger } from '../../../../Foundation/Logging/ErrorLogger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { LogLevel } from '../../../../Foundation/Logging/LogLevel';

function mapIdentityList(dto: IdentityListResult): AccountIdentityList {
  const identities: AccountIdentityStatus[] = [];
  for (let i = 0; i < dto.identities.length; i++) {
    const item = dto.identities[i];
    const provider = AccountIdentityProviders.parse(item.provider);
    if (provider === undefined) {
      continue;
    }
    identities.push(
      new AccountIdentityStatus(provider, item.bound, item.maskedValue, item.modifiable, item.bindable)
    );
  }
  return new AccountIdentityList(dto.accountId, dto.bundleId, dto.identityScope, identities);
}

function fallbackIdentityList(session: UserSession, bundleId: string = ''): AccountIdentityList {
  const identities: AccountIdentityStatus[] = [];
  const method = AccountIdentityProviders.parse(session.signInMethod);
  const contact = session.email.length > 0 ? session.email : session.displayName;
  if (method !== undefined && method !== 'huawei') {
    identities.push(new AccountIdentityStatus(method, true, maskTarget(contact), true, false));
  } else if (method === 'huawei') {
    identities.push(new AccountIdentityStatus('huawei', true, 'Huawei 账号', false, false));
  }
  for (let i = 0; i < AccountIdentityProviders.ALL.length; i++) {
    const provider = AccountIdentityProviders.ALL[i];
    let exists = false;
    for (let j = 0; j < identities.length; j++) {
      if (identities[j].provider === provider) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      identities.push(new AccountIdentityStatus(provider, false, '', false, provider !== 'huawei'));
    }
  }
  return new AccountIdentityList(session.accountId, bundleId, 'session_fallback', identities);
}

function maskTarget(raw: string): string {
  const value = raw.trim();
  if (value.indexOf('@') >= 0) {
    const at = value.indexOf('@');
    const local = value.substring(0, at);
    const domain = value.substring(at);
    if (local.length <= 2) {
      return `*${domain}`;
    }
    return `${local.substring(0, 1)}***${local.substring(local.length - 1)}${domain}`;
  }
  if (value.length <= 4) {
    return '****';
  }
  return `${value.substring(0, 3)}****${value.substring(value.length - 2)}`;
}

export class DefaultAccountManagementRepository extends AccountManagementRepository {
  private readonly backend: SupportBackend;
  private readonly credentials: DeviceCredentialStore;

  constructor(backend: SupportBackend, credentials: DeviceCredentialStore) {
    super();
    this.backend = backend;
    this.credentials = credentials;
  }

  async loadAccountProfile(session: UserSession | undefined): Promise<AccountProfile> {
    if (session === undefined) {
      throw AccountManagementError.missingSession();
    }
    return AccountProfile.fromSession(session);
  }

  async loadIdentities(session: UserSession | undefined): Promise<AccountIdentityList> {
    if (session === undefined) {
      throw AccountManagementError.missingSession();
    }
    const startedAt = Date.now();
    const begin = new LogFields();
    begin.operation = 'listIdentities';
    begin.detail = `accountId=${session.accountId}`;
    Logger.info('account.identities.fetch_begin', LogModule.AUTH, begin);

    let bundleId = '';
    try {
      const cred = await this.credentials.getOrCreate();
      bundleId = cred.bundleId;
      const credFields = new LogFields();
      credFields.operation = 'listIdentities';
      credFields.elapsedMs = Date.now() - startedAt;
      credFields.detail = `bundleId=${bundleId} deviceIdLen=${cred.deviceId.length}`;
      Logger.info('account.identities.credentials_ok', LogModule.AUTH, credFields);

      const apiBegin = new LogFields();
      apiBegin.operation = 'listIdentities';
      apiBegin.route = '/api/v1/accounts/identities/';
      apiBegin.detail = `bundleId=${bundleId}`;
      Logger.info('account.identities.api_begin', LogModule.AUTH, apiBegin);
      const dto = await this.backend.accountIdentity.listIdentities(bundleId);
      const mapped = mapIdentityList(dto);
      const ok = new LogFields();
      ok.operation = 'listIdentities';
      ok.elapsedMs = Date.now() - startedAt;
      ok.detail =
        `rawCount=${dto.identities.length} mappedCount=${mapped.identities.length} scope=${mapped.identityScope} accountId=${mapped.accountId}`;
      Logger.info('account.identities.fetch_ok', LogModule.AUTH, ok);
      if (mapped.identities.length > 0) {
        return mapped;
      }
      const empty = new LogFields();
      empty.operation = 'listIdentities';
      empty.detail = 'mapped_empty_use_fallback';
      Logger.warn('account.identities.fallback_empty', LogModule.AUTH, empty);
      return fallbackIdentityList(session, bundleId);
    } catch (err) {
      const errFields = new LogFields();
      errFields.operation = 'listIdentities';
      errFields.elapsedMs = Date.now() - startedAt;
      errFields.detail = `use_fallback bundleId=${bundleId}`;
      ErrorLogger.log('account.identities.fetch_error', LogModule.AUTH, err as Object, LogLevel.WARN, errFields);
      return fallbackIdentityList(session, bundleId);
    }
  }

  async requestIdentityVerification(
    provider: AccountIdentityProvider,
    purpose: string,
    session: UserSession | undefined
  ): Promise<IdentityVerificationRequestResult> {
    if (session === undefined) {
      throw AccountManagementError.missingSession();
    }
    if (AccountIdentityProviders.isComingSoon(provider)) {
      throw AccountManagementError.huaweiComingSoon();
    }
    const cred = await this.credentials.getOrCreate();
    const body = new IdentityVerificationRequestBody(provider, purpose, cred.bundleId, cred.deviceId);
    const result = await this.backend.accountIdentity.requestVerification(body);
    if (result.ready === true) {
      return IdentityVerificationRequestResult.huaweiReady();
    }
    if (result.otpId === undefined) {
      throw AccountManagementError.unsupportedChannel();
    }
    return IdentityVerificationRequestResult.otp(result.otpId, result.expiresIn ?? 300);
  }

  async verifyIdentityVerification(
    provider: AccountIdentityProvider,
    purpose: string,
    proof: AccountIdentityReauthProof,
    session: UserSession | undefined
  ): Promise<VerificationTicket> {
    if (session === undefined) {
      throw AccountManagementError.missingSession();
    }
    if (AccountIdentityProviders.isComingSoon(provider)) {
      throw AccountManagementError.huaweiComingSoon();
    }
    const cred = await this.credentials.getOrCreate();
    let body: VerifyIdentityRequest;
    if (proof.kind === 'phone') {
      body = VerifyIdentityRequest.phoneOtp(purpose, proof.otpId, proof.code, cred.bundleId, cred.deviceId);
    } else if (proof.kind === 'email') {
      body = VerifyIdentityRequest.emailOtp(purpose, proof.otpId, proof.code, cred.bundleId, cred.deviceId);
    } else {
      throw AccountManagementError.missingProof();
    }
    const result = await this.backend.accountIdentity.verifyAndIssueTicket(body);
    return new VerificationTicket(result.verificationTicket, result.expiresIn);
  }

  async requestTargetOTP(
    provider: AccountIdentityProvider,
    target: string,
    operation: AccountIdentityOperation,
    session: UserSession | undefined
  ): Promise<AccountVerificationRequestContext> {
    if (session === undefined) {
      throw AccountManagementError.missingSession();
    }
    if (AccountIdentityProviders.isComingSoon(provider)) {
      throw AccountManagementError.huaweiComingSoon();
    }
    const cred = await this.credentials.getOrCreate();
    const scene = operation.targetOtpScene();
    if (provider === 'phone') {
      const result = await this.backend.otp.requestPhoneOTP(
        new PhoneOTPRequest(target, cred.bundleId, cred.deviceId, scene, '', session.accountId)
      );
      return new AccountVerificationRequestContext('phone', maskTarget(target), result.otpId, result.expiresIn ?? 300);
    }
    if (provider === 'email') {
      const result = await this.backend.otp.requestEmailOTP(
        new EmailOTPRequest(target, cred.bundleId, cred.deviceId, scene)
      );
      return new AccountVerificationRequestContext('email', maskTarget(target), result.otpId, result.expiresIn ?? 300);
    }
    throw AccountManagementError.unsupportedChannel();
  }

  async bindIdentity(
    provider: AccountIdentityProvider,
    verificationTicket: string,
    proof: AccountIdentityBindProof,
    session: UserSession | undefined
  ): Promise<AccountIdentityList> {
    if (session === undefined) {
      throw AccountManagementError.missingSession();
    }
    if (AccountIdentityProviders.isComingSoon(provider)) {
      throw AccountManagementError.huaweiComingSoon();
    }
    const cred = await this.credentials.getOrCreate();
    let body: BindIdentityRequest;
    if (proof.kind === 'phone') {
      body = BindIdentityRequest.phone(
        verificationTicket,
        proof.target,
        proof.otpId,
        proof.code,
        cred.bundleId,
        cred.deviceId
      );
    } else if (proof.kind === 'email') {
      body = BindIdentityRequest.email(
        verificationTicket,
        proof.target,
        proof.otpId,
        proof.code,
        cred.bundleId,
        cred.deviceId
      );
    } else {
      throw AccountManagementError.missingProof();
    }
    const dto = await this.backend.accountIdentity.bindIdentity(body);
    return mapIdentityList(dto);
  }

  async changeIdentity(
    provider: AccountIdentityProvider,
    verificationTicket: string,
    newTarget: string,
    newOtpId: string,
    newCode: string,
    session: UserSession | undefined
  ): Promise<AccountIdentityList> {
    if (session === undefined) {
      throw AccountManagementError.missingSession();
    }
    if (AccountIdentityProviders.isComingSoon(provider)) {
      throw AccountManagementError.huaweiComingSoon();
    }
    const cred = await this.credentials.getOrCreate();
    const body = new ChangeIdentityRequest(
      provider,
      verificationTicket,
      newTarget,
      newOtpId,
      newCode,
      cred.bundleId,
      cred.deviceId
    );
    const dto = await this.backend.accountIdentity.changeIdentity(body);
    return mapIdentityList(dto);
  }

  async requestDeactivationVerification(
    channel: AccountVerificationChannel,
    session: UserSession | undefined
  ): Promise<AccountVerificationRequestContext> {
    if (session === undefined) {
      throw AccountManagementError.missingSession();
    }
    if (channel.kind === 'huawei') {
      throw AccountManagementError.huaweiComingSoon();
    }
    const cred = await this.credentials.getOrCreate();
    const target = channel.fullTarget;
    if (target.length === 0) {
      throw AccountManagementError.unsupportedChannel();
    }
    if (channel.kind === 'phone') {
      const result = await this.backend.otp.requestPhoneOTP(
        new PhoneOTPRequest(target, cred.bundleId, cred.deviceId, 'account_deactivation', '', session.accountId)
      );
      return new AccountVerificationRequestContext(
        'phone',
        channel.displayMasked.length > 0 ? channel.displayMasked : maskTarget(target),
        result.otpId,
        result.expiresIn ?? 300
      );
    }
    if (channel.kind === 'email') {
      // 对齐 iOS 消费事实：邮箱注销 scene = login（R5 暂不改）
      const result = await this.backend.otp.requestEmailOTP(
        new EmailOTPRequest(target, cred.bundleId, cred.deviceId, 'login')
      );
      return new AccountVerificationRequestContext(
        'email',
        channel.displayMasked.length > 0 ? channel.displayMasked : maskTarget(target),
        result.otpId,
        result.expiresIn ?? 300
      );
    }
    throw AccountManagementError.unsupportedChannel();
  }

  async submitDeactivation(
    options: AccountDeactivationOptions,
    verification: AccountDeactivationVerification,
    session: UserSession | undefined
  ): Promise<AccountDeactivationSubmission> {
    if (session === undefined) {
      throw AccountManagementError.missingSession();
    }
    let payload: DeactivationVerificationPayload;
    if (verification.kind === 'phone') {
      payload = DeactivationVerificationPayload.phone(verification.otpId, verification.code);
    } else if (verification.kind === 'email') {
      payload = DeactivationVerificationPayload.email(verification.otpId, verification.code);
    } else {
      throw AccountManagementError.missingProof();
    }
    const request = new DeactivationRequest();
    const reason = options.reason.trim();
    if (reason.length > 0) {
      request.reason = reason;
    }
    request.immediateDeactivation = options.immediateDeactivation;
    if (!options.immediateDeactivation) {
      request.countdownHours = options.countdownHours;
    }
    request.dataRetentionDays = options.dataRetentionDays;
    request.anonymizePersonalData = options.anonymizePersonalData;
    request.deleteRelatedData = options.deleteRelatedData;
    request.verification = payload;
    const result = await this.backend.deactivation.submit(request);
    const submission = new AccountDeactivationSubmission(result.deactivationId, result.state);
    submission.scheduledAt = result.scheduledAt;
    submission.immediateDeactivation = result.immediateDeactivation;
    submission.countdownHours = result.countdownHours;
    return submission;
  }
}

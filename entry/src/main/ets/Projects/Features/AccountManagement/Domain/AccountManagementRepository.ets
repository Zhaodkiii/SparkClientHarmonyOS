import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { AccountProfile } from './AccountProfile';
import {
  AccountIdentityBindProof,
  AccountIdentityList,
  AccountIdentityOperation,
  AccountIdentityProvider,
  AccountIdentityReauthProof,
  AccountVerificationRequestContext,
  IdentityVerificationRequestResult,
  VerificationTicket
} from './AccountIdentityModels';
import {
  AccountDeactivationOptions,
  AccountDeactivationSubmission,
  AccountDeactivationVerification,
  AccountVerificationChannel
} from './AccountDeactivationModels';

/**
 * 账户管理仓储契约（abstract class，避免 structural typing）。
 */
export abstract class AccountManagementRepository {
  abstract loadAccountProfile(session: UserSession | undefined): Promise<AccountProfile>;

  abstract loadIdentities(session: UserSession | undefined): Promise<AccountIdentityList>;

  abstract requestIdentityVerification(
    provider: AccountIdentityProvider,
    purpose: string,
    session: UserSession | undefined
  ): Promise<IdentityVerificationRequestResult>;

  abstract verifyIdentityVerification(
    provider: AccountIdentityProvider,
    purpose: string,
    proof: AccountIdentityReauthProof,
    session: UserSession | undefined
  ): Promise<VerificationTicket>;

  abstract requestTargetOTP(
    provider: AccountIdentityProvider,
    target: string,
    operation: AccountIdentityOperation,
    session: UserSession | undefined
  ): Promise<AccountVerificationRequestContext>;

  abstract bindIdentity(
    provider: AccountIdentityProvider,
    verificationTicket: string,
    proof: AccountIdentityBindProof,
    session: UserSession | undefined
  ): Promise<AccountIdentityList>;

  abstract changeIdentity(
    provider: AccountIdentityProvider,
    verificationTicket: string,
    newTarget: string,
    newOtpId: string,
    newCode: string,
    session: UserSession | undefined
  ): Promise<AccountIdentityList>;

  abstract requestDeactivationVerification(
    channel: AccountVerificationChannel,
    session: UserSession | undefined
  ): Promise<AccountVerificationRequestContext>;

  abstract submitDeactivation(
    options: AccountDeactivationOptions,
    verification: AccountDeactivationVerification,
    session: UserSession | undefined
  ): Promise<AccountDeactivationSubmission>;
}

import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { AccountManagementRepository } from '../Domain/AccountManagementRepository';
import {
  AccountIdentityOperation,
  AccountIdentityProvider,
  AccountVerificationRequestContext
} from '../Domain/AccountIdentityModels';

export class RequestTargetOTPUseCase {
  private readonly repository: AccountManagementRepository;

  constructor(repository: AccountManagementRepository) {
    this.repository = repository;
  }

  execute(
    provider: AccountIdentityProvider,
    target: string,
    operation: AccountIdentityOperation,
    session: UserSession | undefined
  ): Promise<AccountVerificationRequestContext> {
    return this.repository.requestTargetOTP(provider, target, operation, session);
  }
}

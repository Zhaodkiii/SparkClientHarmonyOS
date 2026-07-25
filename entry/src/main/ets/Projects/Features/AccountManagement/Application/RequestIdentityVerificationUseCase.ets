import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { AccountManagementRepository } from '../Domain/AccountManagementRepository';
import {
  AccountIdentityProvider,
  IdentityVerificationRequestResult
} from '../Domain/AccountIdentityModels';

export class RequestIdentityVerificationUseCase {
  private readonly repository: AccountManagementRepository;

  constructor(repository: AccountManagementRepository) {
    this.repository = repository;
  }

  execute(
    provider: AccountIdentityProvider,
    purpose: string,
    session: UserSession | undefined
  ): Promise<IdentityVerificationRequestResult> {
    return this.repository.requestIdentityVerification(provider, purpose, session);
  }
}

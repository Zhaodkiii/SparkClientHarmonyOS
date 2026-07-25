import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { AccountManagementRepository } from '../Domain/AccountManagementRepository';
import {
  AccountIdentityProvider,
  AccountIdentityReauthProof,
  VerificationTicket
} from '../Domain/AccountIdentityModels';

export class VerifyIdentityVerificationUseCase {
  private readonly repository: AccountManagementRepository;

  constructor(repository: AccountManagementRepository) {
    this.repository = repository;
  }

  execute(
    provider: AccountIdentityProvider,
    purpose: string,
    proof: AccountIdentityReauthProof,
    session: UserSession | undefined
  ): Promise<VerificationTicket> {
    return this.repository.verifyIdentityVerification(provider, purpose, proof, session);
  }
}

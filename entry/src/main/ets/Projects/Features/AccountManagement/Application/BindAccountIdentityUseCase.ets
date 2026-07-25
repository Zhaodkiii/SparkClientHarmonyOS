import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { AccountManagementRepository } from '../Domain/AccountManagementRepository';
import {
  AccountIdentityBindProof,
  AccountIdentityList,
  AccountIdentityProvider
} from '../Domain/AccountIdentityModels';

export class BindAccountIdentityUseCase {
  private readonly repository: AccountManagementRepository;

  constructor(repository: AccountManagementRepository) {
    this.repository = repository;
  }

  execute(
    provider: AccountIdentityProvider,
    verificationTicket: string,
    proof: AccountIdentityBindProof,
    session: UserSession | undefined
  ): Promise<AccountIdentityList> {
    return this.repository.bindIdentity(provider, verificationTicket, proof, session);
  }
}

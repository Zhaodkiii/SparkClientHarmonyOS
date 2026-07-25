import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { AccountManagementRepository } from '../Domain/AccountManagementRepository';
import { AccountIdentityList } from '../Domain/AccountIdentityModels';

export class LoadAccountIdentitiesUseCase {
  private readonly repository: AccountManagementRepository;

  constructor(repository: AccountManagementRepository) {
    this.repository = repository;
  }

  execute(session: UserSession | undefined): Promise<AccountIdentityList> {
    return this.repository.loadIdentities(session);
  }
}

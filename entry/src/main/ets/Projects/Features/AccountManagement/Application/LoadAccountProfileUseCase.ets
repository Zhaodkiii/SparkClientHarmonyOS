import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { AccountManagementRepository } from '../Domain/AccountManagementRepository';
import { AccountProfile } from '../Domain/AccountProfile';

export class LoadAccountProfileUseCase {
  private readonly repository: AccountManagementRepository;

  constructor(repository: AccountManagementRepository) {
    this.repository = repository;
  }

  execute(session: UserSession | undefined): Promise<AccountProfile> {
    return this.repository.loadAccountProfile(session);
  }
}

import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { AccountManagementRepository } from '../Domain/AccountManagementRepository';
import { AccountIdentityList, AccountIdentityProvider } from '../Domain/AccountIdentityModels';

export class ChangeAccountIdentityUseCase {
  private readonly repository: AccountManagementRepository;

  constructor(repository: AccountManagementRepository) {
    this.repository = repository;
  }

  execute(
    provider: AccountIdentityProvider,
    verificationTicket: string,
    newTarget: string,
    newOtpId: string,
    newCode: string,
    session: UserSession | undefined
  ): Promise<AccountIdentityList> {
    return this.repository.changeIdentity(
      provider,
      verificationTicket,
      newTarget,
      newOtpId,
      newCode,
      session
    );
  }
}

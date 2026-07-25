import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { AccountManagementRepository } from '../Domain/AccountManagementRepository';
import { AccountVerificationRequestContext } from '../Domain/AccountIdentityModels';
import { AccountVerificationChannel } from '../Domain/AccountDeactivationModels';

/** 注销发码 */
export class RequestAccountVerificationUseCase {
  private readonly repository: AccountManagementRepository;

  constructor(repository: AccountManagementRepository) {
    this.repository = repository;
  }

  execute(
    channel: AccountVerificationChannel,
    session: UserSession | undefined
  ): Promise<AccountVerificationRequestContext> {
    return this.repository.requestDeactivationVerification(channel, session);
  }
}

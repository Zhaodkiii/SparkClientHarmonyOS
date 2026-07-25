import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { AccountManagementRepository } from '../Domain/AccountManagementRepository';
import {
  AccountDeactivationOptions,
  AccountDeactivationSubmission,
  AccountDeactivationVerification
} from '../Domain/AccountDeactivationModels';

export class SubmitAccountDeactivationUseCase {
  private readonly repository: AccountManagementRepository;

  constructor(repository: AccountManagementRepository) {
    this.repository = repository;
  }

  execute(
    options: AccountDeactivationOptions,
    verification: AccountDeactivationVerification,
    session: UserSession | undefined
  ): Promise<AccountDeactivationSubmission> {
    return this.repository.submitDeactivation(options, verification, session);
  }
}

import { AuthRepository } from '../Domain/AuthRepository';
import { UserSession } from '../../../Core/Domain/Entities/UserSession';

export class RestoreSessionUseCase {
  private readonly repository: AuthRepository;

  constructor(repository: AuthRepository) {
    this.repository = repository;
  }

  async execute(): Promise<UserSession | undefined> {
    return this.repository.restoreSession();
  }
}

import { AuthRepository } from '../Domain/AuthRepository';
import { UserSession } from '../../../Core/Domain/Entities/UserSession';

export class SignInWithDeviceUseCase {
  private readonly repository: AuthRepository;
  private inFlight?: Promise<UserSession>;

  constructor(repository: AuthRepository) {
    this.repository = repository;
  }

  async execute(): Promise<UserSession> {
    if (this.inFlight) {
      return this.inFlight;
    }
    this.inFlight = this.repository.signInWithDevice().finally(() => {
      this.inFlight = undefined;
    });
    return this.inFlight;
  }
}

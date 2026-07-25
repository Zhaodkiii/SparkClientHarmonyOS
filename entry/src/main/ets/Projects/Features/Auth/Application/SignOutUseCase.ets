import { AuthRepository } from '../Domain/AuthRepository';

export class SignOutUseCase {
  private readonly repository: AuthRepository;
  private inFlight?: Promise<void>;

  constructor(repository: AuthRepository) {
    this.repository = repository;
  }

  async execute(): Promise<void> {
    if (this.inFlight) {
      return this.inFlight;
    }
    this.inFlight = this.repository.signOut().finally(() => {
      this.inFlight = undefined;
    });
    return this.inFlight;
  }
}

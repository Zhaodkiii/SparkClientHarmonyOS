import { AuthRepository } from '../Domain/AuthRepository';
import { UserSession } from '../../../Core/Domain/Entities/UserSession';

export class SignInWithPhoneOTPUseCase {
  private readonly repository: AuthRepository;
  private inFlight?: Promise<UserSession>;

  constructor(repository: AuthRepository) {
    this.repository = repository;
  }

  async execute(otpId: string, phoneNumber: string, code: string): Promise<UserSession> {
    if (this.inFlight) {
      return this.inFlight;
    }
    this.inFlight = this.repository.signInWithPhoneOTP(otpId, phoneNumber, code).finally(() => {
      this.inFlight = undefined;
    });
    return this.inFlight;
  }
}

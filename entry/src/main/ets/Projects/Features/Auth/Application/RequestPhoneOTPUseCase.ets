import { AuthRepository } from '../Domain/AuthRepository';
import { OTPRequestResponse } from '../../../Core/Networking/API/Auth/OTPAPI';

export class RequestPhoneOTPUseCase {
  private readonly repository: AuthRepository;
  private inFlight?: Promise<OTPRequestResponse>;

  constructor(repository: AuthRepository) {
    this.repository = repository;
  }

  async execute(phoneNumber: string, scene: string = 'login'): Promise<OTPRequestResponse> {
    if (this.inFlight) {
      return this.inFlight;
    }
    this.inFlight = this.repository.requestPhoneOTP(phoneNumber, scene).finally(() => {
      this.inFlight = undefined;
    });
    return this.inFlight;
  }
}

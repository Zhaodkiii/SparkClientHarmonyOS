/**
 * 设备登记结果；对齐 iOS DeviceRegistrationRequestOutcome。
 */
export type DeviceRegistrationOutcome =
  | 'submitted'
  | 'skippedSameLaunchSubmission'
  | 'failedRetryable'
  | 'authSessionInvalidated';

export class DeviceRegistrationOutcomes {
  static allowsAccountBootstrap(outcome: DeviceRegistrationOutcome): boolean {
    return outcome === 'submitted' || outcome === 'skippedSameLaunchSubmission';
  }
}

export class DeviceRegistrationRetryPolicy {
  static readonly maxAttempts: number = 3;
  /** 每次尝试前的退避毫秒：第 0/1/2 次；测试可临时改写 */
  static backoffMs: number[] = [0, 300, 600];

  static backoffBeforeAttempt(attemptIndex: number): number {
    if (attemptIndex <= 0 || attemptIndex >= DeviceRegistrationRetryPolicy.backoffMs.length) {
      return 0;
    }
    return DeviceRegistrationRetryPolicy.backoffMs[attemptIndex];
  }
}

export type DeviceRegistrationReason = 'guestColdLaunch' | 'signedInColdLaunch' | 'signedInForeground';

import {
  DeviceRegisterClient,
  DeviceRegistrationRequest
} from '../Projects/Core/Networking/API/Device/DeviceAPI';
import { DeviceCredentialProvider } from '../Foundation/Security/DeviceCredentialStore';
import { SystemInfoProvider, SupportSystemInfo } from '../Foundation/SupportSystemInfo';
import { DeviceCache } from '../Projects/Core/Networking/Caching/DeviceCache';
import { DeviceRegistrationSubmittedSnapshot } from '../Projects/Core/Device/Application/DeviceRegistrationSubmittedSnapshot';
import { UserSession } from '../Projects/Core/Domain/Entities/UserSession';
import { SupportNetworkError } from '../Projects/Core/Networking/SupportNetworkModels';
import { Logger } from '../Foundation/Logging/Logger';
import { LogModule } from '../Foundation/Logging/LogModule';
import { LogFields } from '../Foundation/Logging/LogEvent';
import {
  DeviceRegistrationOutcome,
  DeviceRegistrationReason,
  DeviceRegistrationRetryPolicy
} from './DeviceRegistrationRequestOutcome';

/**
 * 游客/已登录设备登记：有限重试、同启动去重、跨启动摘要、401 中止。
 */
export class DeviceRegistrationCoordinator {
  private readonly deviceApi: DeviceRegisterClient;
  private readonly credentials: DeviceCredentialProvider;
  private readonly systemInfo: SystemInfoProvider;
  private readonly deviceCache?: DeviceCache;
  private lastRegisteredKey?: string;
  private submissionSuspended: boolean = false;

  constructor(
    deviceApi: DeviceRegisterClient,
    credentials: DeviceCredentialProvider,
    systemInfo?: SystemInfoProvider,
    deviceCache?: DeviceCache
  ) {
    this.deviceApi = deviceApi;
    this.credentials = credentials;
    this.systemInfo = systemInfo ?? new SupportSystemInfo();
    this.deviceCache = deviceCache;
  }

  reset(): void {
    this.lastRegisteredKey = undefined;
    this.submissionSuspended = false;
  }

  suspendPendingSubmissions(): void {
    this.submissionSuspended = true;
    Logger.info('device.registration_suspended', LogModule.LIFECYCLE);
  }

  async registerGuestDevice(reason: DeviceRegistrationReason = 'guestColdLaunch'): Promise<DeviceRegistrationOutcome> {
    return this.requestRegister(undefined, false, reason);
  }

  async requestRegisterWithLimitedRetry(
    session: UserSession,
    reason: DeviceRegistrationReason = 'signedInColdLaunch',
    maxAttempts: number = DeviceRegistrationRetryPolicy.maxAttempts
  ): Promise<DeviceRegistrationOutcome> {
    const attempts = maxAttempts < 1 ? 1 : maxAttempts;
    let lastOutcome: DeviceRegistrationOutcome = 'failedRetryable';
    for (let attemptIndex = 0; attemptIndex < attempts; attemptIndex++) {
      const backoff = DeviceRegistrationRetryPolicy.backoffBeforeAttempt(attemptIndex);
      if (backoff > 0) {
        await DeviceRegistrationCoordinator.delay(backoff);
      }
      lastOutcome = await this.requestRegister(session.accountId, true, reason);
      if (lastOutcome === 'submitted'
        || lastOutcome === 'skippedSameLaunchSubmission'
        || lastOutcome === 'authSessionInvalidated') {
        return lastOutcome;
      }
      const retry = new LogFields();
      retry.detail = `设备登记重试 attempt=${attemptIndex + 1}/${attempts}`;
      Logger.warn('device.registration.retry', LogModule.LIFECYCLE, retry);
    }
    return lastOutcome;
  }

  private async requestRegister(
    userId: number | undefined,
    authenticated: boolean,
    reason: DeviceRegistrationReason
  ): Promise<DeviceRegistrationOutcome> {
    if (this.submissionSuspended) {
      return 'failedRetryable';
    }
    const cred = await this.credentials.getOrCreateDeviceIdentity();
    const key = `${authenticated}-${userId ?? 0}-${cred.deviceId}`;
    if (key === this.lastRegisteredKey && reason !== 'signedInForeground') {
      Logger.info('device.registration_skipped_same_launch', LogModule.LIFECYCLE);
      return 'skippedSameLaunchSubmission';
    }

    const info = this.systemInfo.collect();
    const bundleId = info.bundleId.length > 0 ? info.bundleId : cred.bundleId;
    const request = new DeviceRegistrationRequest();
    request.device_id = cred.deviceId;
    if (userId !== undefined) {
      request.user_id = userId;
    }
    request.push_token = '';
    request.notifications_enabled = false;
    request.app_version = info.appVersion;
    request.build_version = info.buildVersion;
    request.bundle_identifier = bundleId;
    request.bundle_id = bundleId;
    request.platform = info.platform.length > 0 ? info.platform : 'harmonyos';
    request.system_version = info.systemVersion;
    request.device_model = info.deviceModel;
    request.device_model_name = info.deviceModelName;
    request.device_name = info.deviceName;
    request.screen_size = info.screenSize;
    if (info.screenScale !== undefined) {
      request.screen_scale = info.screenScale;
    }
    request.time_zone = info.timeZone;
    request.language_code = info.languageCode;
    request.region_code = info.regionCode;
    request.country_code = info.countryCode;
    request.is_simulator = info.isSimulator;

    const pending = DeviceRegistrationCoordinator.buildSnapshot(
      userId,
      authenticated,
      bundleId,
      cred.deviceId,
      info.countryCode,
      info.regionCode,
      request.notifications_enabled,
      request.push_token
    );

    if (this.deviceCache) {
      this.deviceCache.setAccountScope(authenticated && userId !== undefined ? `${userId}` : 'anonymous');
      const previous = await this.deviceCache.getLastDeviceRegistrationSnapshot();
      if (DeviceRegistrationSubmittedSnapshot.equals(previous, pending)) {
        this.lastRegisteredKey = key;
        Logger.info('device.registration_skipped_unchanged_snapshot', LogModule.LIFECYCLE);
        return 'skippedSameLaunchSubmission';
      }
    }

    try {
      await this.deviceApi.register(request, authenticated);
      this.lastRegisteredKey = key;
      if (this.deviceCache) {
        await this.deviceCache.setLastDeviceRegistrationSnapshot(pending);
      }
      const submitted = new LogFields();
      submitted.detail = `设备登记已提交 reason=${reason}`;
      Logger.info('device.registration.submitted', LogModule.LIFECYCLE, submitted);
      return 'submitted';
    } catch (err) {
      if (DeviceRegistrationCoordinator.isAuthInvalidation(err as Object)) {
        this.suspendPendingSubmissions();
        Logger.warn('device.registration_auth_invalidated', LogModule.LIFECYCLE);
        return 'authSessionInvalidated';
      }
      Logger.warn('device.registration_failed_retryable', LogModule.LIFECYCLE);
      return 'failedRetryable';
    }
  }

  private static buildSnapshot(
    userId: number | undefined,
    authenticated: boolean,
    bundleId: string,
    deviceId: string,
    countryCode: string,
    regionCode: string,
    notificationsEnabled: boolean,
    pushToken: string
  ): DeviceRegistrationSubmittedSnapshot {
    const snap = new DeviceRegistrationSubmittedSnapshot();
    if (userId !== undefined) {
      snap.accountID = userId;
    }
    snap.isAuthenticated = authenticated;
    snap.bundleID = bundleId;
    snap.deviceID = deviceId;
    snap.countryCode = countryCode;
    snap.regionCode = regionCode;
    snap.notificationsEnabled = notificationsEnabled;
    snap.pushTokenHash = pushToken.length > 0 ? `h_${pushToken.length}` : '';
    return snap;
  }

  private static isAuthInvalidation(err: Object): boolean {
    if (err instanceof SupportNetworkError) {
      if (err.statusCode === 401) {
        return true;
      }
      if (err.backend && err.backend.code >= 40100 && err.backend.code <= 40199) {
        return true;
      }
    }
    return false;
  }

  private static delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }
}

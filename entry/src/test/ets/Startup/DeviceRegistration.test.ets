import { describe, it, expect } from '@ohos/hypium';
import {
  DeviceRegistrationOutcomes,
  DeviceRegistrationRetryPolicy
} from '../../../main/ets/App/DeviceRegistrationRequestOutcome';
import {
  DeviceAPI,
  DeviceRegisterClient,
  DeviceRegistrationRequest,
  DeviceRegistrationResponse
} from '../../../main/ets/Projects/Core/Networking/API/Device/DeviceAPI';
import { DeviceRegistrationCoordinator } from '../../../main/ets/App/DeviceRegistrationCoordinator';
import {
  DeviceCredential,
  FixedDeviceCredentials
} from '../../../main/ets/Foundation/Security/DeviceCredentialStore';
import {
  FixedSystemInfo,
  SupportSystemInfoSnapshot
} from '../../../main/ets/Foundation/SupportSystemInfo';
import { DeviceCache } from '../../../main/ets/Projects/Core/Networking/Caching/DeviceCache';
import { DeviceRegistrationSubmittedSnapshot } from '../../../main/ets/Projects/Core/Device/Application/DeviceRegistrationSubmittedSnapshot';
import { UserSession } from '../../../main/ets/Projects/Core/Domain/Entities/UserSession';
import {
  BackendErrorInfo,
  SupportNetworkError
} from '../../../main/ets/Projects/Core/Networking/SupportNetworkModels';

class FakeDeviceApi extends DeviceRegisterClient {
  calls: number = 0;
  behavior: string = 'ok';
  lastRequest?: DeviceRegistrationRequest;
  lastAuthenticated: boolean = false;

  async register(
    request: DeviceRegistrationRequest,
    authenticated: boolean
  ): Promise<DeviceRegistrationResponse> {
    this.calls += 1;
    this.lastRequest = request;
    this.lastAuthenticated = authenticated;
    if (this.behavior === 'fail') {
      throw new Error('network');
    }
    if (this.behavior === 'auth') {
      throw SupportNetworkError.http(401, new BackendErrorInfo(40102, 'token_not_valid'));
    }
    const r = new DeviceRegistrationResponse();
    r.deviceId = request.device_id;
    r.registered = true;
    r.created = true;
    return r;
  }
}

function makeCoordinator(api: FakeDeviceApi, cache?: DeviceCache): DeviceRegistrationCoordinator {
  const snap = new SupportSystemInfoSnapshot();
  snap.appVersion = '2.0.0';
  snap.buildVersion = '42';
  snap.systemVersion = 'HarmonyOS 6';
  snap.deviceModel = 'TestModel';
  snap.deviceModelName = 'Test Phone';
  snap.timeZone = 'Asia/Shanghai';
  snap.languageCode = 'zh';
  snap.regionCode = 'CN';
  snap.countryCode = 'CN';
  snap.screenSize = '1080x2340';
  snap.screenScale = 3;
  return new DeviceRegistrationCoordinator(
    api,
    new FixedDeviceCredentials(new DeviceCredential('dev-1', 'secret-1')),
    new FixedSystemInfo(snap),
    cache
  );
}

export default function deviceRegistrationTest() {
  describe('DeviceRegistration', () => {
    it('request_defaults_platform_harmonyos', 0, () => {
      const req = new DeviceRegistrationRequest();
      expect(req.platform).assertEqual('harmonyos');
      expect(req.device_id).assertEqual('');
      expect(req.notifications_enabled).assertFalse();
    });

    it('outcome_gate_for_bootstrap', 0, () => {
      expect(DeviceRegistrationOutcomes.allowsAccountBootstrap('submitted')).assertTrue();
      expect(DeviceRegistrationOutcomes.allowsAccountBootstrap('failedRetryable')).assertFalse();
    });

    it('retry_policy_three_attempts', 0, () => {
      expect(DeviceRegistrationRetryPolicy.maxAttempts).assertEqual(3);
      expect(DeviceRegistrationRetryPolicy.backoffMs.length).assertEqual(3);
    });

    it('decode_response_maps_created_to_registered', 0, () => {
      const data: Record<string, Object | string | boolean | number> = {};
      data['device_id'] = 'd1';
      data['bundle_id'] = 'cn.Zhaodk.Health';
      data['created'] = true;
      const r = DeviceAPI.decodeResponse(data);
      expect(r.deviceId).assertEqual('d1');
      expect(r.bundleId).assertEqual('cn.Zhaodk.Health');
      expect(r.created).assertTrue();
      expect(r.registered).assertTrue();
    });

    it('coordinator_submit_success_and_same_launch_skip', 0, async () => {
      const api = new FakeDeviceApi();
      const coord = makeCoordinator(api);
      const first = await coord.registerGuestDevice('guestColdLaunch');
      expect(first).assertEqual('submitted');
      expect(api.calls).assertEqual(1);
      expect(api.lastAuthenticated).assertFalse();
      expect(api.lastRequest?.app_version).assertEqual('2.0.0');
      expect(api.lastRequest?.system_version).assertEqual('HarmonyOS 6');
      const second = await coord.registerGuestDevice('guestColdLaunch');
      expect(second).assertEqual('skippedSameLaunchSubmission');
      expect(api.calls).assertEqual(1);
    });

    it('coordinator_retry_then_fail', 0, async () => {
      const api = new FakeDeviceApi();
      api.behavior = 'fail';
      const coord = makeCoordinator(api);
      const prev = DeviceRegistrationRetryPolicy.backoffMs;
      DeviceRegistrationRetryPolicy.backoffMs = [0, 0, 0];
      const session = new UserSession(9, 'device');
      const outcome = await coord.requestRegisterWithLimitedRetry(session, 'signedInColdLaunch', 3);
      DeviceRegistrationRetryPolicy.backoffMs = prev;
      expect(outcome).assertEqual('failedRetryable');
      expect(api.calls).assertEqual(3);
    });

    it('coordinator_auth_invalidation_suspends', 0, async () => {
      const api = new FakeDeviceApi();
      api.behavior = 'auth';
      const coord = makeCoordinator(api);
      const session = new UserSession(9, 'device');
      const outcome = await coord.requestRegisterWithLimitedRetry(session, 'signedInColdLaunch', 1);
      expect(outcome).assertEqual('authSessionInvalidated');
      api.behavior = 'ok';
      const after = await coord.registerGuestDevice('guestColdLaunch');
      expect(after).assertEqual('failedRetryable');
      expect(api.calls).assertEqual(1);
    });

    it('snapshot_equals_and_cross_launch_skip', 0, async () => {
      const a = new DeviceRegistrationSubmittedSnapshot();
      a.accountID = 1;
      a.isAuthenticated = true;
      a.bundleID = 'b';
      a.deviceID = 'd';
      a.countryCode = 'CN';
      a.regionCode = 'CN';
      a.notificationsEnabled = false;
      a.pushTokenHash = '';
      const b = DeviceRegistrationSubmittedSnapshot.fromJson(a.toJson());
      expect(DeviceRegistrationSubmittedSnapshot.equals(a, b)).assertTrue();

      const api = new FakeDeviceApi();
      const cache = DeviceCache.memoryOnly();
      const coord = makeCoordinator(api, cache);
      const session = new UserSession(1, 'device');
      const first = await coord.requestRegisterWithLimitedRetry(session, 'signedInColdLaunch', 1);
      expect(first).assertEqual('submitted');
      coord.reset();
      const second = await coord.requestRegisterWithLimitedRetry(session, 'signedInForeground', 1);
      expect(second).assertEqual('skippedSameLaunchSubmission');
      expect(api.calls).assertEqual(1);
    });
  });
}

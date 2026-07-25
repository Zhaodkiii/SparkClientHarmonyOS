import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium';
import { UserSession } from '../../../main/ets/Projects/Core/Domain/Entities/UserSession';
import { SessionSnapshotStore } from '../../../main/ets/Projects/Features/Auth/Infrastructure/SessionSnapshotStore';
import { DeviceCredentialStore, DeviceCredential } from '../../../main/ets/Foundation/Security/DeviceCredentialStore';
import { AuthenticatedUserContext, CurrentSessionResult } from '../../../main/ets/Projects/Core/Networking/API/Auth/AuthAPI';
import { AuthTokens } from '../../../main/ets/Projects/Core/Networking/SupportNetworkModels';
import { AuthRepository } from '../../../main/ets/Projects/Features/Auth/Domain/AuthRepository';
import { RestoreSessionUseCase } from '../../../main/ets/Projects/Features/Auth/Application/RestoreSessionUseCase';
import { SignInWithDeviceUseCase } from '../../../main/ets/Projects/Features/Auth/Application/SignInWithDeviceUseCase';
import { SignOutUseCase } from '../../../main/ets/Projects/Features/Auth/Application/SignOutUseCase';
import { OTPRequestResponse } from '../../../main/ets/Projects/Core/Networking/API/Auth/OTPAPI';
import { AppSessionStore } from '../../../main/ets/App/AppSessionStore';
import { AccountSessionRuntime } from '../../../main/ets/App/AccountSessionRuntime';
import { SessionInvalidation } from '../../../main/ets/Projects/Core/Networking/SessionInvalidation';
import { RouteCoordinator } from '../../../main/ets/App/RouteCoordinator';
import { fileIo as fs } from '@kit.CoreFileKit';

class MemoryAuthRepository extends AuthRepository {
  session?: UserSession;
  signedOut: boolean = false;
  deviceCalls: number = 0;

  async signInWithDevice(): Promise<UserSession> {
    this.deviceCalls += 1;
    this.session = new UserSession(100, 'device', '', 'guest', Date.now(), false, true, true);
    return this.session;
  }

  async requestPhoneOTP(_phoneNumber: string, _scene?: string): Promise<OTPRequestResponse> {
    return new OTPRequestResponse('otp-x', 60);
  }

  async signInWithPhoneOTP(_otpId: string, _phoneNumber: string, _code: string): Promise<UserSession> {
    this.session = new UserSession(200, 'phone');
    return this.session;
  }

  async restoreSession(): Promise<UserSession | undefined> {
    return this.session;
  }

  async signOut(): Promise<void> {
    this.session = undefined;
    this.signedOut = true;
  }

  async clearLocalSession(): Promise<void> {
    this.session = undefined;
    this.signedOut = true;
  }
}

export default function authDomainTest() {
  describe('AuthDomain', () => {
    beforeEach(() => {
      SessionInvalidation.resetForTests();
    });

    afterEach(() => {
      SessionInvalidation.resetForTests();
    });

    it('user_session_roundtrip_plain', 0, () => {
      const s = new UserSession(42, 'phone', 'a@b.c', '小鲸', 123456, true, false, false);
      const plain = s.toPlain();
      const back = UserSession.fromPlain(plain);
      expect(back !== undefined).assertTrue();
      expect(back!.accountId).assertEqual(42);
      expect(back!.signInMethod).assertEqual('phone');
      expect(back!.email).assertEqual('a@b.c');
      expect(back!.isPro).assertTrue();
      expect(back!.isDeviceAccount).assertFalse();
    });

    it('user_session_from_plain_accepts_snake_aliases', 0, () => {
      const obj: Record<string, Object | string | number | boolean | undefined> = {};
      obj['user_id'] = 7;
      obj['sign_in_method'] = 'device';
      obj['is_device_account'] = true;
      obj['display_name'] = '游客';
      const s = UserSession.fromPlain(obj);
      expect(s !== undefined).assertTrue();
      expect(s!.accountId).assertEqual(7);
      expect(s!.isDeviceAccount).assertTrue();
      expect(s!.displayName).assertEqual('游客');
    });

    it('user_session_from_auth_context', 0, () => {
      const tokens = new AuthTokens('a', 'r', Date.now() + 10000);
      const ctx = new AuthenticatedUserContext(3, tokens, false, true, true, undefined, '设备', 'device');
      const s = UserSession.fromAuthContext(ctx);
      expect(s.accountId).assertEqual(3);
      expect(s.isDeviceAccount).assertTrue();
      expect(s.isNewUser).assertTrue();
      expect(s.signInMethod).assertEqual('device');
    });

    it('user_session_merge_current_session_keeps_signed_in_at', 0, () => {
      const local = new UserSession(1, 'device', '', 'old', 999, false, false, true);
      const remote = new CurrentSessionResult(1, 'x@y.z', '新名', true, false, 'device', true);
      const merged = UserSession.fromCurrentSession(remote, local);
      expect(merged.signedInAtMs).assertEqual(999);
      expect(merged.email).assertEqual('x@y.z');
      expect(merged.displayName).assertEqual('新名');
      expect(merged.isPro).assertTrue();
    });

    it('user_session_corrupt_plain_returns_undefined', 0, () => {
      const obj: Record<string, Object | string | number | boolean | undefined> = {};
      obj['email'] = 'only';
      expect(UserSession.fromPlain(obj) === undefined).assertTrue();
    });

    it('session_snapshot_store_save_load_clear', 0, async () => {
      const dir = '/tmp/support-auth-snapshot-test';
      try {
        fs.mkdirSync(dir, true);
      } catch (_e) {
        // ignore
      }
      const store = new SessionSnapshotStore(dir);
      await store.clear();
      const empty = await store.load();
      expect(empty === undefined).assertTrue();
      const session = new UserSession(11, 'device', '', 'g', Date.now(), false, true, true);
      await store.save(session);
      const loaded = await store.load();
      expect(loaded !== undefined).assertTrue();
      expect(loaded!.accountId).assertEqual(11);
      await store.clear();
      expect((await store.load()) === undefined).assertTrue();
    });

    it('session_snapshot_store_corrupt_returns_undefined', 0, async () => {
      const dir = '/tmp/support-auth-snapshot-corrupt';
      try {
        fs.mkdirSync(dir, true);
      } catch (_e) {
        // ignore
      }
      const path = `${dir}/session/user_session.json`;
      try {
        fs.mkdirSync(`${dir}/session`, true);
      } catch (_e2) {
        // ignore
      }
      const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, '{not-json');
      } finally {
        fs.closeSync(file);
      }
      const store = new SessionSnapshotStore(dir);
      const loaded = await store.load();
      expect(loaded === undefined).assertTrue();
    });

    it('device_credential_store_stable_across_getOrCreate', 0, async () => {
      const dir = '/tmp/support-auth-device-cred';
      try {
        fs.mkdirSync(dir, true);
      } catch (_e) {
        // ignore
      }
      const store = new DeviceCredentialStore(dir);
      await store.clearForTests();
      const a = await store.getOrCreate();
      const b = await store.getOrCreate();
      expect(a.deviceId).assertEqual(b.deviceId);
      expect(a.deviceSecret).assertEqual(b.deviceSecret);
      const store2 = new DeviceCredentialStore(dir);
      const c = await store2.getOrCreate();
      expect(c.deviceId).assertEqual(a.deviceId);
    });

    it('device_credential_save_rejects_empty_secret', 0, async () => {
      const store = new DeviceCredentialStore('/tmp/support-auth-device-bad');
      let threw = false;
      try {
        await store.save(new DeviceCredential('id', '', 'cn.Zhaodk.Health'));
      } catch (_e) {
        threw = true;
      }
      expect(threw).assertTrue();
    });

    it('sign_in_device_usecase_single_flight', 0, async () => {
      const repo = new MemoryAuthRepository();
      const useCase = new SignInWithDeviceUseCase(repo);
      const p1 = useCase.execute();
      const p2 = useCase.execute();
      const s1 = await p1;
      const s2 = await p2;
      expect(s1.accountId).assertEqual(s2.accountId);
      expect(repo.deviceCalls).assertEqual(1);
    });

    it('sign_out_usecase_clears_session', 0, async () => {
      const repo = new MemoryAuthRepository();
      repo.session = new UserSession(1);
      const useCase = new SignOutUseCase(repo);
      await useCase.execute();
      expect(repo.signedOut).assertTrue();
      expect(repo.session === undefined).assertTrue();
    });

    it('restore_usecase_returns_repo_result', 0, async () => {
      const repo = new MemoryAuthRepository();
      repo.session = new UserSession(55, 'phone');
      const useCase = new RestoreSessionUseCase(repo);
      const s = await useCase.execute();
      expect(s?.accountId).assertEqual(55);
    });

    it('invalidate_clears_snapshot_via_runtime', 0, async () => {
      const dir = '/tmp/support-auth-invalidate';
      const snapshot = new SessionSnapshotStore(dir);
      await snapshot.save(new UserSession(8, 'device', '', '', Date.now(), false, false, true));
      const runtime = new AccountSessionRuntime(snapshot);
      const store = new AppSessionStore();
      store.configure(new RestoreSessionUseCase(new MemoryAuthRepository()), runtime);
      store.setStateForTests('signedIn', 1, new UserSession(8));
      const coordinator = new RouteCoordinator(store);
      coordinator.start();
      SessionInvalidation.postIfNeeded(401, undefined, 'token_not_valid', 'auth-domain');
      expect(store.sessionState).assertEqual('signedOut');
      await runtime.onAuthInvalidated();
      expect((await snapshot.load()) === undefined).assertTrue();
      coordinator.stop();
    });
  });
}

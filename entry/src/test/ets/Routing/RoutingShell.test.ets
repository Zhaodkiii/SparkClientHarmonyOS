import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium';
import { AppSessionStore } from '../../../main/ets/App/AppSessionStore';
import { RouteCoordinator } from '../../../main/ets/App/RouteCoordinator';
import { SessionInvalidation } from '../../../main/ets/Projects/Core/Networking/SessionInvalidation';
import { RestoreSessionUseCase } from '../../../main/ets/Projects/Features/Auth/Application/RestoreSessionUseCase';
import { AuthRepository } from '../../../main/ets/Projects/Features/Auth/Domain/AuthRepository';
import { UserSession } from '../../../main/ets/Projects/Core/Domain/Entities/UserSession';
import { OTPRequestResponse } from '../../../main/ets/Projects/Core/Networking/API/Auth/OTPAPI';
import { AccountSessionRuntime } from '../../../main/ets/App/AccountSessionRuntime';
import { SessionSnapshotStore } from '../../../main/ets/Projects/Features/Auth/Infrastructure/SessionSnapshotStore';

class FakeAuthRepository extends AuthRepository {
  restoreResult?: UserSession;
  clearCalled: boolean = false;

  async signInWithDevice(): Promise<UserSession> {
    return new UserSession(1, 'device', '', '', Date.now(), false, false, true);
  }

  async requestPhoneOTP(_phoneNumber: string, _scene?: string): Promise<OTPRequestResponse> {
    return new OTPRequestResponse('otp-1', 60);
  }

  async signInWithPhoneOTP(_otpId: string, _phoneNumber: string, _code: string): Promise<UserSession> {
    return new UserSession(2, 'phone');
  }

  async restoreSession(): Promise<UserSession | undefined> {
    return this.restoreResult;
  }

  async signOut(): Promise<void> {
    // no-op
  }

  async clearLocalSession(): Promise<void> {
    this.clearCalled = true;
  }
}

export default function routingShellTest() {
  describe('RoutingShell', () => {
    let store: AppSessionStore;
    let fakeRepo: FakeAuthRepository;

    beforeEach(() => {
      SessionInvalidation.resetForTests();
      fakeRepo = new FakeAuthRepository();
      store = new AppSessionStore();
      const snapshot = new SessionSnapshotStore('/tmp/support_routing_test_session');
      const runtime = new AccountSessionRuntime(snapshot);
      store.configure(new RestoreSessionUseCase(fakeRepo), runtime);
    });

    afterEach(() => {
      SessionInvalidation.resetForTests();
    });

    it('restore_without_session_goes_signed_out', 0, async () => {
      fakeRepo.restoreResult = undefined;
      await store.restoreIfNeeded();
      expect(store.sessionState).assertEqual('signedOut');
    });

    it('restore_with_session_goes_signed_in', 0, async () => {
      fakeRepo.restoreResult = new UserSession(9, 'device', '', '', Date.now(), false, true, true);
      await store.restoreIfNeeded();
      expect(store.sessionState).assertEqual('signedIn');
      expect(store.session?.accountId).assertEqual(9);
    });

    it('enter_signed_in_bumps_generation', 0, () => {
      const before = store.generation;
      store.enterSignedIn(new UserSession(1));
      expect(store.sessionState).assertEqual('signedIn');
      expect(store.generation).assertEqual(before + 1);
    });

    it('sign_out_is_idempotent_when_already_signed_out', 0, () => {
      store.setStateForTests('signedOut', 1);
      const gen = store.generation;
      store.signOut();
      expect(store.sessionState).assertEqual('signedOut');
      expect(store.generation).assertEqual(gen);
    });

    it('auth_invalidated_same_generation_signs_out', 0, () => {
      store.setStateForTests('signedIn', 3);
      const applied = store.handleAuthInvalidated(3);
      expect(applied).assertTrue();
      expect(store.sessionState).assertEqual('signedOut');
      expect(store.generation).assertEqual(4);
    });

    it('auth_invalidated_stale_generation_discarded', 0, () => {
      store.setStateForTests('signedIn', 5);
      const applied = store.handleAuthInvalidated(4);
      expect(applied).assertFalse();
      expect(store.sessionState).assertEqual('signedIn');
      expect(store.generation).assertEqual(5);
    });

    it('auth_invalidated_when_signed_out_is_idempotent', 0, () => {
      store.setStateForTests('signedOut', 2);
      const applied = store.handleAuthInvalidated(2);
      expect(applied).assertFalse();
      expect(store.generation).assertEqual(2);
    });

    it('route_coordinator_consumes_session_invalidation', 0, () => {
      store.setStateForTests('signedIn', 7);
      const coordinator = new RouteCoordinator(store);
      coordinator.start();
      const posted = SessionInvalidation.postIfNeeded(401, undefined, 'token_expired', 'test');
      expect(posted).assertTrue();
      expect(store.sessionState).assertEqual('signedOut');
      expect(SessionInvalidation.invalidating).assertFalse();
      coordinator.stop();
    });

    it('route_coordinator_second_invalidation_after_relogin', 0, () => {
      store.setStateForTests('signedIn', 1);
      const coordinator = new RouteCoordinator(store);
      coordinator.start();
      SessionInvalidation.postIfNeeded(401, undefined, 'token_expired', 'first');
      expect(store.sessionState).assertEqual('signedOut');
      store.enterSignedIn(new UserSession(1));
      const gen = store.generation;
      SessionInvalidation.postIfNeeded(401, undefined, 'token_expired', 'second');
      expect(store.sessionState).assertEqual('signedOut');
      expect(store.generation > gen).assertTrue();
      coordinator.stop();
    });
  });
}

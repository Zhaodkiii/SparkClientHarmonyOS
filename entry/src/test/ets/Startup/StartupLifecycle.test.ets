import { describe, it, expect } from '@ohos/hypium';
import { SignedInSessionPreparationRegistry } from '../../../main/ets/App/SignedInSessionPreparationRegistry';
import {
  DeviceRegistrationOutcomes,
  DeviceRegistrationRetryPolicy
} from '../../../main/ets/App/DeviceRegistrationRequestOutcome';
import { AIAccountBootstrapGateway, AppBootstrapper, BootstrapOutcome } from '../../../main/ets/App/AppBootstrapper';
import { SupportNetworkError, BackendErrorInfo } from '../../../main/ets/Projects/Core/Networking/SupportNetworkModels';

class FakeAIBootstrap extends AIAccountBootstrapGateway {
  calls: number = 0;
  failWith?: Object;

  async prepareAccount(_accountId: number): Promise<BootstrapOutcome> {
    this.calls += 1;
    if (this.failWith) {
      throw this.failWith;
    }
    return new BootstrapOutcome();
  }
}

export default function startupLifecycleTest() {
  describe('StartupLifecycle', () => {
    it('preparation_registry_marks_prepared', 0, async () => {
      const reg = new SignedInSessionPreparationRegistry();
      let ran = 0;
      await reg.runIfNeeded(7, async () => {
        ran += 1;
        reg.markPrepared(7);
      });
      expect(ran).assertEqual(1);
      expect(reg.preparedAccountId).assertEqual(7);
      await reg.runIfNeeded(7, async () => {
        ran += 1;
      });
      expect(ran).assertEqual(1);
    });

    it('preparation_registry_reset_clears_prepared', 0, async () => {
      const reg = new SignedInSessionPreparationRegistry();
      reg.setPreparedForTests(3);
      expect(reg.preparedAccountId).assertEqual(3);
      reg.reset();
      expect(reg.preparedAccountId === undefined).assertTrue();
    });

    it('preparation_single_flight_same_account', 0, async () => {
      const reg = new SignedInSessionPreparationRegistry();
      let ran = 0;
      const op = async (): Promise<void> => {
        ran += 1;
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 20));
        reg.markPrepared(11);
      };
      const p1 = reg.runIfNeeded(11, op);
      const p2 = reg.runIfNeeded(11, op);
      await p1;
      await p2;
      expect(ran).assertEqual(1);
    });

    it('device_outcome_allows_bootstrap', 0, () => {
      expect(DeviceRegistrationOutcomes.allowsAccountBootstrap('submitted')).assertTrue();
      expect(DeviceRegistrationOutcomes.allowsAccountBootstrap('skippedSameLaunchSubmission')).assertTrue();
      expect(DeviceRegistrationOutcomes.allowsAccountBootstrap('failedRetryable')).assertFalse();
      expect(DeviceRegistrationOutcomes.allowsAccountBootstrap('authSessionInvalidated')).assertFalse();
    });

    it('device_retry_backoff_policy', 0, () => {
      expect(DeviceRegistrationRetryPolicy.backoffBeforeAttempt(0)).assertEqual(0);
      expect(DeviceRegistrationRetryPolicy.backoffBeforeAttempt(1)).assertEqual(300);
      expect(DeviceRegistrationRetryPolicy.backoffBeforeAttempt(2)).assertEqual(600);
      expect(DeviceRegistrationRetryPolicy.maxAttempts).assertEqual(3);
    });

    it('bootstrap_dedupes_account', 0, async () => {
      const api = new FakeAIBootstrap();
      const boot = new AppBootstrapper(api);
      const ok1 = await boot.bootstrapAccountIfNeeded(5);
      const ok2 = await boot.bootstrapAccountIfNeeded(5);
      expect(ok1).assertTrue();
      expect(ok2).assertTrue();
      expect(api.calls).assertEqual(1);
    });

    it('bootstrap_401_aborts', 0, async () => {
      const api = new FakeAIBootstrap();
      api.failWith = new SupportNetworkError('http', 'unauthorized', 401, new BackendErrorInfo(40102, 'token_not_valid'));
      const boot = new AppBootstrapper(api);
      const ok = await boot.bootstrapAccountIfNeeded(8);
      expect(ok).assertFalse();
      expect(boot.hasBootstrapped(8)).assertFalse();
    });

    it('bootstrap_soft_fail_still_marks_done', 0, async () => {
      const api = new FakeAIBootstrap();
      api.failWith = new SupportNetworkError('http', 'server', 500, new BackendErrorInfo(50000, 'server'));
      const boot = new AppBootstrapper(api);
      const ok = await boot.bootstrapAccountIfNeeded(9);
      expect(ok).assertTrue();
      expect(boot.hasBootstrapped(9)).assertTrue();
    });
  });
}

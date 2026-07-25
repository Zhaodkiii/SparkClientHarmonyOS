import { describe, it, expect } from '@ohos/hypium';
import {
  AIAccountBootstrapGateway,
  AppBootstrapper,
  BootstrapOutcome
} from '../../../main/ets/App/AppBootstrapper';
import { SupportNetworkError, BackendErrorInfo } from '../../../main/ets/Projects/Core/Networking/SupportNetworkModels';

class CountingGateway extends AIAccountBootstrapGateway {
  calls: number = 0;
  outcome: BootstrapOutcome = new BootstrapOutcome();
  throwAuth: boolean = false;
  throwSeed: boolean = false;

  async prepareAccount(_accountId: number): Promise<BootstrapOutcome> {
    this.calls += 1;
    if (this.throwAuth) {
      throw SupportNetworkError.business(new BackendErrorInfo(40101, 'auth', undefined), 401, 'r');
    }
    if (this.throwSeed) {
      throw new Error('seed:json_parse:APIKeys.json');
    }
    return this.outcome;
  }
}

export default function appBootstrapperTest() {
  describe('AppBootstrapper', () => {
    it('reset_clears_dedupe', 0, async () => {
      const api = new CountingGateway();
      const boot = new AppBootstrapper(api);
      await boot.bootstrapAccountIfNeeded(1);
      boot.reset();
      await boot.bootstrapAccountIfNeeded(1);
      expect(api.calls).assertEqual(2);
    });

    it('different_accounts_bootstrap_separately', 0, async () => {
      const api = new CountingGateway();
      const boot = new AppBootstrapper(api);
      await boot.bootstrapAccountIfNeeded(1);
      await boot.bootstrapAccountIfNeeded(2);
      expect(api.calls).assertEqual(2);
    });

    it('auth_invalidation_aborts_prepared', 0, async () => {
      const api = new CountingGateway();
      api.throwAuth = true;
      const boot = new AppBootstrapper(api);
      const ok = await boot.bootstrapAccountIfNeeded(5);
      expect(ok).assertFalse();
      expect(boot.hasBootstrapped(5)).assertFalse();
    });

    it('degraded_still_completes', 0, async () => {
      const api = new CountingGateway();
      api.outcome.state = 'degraded';
      const boot = new AppBootstrapper(api);
      const ok = await boot.bootstrapAccountIfNeeded(6);
      expect(ok).assertTrue();
      expect(boot.hasBootstrapped(6)).assertTrue();
    });

    it('seed_failure_does_not_mark_bootstrapped', 0, async () => {
      const api = new CountingGateway();
      api.throwSeed = true;
      const boot = new AppBootstrapper(api);
      let threw = false;
      try {
        await boot.bootstrapAccountIfNeeded(7);
      } catch (_e) {
        threw = true;
      }
      expect(threw).assertTrue();
      expect(boot.hasBootstrapped(7)).assertFalse();
    });
  });
}

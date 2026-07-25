import { describe, it, expect } from '@ohos/hypium';
import { AIConfigSeedLoader, AISeedValidationError } from '../../../main/ets/Core/AI/Infrastructure/AIConfigSeedLoader';
import { AIConfigSchema } from '../../../main/ets/Core/AI/Infrastructure/AIConfigSchema';
import { MemoryAIConfigStore } from '../../../main/ets/Core/AI/Infrastructure/AIConfigStore';
import { AIKeyStore } from '../../../main/ets/Core/AI/Infrastructure/AIKeyStore';
import { AIConfigResolver } from '../../../main/ets/Core/AI/Application/AIConfigResolver';
import { AIConfigRepository, SeedJsonCache } from '../../../main/ets/Core/AI/Application/AIConfigRepository';
import { AIRuntimeSnapshotStore } from '../../../main/ets/Core/AI/Runtime/AIRuntimeSnapshotStore';
import { AccountSessionRuntime } from '../../../main/ets/App/AccountSessionRuntime';
import { SessionSnapshotStore } from '../../../main/ets/Projects/Features/Auth/Infrastructure/SessionSnapshotStore';
import { AIConfigAPI } from '../../../main/ets/Projects/Core/Networking/API/AI/AIConfigAPI';
import { SupportBackendConfiguration } from '../../../main/ets/Projects/Core/Networking/SupportBackendConfiguration';
import { SupportNetworkEngine } from '../../../main/ets/Projects/Core/Networking/SupportNetworkEngine';
import { MockNetworkTransport } from '../../../main/ets/Projects/Core/Networking/SupportNetworkTransport';
import { AuthTokenProvider } from '../../../main/ets/Projects/Core/Networking/AuthTokenProvider';
import { SecureTokenStore } from '../../../main/ets/Foundation/Security/SecureTokenStore';
import { ETagStore } from '../../../main/ets/Projects/Core/Networking/ETagStore';
import { DeviceCache } from '../../../main/ets/Projects/Core/Networking/Caching/DeviceCache';
import {
  LocalProvider,
  ProBootstrapSnapshot,
  ProScenarioBundle,
  ProScenarioModelRow,
  nowIso
} from '../../../main/ets/Core/AI/Domain/AIConfigModels';

const IOS_API_KEYS: string = JSON.stringify([
  {
    'name': 'OPENAI_API_KEY',
    'company': 'OPENAI',
    'key': '',
    'requestURL': 'https://api.openai.com/v1/chat/completions',
    'isEnabled': false
  },
  {
    'name': 'QWEN_API_KEY',
    'company': 'QWEN',
    'key': '',
    'requestURL': 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
    'isEnabled': false
  }
]);

const IOS_ALL_MODELS: string = JSON.stringify([
  {
    'name': 'gpt-test',
    'displayName': 'GPT Test',
    'company': 'OPENAI',
    'isEnabled': true,
    'supportsTextGen': true,
    'supportReasoningChange': true,
    'aiScenarios': ['chat', 'report_interpretation']
  },
  {
    'name': 'qwen-test',
    'displayName': 'Qwen Test',
    'company': 'QWEN',
    'isEnabled': true,
    'supportsText': true,
    'aiScenarios': ['chat']
  }
]);

function makeDummyApi(): AIConfigAPI {
  const transport = new MockNetworkTransport();
  const cache = DeviceCache.memoryOnly();
  const store = new SecureTokenStore('/tmp/ai-seed-api');
  const auth = new AuthTokenProvider(transport, 'https://api.example.com', store);
  const etag = new ETagStore('/tmp/ai-seed-api');
  const engine = new SupportNetworkEngine('https://api.example.com', transport, auth, etag, cache);
  const backend = new SupportBackendConfiguration(engine, cache);
  return new AIConfigAPI(backend);
}

function makeRepository(seed?: SeedJsonCache): AIConfigRepository {
  const store = new MemoryAIConfigStore();
  const keys = new AIKeyStore('/tmp/ai-seed-repo', true);
  const resolver = new AIConfigResolver();
  const runtime = new AIRuntimeSnapshotStore();
  const session = new AccountSessionRuntime(new SessionSnapshotStore('/tmp/ai-seed-session'));
  const repo = new AIConfigRepository(store, keys, makeDummyApi(), resolver, runtime, session);
  if (seed) {
    repo.setSeedJsonCache(seed);
  } else {
    repo.setSeedJsonCache(SeedJsonCache.fromIOSSource(IOS_API_KEYS, IOS_ALL_MODELS));
  }
  return repo;
}

function makeRemote(revision: string, withModels: boolean): ProBootstrapSnapshot {
  const remote = new ProBootstrapSnapshot();
  remote.revision = revision;
  if (!withModels) {
    return remote;
  }
  const bundle = new ProScenarioBundle();
  bundle.scenario = 'chat';
  bundle.defaultModel = 'pro-m';
  const row = new ProScenarioModelRow();
  row.name = 'pro-m';
  row.displayName = 'Pro M';
  row.company = 'PROCO';
  row.endpoint = 'https://example.com/v1';
  row.isDefault = true;
  row.apiKey = 'sk-should-not-persist';
  bundle.models = [row];
  remote.scenarios = [bundle];
  return remote;
}

class StubBootstrapOverride {
  next: ProBootstrapSnapshot = makeRemote('1', true);

  async bootstrap(_v: string): Promise<ProBootstrapSnapshot> {
    return this.next;
  }
}

export default function aiConfigSeedLifecycleTest() {
  describe('AIConfigSeedLifecycle', () => {
    it('parse_ios_source_maps_fields_and_bindings', 0, () => {
      const snap = AIConfigSeedLoader.parseIOSSourceBundle(IOS_API_KEYS, IOS_ALL_MODELS, 1001);
      expect(snap.providers.length).assertEqual(2);
      expect(snap.providers[0].id).assertEqual('seed:OPENAI');
      expect(snap.providers[0].requestUrl).assertEqual('https://api.openai.com/v1/chat/completions');
      expect(snap.providers[0].secretRef === undefined).assertTrue();
      expect(snap.models.length).assertEqual(2);
      expect(snap.models[0].capabilities.supportsText).assertTrue();
      expect(snap.models[0].capabilities.reasoningControllable).assertTrue();
      expect(snap.scenarioBindings.length > 0).assertTrue();
      expect(snap.seedVersion).assertEqual(AIConfigSchema.SEED_VERSION);
    });

    it('first_login_imports_ios_source_and_persists', 0, async () => {
      const repository = makeRepository();
      const result = await repository.ensureSeeded(1001);
      expect(result.status).assertEqual('seeded');
      const snapshot = await repository.loadSnapshot(1001);
      expect(snapshot.seedVersion).assertEqual(1);
      expect(snapshot.providers.length > 0).assertTrue();
      expect(snapshot.models.length > 0).assertTrue();
      expect(snapshot.scenarioBindings.length > 0).assertTrue();
      for (let i = 0; i < snapshot.providers.length; i++) {
        expect(snapshot.providers[i].secretRef === undefined).assertTrue();
      }
    });

    it('second_launch_does_not_overwrite_custom_provider', 0, async () => {
      const repository = makeRepository();
      await repository.ensureSeeded(1001);
      const snap = await repository.loadSnapshot(1001);
      const custom = new LocalProvider();
      custom.id = 'custom:test';
      custom.company = 'TEST';
      custom.name = 'Custom';
      custom.kind = 'api';
      custom.requestUrl = 'https://example.com/v1';
      custom.isEnabled = true;
      custom.source = 'custom';
      custom.updatedAt = nowIso();
      snap.providers.push(custom);
      await repository.save(1001, snap);
      const result = await repository.ensureSeeded(1001);
      expect(result.status).assertEqual('alreadySeeded');
      const loaded = await repository.loadSnapshot(1001);
      expect(loaded.providers.some((p: LocalProvider) => p.id === 'custom:test')).assertTrue();
    });

    it('invalid_source_rolls_back_without_seed_version', 0, async () => {
      const bad = SeedJsonCache.fromIOSSource('not-json', IOS_ALL_MODELS);
      const repository = makeRepository(bad);
      let threw = false;
      try {
        await repository.ensureSeeded(1001);
      } catch (err) {
        threw = true;
        expect(`${err}`.indexOf('seed') >= 0).assertTrue();
      }
      expect(threw).assertTrue();
      const snapshot = await repository.loadSnapshot(1001);
      expect(snapshot.seedVersion === undefined || snapshot.seedVersion === 0).assertTrue();
    });

    it('refresh_rejects_older_revision_and_empty_payload', 0, async () => {
      const repo = makeRepository();
      const stub = new StubBootstrapOverride();
      stub.next = makeRemote('2', true);
      repo.setBootstrapOverride(stub);
      await repo.ensureSeeded(42);
      await repo.buildRuntime(42);

      const ok = await repo.refreshRemote(42);
      expect(ok.state).assertEqual('remoteReady');

      stub.next = makeRemote('1', true);
      const older = await repo.refreshRemote(42);
      expect(older.state).assertEqual('degraded');
      expect(older.reason).assertEqual('older_revision');

      stub.next = makeRemote('3', false);
      const empty = await repo.refreshRemote(42);
      expect(empty.state).assertEqual('degraded');
      expect(empty.reason).assertEqual('empty_remote_payload');
      const snap = await repo.loadSnapshot(42);
      expect(snap.revision).assertEqual('2');
    });

    it('compare_revision_and_clear_api_keys', 0, () => {
      expect(AIConfigRepository.compareRevision('2', '1')).assertEqual(1);
      expect(AIConfigRepository.compareRevision('1', '2')).assertEqual(-1);
      expect(AIConfigRepository.compareRevision('2', '2')).assertEqual(0);
      const remote = makeRemote('9', true);
      AIConfigRepository.clearRemoteApiKeys(remote);
      expect(remote.scenarios[0].models[0].apiKey === undefined).assertTrue();
    });

    it('local_provider_placeholder_does_not_fail_seed', 0, () => {
      const keys = JSON.stringify([
        {
          'name': 'OPENAI_API_KEY',
          'company': 'OPENAI',
          'key': '',
          'requestURL': 'https://api.openai.com/v1/chat/completions',
          'isEnabled': false
        },
        {
          'name': 'LOCAL',
          'company': 'LOCAL',
          'key': 'LOCAL',
          'requestURL': 'LOCAL',
          'isEnabled': false
        }
      ]);
      const models = JSON.stringify([{
        'name': 'gpt-test',
        'company': 'OPENAI',
        'supportsText': true,
        'aiScenarios': ['chat']
      }]);
      const snap = AIConfigSeedLoader.parseIOSSourceBundle(keys, models, 1);
      expect(snap.providers.length).assertEqual(2);
      const local = snap.providers[1];
      expect(local.kind).assertEqual('local');
      expect(local.requestUrl === undefined).assertTrue();
      expect(local.secretRef === undefined).assertTrue();
    });

    it('missing_provider_company_throws_validation', 0, () => {
      const models = JSON.stringify([{
        'name': 'orphan',
        'company': 'MISSING',
        'aiScenarios': ['chat'],
        'supportsText': true
      }]);
      let code = '';
      try {
        AIConfigSeedLoader.parseIOSSourceBundle(IOS_API_KEYS, models, 1);
      } catch (err) {
        if (err instanceof AISeedValidationError) {
          code = err.code;
        }
      }
      expect(code).assertEqual('model_provider_missing');
    });
  });
}

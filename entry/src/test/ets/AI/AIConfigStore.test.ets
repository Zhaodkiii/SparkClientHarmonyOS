import { describe, it, expect } from '@ohos/hypium';
import { MemoryAIConfigStore } from '../../../main/ets/Core/AI/Infrastructure/AIConfigStore';
import { AIConfigSeedLoader } from '../../../main/ets/Core/AI/Infrastructure/AIConfigSeedLoader';
import { AIKeyStore } from '../../../main/ets/Core/AI/Infrastructure/AIKeyStore';
import { ProOverlayStore } from '../../../main/ets/Core/AI/Infrastructure/ProOverlayStore';
import { ProOverlayMaterializer } from '../../../main/ets/Core/AI/Application/ProOverlayMaterializer';
import {
  AIScenario,
  LocalSmallTask,
  ProBootstrapSnapshot,
  ProScenarioBundle,
  ProScenarioModelRow
} from '../../../main/ets/Core/AI/Domain/AIConfigModels';
import { AIConfigSchema } from '../../../main/ets/Core/AI/Infrastructure/AIConfigSchema';
import { ProviderModelCatalogService } from '../../../main/ets/Projects/Features/AISettings/Application/ProviderModelCatalogService';

const PROVIDERS_JSON: string =
  '[{"id":"OPENAI","name":"OPENAI_API_KEY","company":"OPENAI","requestUrl":"https://api.openai.com/v1/chat/completions","isEnabled":false,"position":0,"source":"localSeed"}]';
const MODELS_JSON: string =
  '[{"id":"OPENAI:gpt-test","name":"gpt-test","displayName":"GPT Test","providerId":"OPENAI","capabilities":{"supportsText":true},"isEnabled":true,"source":"localSeed"}]';
const BINDINGS_JSON: string =
  '[{"scenario":"chat","modelId":"OPENAI:gpt-test","isDefault":true,"temperature":0.68,"maxTokens":12800,"enabled":true,"source":"localSeed"}]';

function makeRemote(): ProBootstrapSnapshot {
  const remote = new ProBootstrapSnapshot();
  remote.revision = 'r-pro';
  const bundle = new ProScenarioBundle();
  bundle.scenario = 'chat';
  bundle.defaultModel = 'pro-m';
  const row = new ProScenarioModelRow();
  row.name = 'pro-m';
  row.displayName = 'Pro M';
  row.company = 'DEEPSEEK';
  row.endpoint = 'https://example.com/v1/chat/completions';
  row.isDefault = true;
  row.capabilities.supportsText = true;
  bundle.models.push(row);
  remote.scenarios.push(bundle);
  return remote;
}

export default function aiConfigStoreTest() {
  describe('AIConfigStore', () => {
    it('seed_and_account_isolation', 0, async () => {
      const store = new MemoryAIConfigStore();
      const a1 = AIConfigSeedLoader.parseSeedBundle(
        PROVIDERS_JSON, MODELS_JSON, BINDINGS_JSON, '[]',
        '{"defaultSource":"auto","allowNetwork":true,"allowLocalModel":true}', 1
      );
      const a2 = AIConfigSeedLoader.parseSeedBundle(
        PROVIDERS_JSON, MODELS_JSON, BINDINGS_JSON, '[]',
        '{"defaultSource":"local","allowNetwork":false,"allowLocalModel":true}', 2
      );
      await store.saveLocal(1, a1);
      await store.saveLocal(2, a2);
      const loaded1 = await store.load(1);
      const loaded2 = await store.load(2);
      expect(loaded1 !== undefined).assertTrue();
      expect(loaded2 !== undefined).assertTrue();
      expect(loaded1!.accountId).assertEqual(1);
      expect(loaded2!.preferences.defaultSource).assertEqual('local');
      expect(loaded1!.providers.length).assertEqual(1);
      expect(loaded1!.scenarioBindings[0].scenario).assertEqual(AIScenario.CHAT);
      expect(loaded1!.seedVersion).assertEqual(AIConfigSchema.SEED_VERSION);
    });

    it('key_store_memory_no_plaintext_in_snapshot', 0, async () => {
      const keys = new AIKeyStore('/tmp/ai-key-test', true);
      const ref = await keys.put(9, 'OPENAI', 'sk-secret-value');
      expect(ref.indexOf('ai-key:9:OPENAI') >= 0).assertTrue();
      expect(await keys.get(ref)).assertEqual('sk-secret-value');
      const store = new MemoryAIConfigStore();
      const snap = AIConfigSeedLoader.parseSeedBundle(PROVIDERS_JSON, MODELS_JSON, BINDINGS_JSON, '[]', '{}', 9);
      snap.providers[0].secretRef = ref;
      await store.saveLocal(9, snap);
      const loaded = await store.load(9);
      expect(JSON.stringify(loaded).indexOf('sk-secret-value') < 0).assertTrue();
      await keys.deleteAccount(9);
      expect((await keys.get(ref)) === undefined).assertTrue();
    });

    it('publish_pro_overlay_meta_does_not_write_pro_providers', 0, async () => {
      const store = new MemoryAIConfigStore();
      const snap = AIConfigSeedLoader.parseSeedBundle(PROVIDERS_JSON, MODELS_JSON, BINDINGS_JSON, '[]', '{}', 3);
      const t = new LocalSmallTask();
      t.code = 'local_only';
      t.name = 'Local';
      t.prompt = 'p';
      t.source = 'localUser';
      snap.smallTasks.push(t);
      await store.saveLocal(3, snap);

      const remote = makeRemote();
      await store.publishProOverlayMeta(3, remote, 'etag-1');
      const loaded = await store.load(3);
      expect(loaded!.syncState).assertEqual('remoteReady');
      expect(loaded!.revision).assertEqual('r-pro');
      expect(loaded!.providers.length).assertEqual(1);
      expect(loaded!.providers[0].id.indexOf('pro:') < 0).assertTrue();
      let hasProProvider = false;
      for (let i = 0; i < loaded!.providers.length; i++) {
        if (loaded!.providers[i].source === 'pro') {
          hasProProvider = true;
        }
      }
      expect(hasProProvider).assertFalse();
      let hasLocal = false;
      for (let i = 0; i < loaded!.smallTasks.length; i++) {
        if (loaded!.smallTasks[i].code === 'local_only') {
          hasLocal = true;
        }
      }
      expect(hasLocal).assertTrue();

      const overlay = new ProOverlayStore();
      const refs = new Map<string, string>();
      refs.set('pro:DEEPSEEK', 'ai-pro:3:pro:DEEPSEEK');
      overlay.set(3, remote, refs, 'etag-1');
      const fragment = ProOverlayMaterializer.materialize(3, remote, refs);
      expect(fragment.providers.length).assertEqual(1);
      expect(fragment.providers[0].id).assertEqual('pro:DEEPSEEK');
      const creds = ProviderModelCatalogService.localCredentialProviders(loaded!);
      expect(creds.length).assertEqual(1);
      expect(creds[0].providerId.indexOf('pro:') < 0).assertTrue();
      const merged = ProOverlayMaterializer.merge(loaded!, fragment);
      expect(merged.providers.length).assertEqual(2);
    });
  });
}

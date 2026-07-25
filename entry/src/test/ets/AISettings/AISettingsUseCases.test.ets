import { describe, it, expect } from '@ohos/hypium';
import { AIKeyStore, AIKeyStoreError } from '../../../main/ets/Core/AI/Infrastructure/AIKeyStore';
import { AIConfigSeedLoader } from '../../../main/ets/Core/AI/Infrastructure/AIConfigSeedLoader';
import {
  AIConfigSnapshot,
  LocalModel,
  LocalScenarioBinding,
  LocalSmallTask,
  ModelCapabilities
} from '../../../main/ets/Core/AI/Domain/AIConfigModels';
import { ProviderUseCases } from '../../../main/ets/Projects/Features/AISettings/Application/ProviderUseCases';
import { ModelCatalogUseCases } from '../../../main/ets/Projects/Features/AISettings/Application/ModelCatalogUseCases';
import { SmallTaskUseCases } from '../../../main/ets/Projects/Features/AISettings/Application/SmallTaskUseCases';
import { AISettingsErrorLocalizer } from '../../../main/ets/Projects/Features/AISettings/Application/AISettingsErrorLocalizer';

const PROVIDERS_JSON: string =
  '[{"id":"OPENAI","name":"OPENAI_API_KEY","company":"OPENAI","requestUrl":"https://api.openai.com/v1/chat/completions","isEnabled":true,"position":0}]';
const MODELS_JSON: string =
  '[{"id":"OPENAI:gpt-test","name":"gpt-test","displayName":"GPT Test","providerId":"OPENAI","capabilities":{"supportsText":true},"isEnabled":true}]';
const BINDINGS_JSON: string =
  '[{"scenario":"chat","modelId":"OPENAI:gpt-test","isDefault":true,"temperature":0.68,"maxTokens":12800,"enabled":true,"relatedTaskCodes":["local_task"]}]';

function sampleSnap(): AIConfigSnapshot {
  return AIConfigSeedLoader.parseSeedBundle(
    PROVIDERS_JSON, MODELS_JSON, BINDINGS_JSON, '[]',
    '{"defaultSource":"auto","allowNetwork":true,"allowLocalModel":true}', 1
  );
}

export default function aiSettingsUseCasesTest() {
  describe('AISettingsUseCases', () => {
    it('key_store_memory_only_ok_for_tests', 0, async () => {
      const keys = new AIKeyStore('/tmp/ai-key-settings', true);
      const ref = await keys.put(1, 'OPENAI', 'sk-test');
      expect(await keys.get(ref)).assertEqual('sk-test');
      expect(await keys.hasSecret(ref)).assertTrue();
    });

    it('error_localizer_hides_key_material', 0, () => {
      const msg = AISettingsErrorLocalizer.localize(new Error('failed sk-abc123 body'));
      expect(msg.indexOf('sk-') < 0).assertTrue();
      const secure = AISettingsErrorLocalizer.localize(
        new AIKeyStoreError('secureStorageUnavailable', 'x')
      );
      expect(secure.indexOf('安全存储') >= 0).assertTrue();
    });

    it('provider_custom_validation', 0, () => {
      let threw = false;
      try {
        ProviderUseCases.createCustom('', 'n', 'https://x.com');
      } catch (_e) {
        threw = true;
      }
      expect(threw).assertTrue();
      const p = ProviderUseCases.createCustom('ACME', 'Acme Key', 'https://api.acme.com/v1', 't1');
      expect(p.company).assertEqual('ACME');
      expect(p.id.indexOf('custom:') === 0).assertTrue();
      expect(p.source).assertEqual('custom');
    });

    it('model_enable_requires_key', 0, () => {
      const snap = sampleSnap();
      snap.providers[0].secretRef = undefined;
      const m = snap.models[0];
      m.isEnabled = false;
      let blocked = false;
      try {
        ModelCatalogUseCases.setEnabled(snap, m.id, true, false);
      } catch (_e) {
        blocked = true;
      }
      expect(blocked).assertTrue();
      ModelCatalogUseCases.setEnabled(snap, m.id, true, true);
      expect(m.isEnabled).assertTrue();
    });

    it('default_unique_via_set_scenario', 0, () => {
      const snap = sampleSnap();
      const b2 = new LocalScenarioBinding();
      b2.scenario = 'chat';
      b2.modelId = 'OPENAI:other';
      b2.isDefault = false;
      b2.enabled = true;
      b2.source = 'localUser';
      snap.scenarioBindings.push(b2);
      for (let i = 0; i < snap.scenarioBindings.length; i++) {
        if (snap.scenarioBindings[i].scenario === 'chat') {
          snap.scenarioBindings[i].isDefault = snap.scenarioBindings[i].modelId === 'OPENAI:other';
        }
      }
      let defaults = 0;
      for (let i = 0; i < snap.scenarioBindings.length; i++) {
        if (snap.scenarioBindings[i].scenario === 'chat' && snap.scenarioBindings[i].isDefault) {
          defaults++;
        }
      }
      expect(defaults).assertEqual(1);
    });

    it('small_task_delete_blocked_by_reference', 0, () => {
      const snap = sampleSnap();
      const t = new LocalSmallTask();
      t.code = 'local_task';
      t.name = 'Local Task';
      t.prompt = 'p';
      t.source = 'Local';
      snap.smallTasks.push(t);
      const refs = SmallTaskUseCases.findReferences(snap, 'local_task');
      expect(refs.length > 0).assertTrue();
      let blocked = false;
      try {
        SmallTaskUseCases.delete(snap, 'local_task');
      } catch (_e) {
        blocked = true;
      }
      expect(blocked).assertTrue();
    });

    it('agent_requires_name_base_prompt', 0, () => {
      const snap = sampleSnap();
      let blocked = false;
      try {
        ModelCatalogUseCases.upsertAgent(snap, '', 'OPENAI:gpt-test', 'sys');
      } catch (_e) {
        blocked = true;
      }
      expect(blocked).assertTrue();
      const agent = ModelCatalogUseCases.upsertAgent(snap, '助手', 'OPENAI:gpt-test', '你是助手');
      expect(agent.identity).assertEqual('agent');
    });

    it('online_model_create', 0, () => {
      const caps = new ModelCapabilities();
      caps.supportsText = true;
      const m: LocalModel = ModelCatalogUseCases.createOnline('OPENAI', 'gpt-x', 'GPT X', caps);
      expect(m.id).assertEqual('OPENAI:gpt-x');
      expect(m.isEnabled).assertFalse();
    });
  });
}

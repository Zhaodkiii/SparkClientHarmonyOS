import { describe, it, expect } from '@ohos/hypium';
import { AIConfigResolver, ResolveOptions } from '../../../main/ets/Core/AI/Application/AIConfigResolver';
import { AIConfigSeedLoader } from '../../../main/ets/Core/AI/Infrastructure/AIConfigSeedLoader';
import { ProOverlayMaterializer } from '../../../main/ets/Core/AI/Application/ProOverlayMaterializer';
import {
  AIScenario,
  ProBootstrapSnapshot,
  ProScenarioBundle,
  ProScenarioModelRow
} from '../../../main/ets/Core/AI/Domain/AIConfigModels';
import { MemoryAIConfigStore } from '../../../main/ets/Core/AI/Infrastructure/AIConfigStore';

const PROVIDERS =
  '[{"id":"OPENAI","name":"OPENAI","company":"OPENAI","requestUrl":"https://api.openai.com/v1/chat/completions","isEnabled":true,"position":0,"source":"localSeed"}]';
const MODELS =
  '[{"id":"OPENAI:local-m","name":"local-m","displayName":"Local M","providerId":"OPENAI","capabilities":{"supportsText":true},"isEnabled":true,"source":"localSeed"}]';
const BINDINGS =
  '[{"scenario":"chat","modelId":"OPENAI:local-m","isDefault":true,"temperature":0.5,"maxTokens":1000,"enabled":true,"source":"localSeed"},{"scenario":"report_interpretation","modelId":"OPENAI:local-m","isDefault":true,"enabled":true,"source":"localSeed"},{"scenario":"medical_exam_plan_generation","modelId":"OPENAI:local-m","isDefault":true,"enabled":true,"source":"localSeed"}]';

function makeRemote(revision: string): ProBootstrapSnapshot {
  const remote = new ProBootstrapSnapshot();
  remote.revision = revision;
  const bundle = new ProScenarioBundle();
  bundle.scenario = 'chat';
  bundle.defaultModel = 'pro-m';
  const row = new ProScenarioModelRow();
  row.name = 'pro-m';
  row.displayName = 'Pro';
  row.company = 'OPENAI';
  row.endpoint = 'https://pro.example/v1/chat/completions';
  row.isDefault = true;
  row.capabilities.supportsText = true;
  bundle.models.push(row);
  remote.scenarios.push(bundle);
  return remote;
}

export default function aiConfigResolverTest() {
  describe('AIConfigResolver', () => {
    it('resolves_local_default_for_chat', 0, () => {
      const snap = AIConfigSeedLoader.parseSeedBundle(PROVIDERS, MODELS, BINDINGS, '[]', '{}', 1);
      snap.providers[0].isEnabled = true;
      const resolver = new AIConfigResolver();
      const cfg = resolver.resolve(snap, AIScenario.CHAT);
      expect(cfg.modelName).assertEqual('local-m');
      expect(cfg.source).assertEqual('local');
      expect(cfg.isReady).assertTrue();
    });

    it('keeps_exam_plan_independent_from_report', 0, () => {
      const snap = AIConfigSeedLoader.parseSeedBundle(PROVIDERS, MODELS, BINDINGS, '[]', '{}', 1);
      snap.providers[0].isEnabled = true;
      const resolver = new AIConfigResolver();
      const report = resolver.resolve(snap, AIScenario.REPORT_INTERPRETATION);
      const exam = resolver.resolve(snap, AIScenario.MEDICAL_EXAM_PLAN_GENERATION);
      expect(report.scenario).assertEqual(AIScenario.REPORT_INTERPRETATION);
      expect(exam.scenario).assertEqual(AIScenario.MEDICAL_EXAM_PLAN_GENERATION);
    });

    it('prefers_local_over_pro_when_default_source_local', 0, async () => {
      const store = new MemoryAIConfigStore();
      const snap = AIConfigSeedLoader.parseSeedBundle(PROVIDERS, MODELS, BINDINGS, '[]',
        '{"defaultSource":"local","allowNetwork":true}', 2);
      snap.providers[0].isEnabled = true;
      await store.saveLocal(2, snap);
      const remote = makeRemote('r1');
      await store.publishProOverlayMeta(2, remote);
      const loaded = await store.load(2);
      loaded!.preferences.defaultSource = 'local';
      const refs = new Map<string, string>();
      refs.set('pro:OPENAI', 'ref');
      const fragment = ProOverlayMaterializer.materialize(2, remote, refs);
      const merged = ProOverlayMaterializer.merge(loaded!, fragment);
      const resolver = new AIConfigResolver();
      const cfg = resolver.resolve(merged, AIScenario.CHAT);
      expect(cfg.source).assertEqual('local');
      // 本地目录不含 Pro
      expect(loaded!.providers.some((p) => p.source === 'pro')).assertFalse();
    });

    it('offline_skips_pro_candidates', 0, async () => {
      const store = new MemoryAIConfigStore();
      const snap = AIConfigSeedLoader.parseSeedBundle(PROVIDERS, MODELS, BINDINGS, '[]',
        '{"defaultSource":"auto","allowNetwork":false}', 3);
      snap.providers[0].isEnabled = true;
      await store.saveLocal(3, snap);
      const remote = makeRemote('r2');
      await store.publishProOverlayMeta(3, remote);
      const loaded = await store.load(3);
      loaded!.preferences.allowNetwork = false;
      const refs = new Map<string, string>();
      const fragment = ProOverlayMaterializer.materialize(3, remote, refs);
      const merged = ProOverlayMaterializer.merge(loaded!, fragment);
      const resolver = new AIConfigResolver();
      const runtime = resolver.buildRuntime(merged);
      const list = runtime.scenarios.get(AIScenario.CHAT) ?? [];
      for (let i = 0; i < list.length; i++) {
        expect(list[i].source !== 'pro').assertTrue();
      }
    });
  });
}

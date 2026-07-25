import { describe, it, expect } from '@ohos/hypium';
import { AIConfigSeedLoader } from '../../../main/ets/Core/AI/Infrastructure/AIConfigSeedLoader';
import { ProOverlayMaterializer } from '../../../main/ets/Core/AI/Application/ProOverlayMaterializer';
import {
  LocalProvider,
  ProBootstrapSnapshot,
  ProScenarioBundle,
  ProScenarioModelRow
} from '../../../main/ets/Core/AI/Domain/AIConfigModels';
import { ProviderModelCatalogService } from '../../../main/ets/Projects/Features/AISettings/Application/ProviderModelCatalogService';

export default function providerCatalogOverlayTest() {
  describe('ProviderCatalogOverlayBoundary', () => {
    it('local_credentials_exclude_pro_providers', 0, () => {
      const snap = AIConfigSeedLoader.parseSeedBundle(
        '[{"id":"seed:OPENAI","name":"OPENAI","company":"OPENAI","kind":"api","requestUrl":"https://api.openai.com/v1/chat/completions","isEnabled":true,"position":0,"source":"localSeed"}]',
        '[{"id":"seed:OPENAI:gpt","name":"gpt","displayName":"GPT","providerId":"seed:OPENAI","capabilities":{"supportsText":true},"isEnabled":true,"source":"localSeed"}]',
        '[]',
        '[]',
        '{}',
        1
      );
      const pro = new LocalProvider();
      pro.id = 'pro:DEEPSEEK';
      pro.name = 'DEEPSEEK';
      pro.company = 'DEEPSEEK';
      pro.kind = 'api';
      pro.source = 'pro';
      pro.isEnabled = true;
      snap.providers.push(pro);

      const rows = ProviderModelCatalogService.localCredentialProviders(snap);
      expect(rows.length).assertEqual(1);
      expect(rows[0].providerId).assertEqual('seed:OPENAI');
      expect(ProviderModelCatalogService.isEditableApiCredentialProvider(pro)).assertFalse();
    });

    it('visible_models_merged_shows_pro_readonly_filter', 0, () => {
      const local = AIConfigSeedLoader.parseSeedBundle(
        '[{"id":"seed:OPENAI","name":"OPENAI","company":"OPENAI","kind":"api","isEnabled":true,"position":0,"source":"localSeed"}]',
        '[{"id":"seed:OPENAI:gpt","name":"gpt","displayName":"GPT","providerId":"seed:OPENAI","capabilities":{"supportsText":true},"isEnabled":true,"source":"localSeed"}]',
        '[]',
        '[]',
        '{}',
        1
      );
      const remote = new ProBootstrapSnapshot();
      remote.revision = 'r1';
      const bundle = new ProScenarioBundle();
      bundle.scenario = 'chat';
      bundle.defaultModel = 'deep';
      const row = new ProScenarioModelRow();
      row.name = 'deep';
      row.displayName = 'DeepSeek';
      row.company = 'DEEPSEEK';
      row.isDefault = true;
      row.capabilities.supportsText = true;
      bundle.models.push(row);
      remote.scenarios.push(bundle);
      const fragment = ProOverlayMaterializer.materialize(1, remote, new Map());
      const proRows = ProviderModelCatalogService.visibleModelsMerged(local, fragment, 'pro', '');
      expect(proRows.length).assertEqual(1);
      expect(proRows[0].source).assertEqual('pro');
      const all = ProviderModelCatalogService.visibleModelsMerged(local, fragment, 'all', '');
      expect(all.length).assertEqual(2);
    });
  });
}

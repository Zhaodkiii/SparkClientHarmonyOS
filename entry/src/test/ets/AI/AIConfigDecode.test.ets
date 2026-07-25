import { describe, it, expect } from '@ohos/hypium';
import { AIConfigDecode } from '../../../main/ets/Core/AI/Domain/AIConfigDecode';
import { AIScenario } from '../../../main/ets/Core/AI/Domain/AIConfigModels';

export default function aiConfigDecodeTest() {
  describe('AIConfigDecode', () => {
    it('decodes_non_pro_empty_scenarios_with_trial_snake', 0, () => {
      const data = {
        'revision': '2026-01-01T00:00:00Z',
        'scenarios': {},
        'smallTasks': [],
        'trial_status': { 'status': 'none', 'is_active': false },
        'trial_message': 'not pro'
      };
      const snap = AIConfigDecode.decodeBootstrap(data);
      expect(snap.revision).assertEqual('2026-01-01T00:00:00Z');
      expect(snap.scenarios.length).assertEqual(0);
      expect(snap.trialMessage).assertEqual('not pro');
      expect(snap.trialStatus !== undefined).assertTrue();
      expect(snap.trialStatus!.isActive).assertFalse();
    });

    it('decodes_pro_bundle_snake_and_camel_mix', 0, () => {
      const data = {
        'revision': 'rev-1',
        'scenarios': {
          'chat': {
            'default_model': 'gpt-x',
            'models': [{
              'name': 'gpt-x',
              'display_name': 'GPT X',
              'identity': 'model',
              'company': 'OPENAI',
              'endpoint': 'https://example.com/v1/chat/completions',
              'api_key': 'secret-should-not-log',
              'supports_text': true,
              'supportsToolUse': true,
              'is_default': true,
              'temperature': 0.5,
              'max_tokens': 2048,
              'systemProvision': 'sys',
              'relatedTaskCodes': ['t1'],
              'unknownFutureField': 123
            }]
          },
          'totally_unknown_scenario': {
            'default_model': '',
            'models': []
          }
        },
        'smallTasks': [{
          'code': 't1',
          'name': 'Task',
          'prompt': 'do it',
          'tool_list': ['a'],
          'is_deleted': false
        }]
      };
      const snap = AIConfigDecode.decodeBootstrap(data);
      expect(snap.scenarios.length).assertEqual(2);
      let chat = snap.scenarios[0];
      for (let i = 0; i < snap.scenarios.length; i++) {
        if (snap.scenarios[i].scenario === 'chat') {
          chat = snap.scenarios[i];
          break;
        }
      }
      expect(chat.scenario).assertEqual('chat');
      expect(chat.defaultModel).assertEqual('gpt-x');
      expect(chat.models.length).assertEqual(1);
      expect(chat.models[0].capabilities.supportsText).assertTrue();
      expect(chat.models[0].capabilities.supportsToolUse).assertTrue();
      expect(chat.models[0].apiKey).assertEqual('secret-should-not-log');
      expect(chat.models[0].maxTokens).assertEqual(2048);
      expect(snap.smallTasks.length).assertEqual(1);
      expect(snap.smallTasks[0].code).assertEqual('t1');
      expect(AIConfigDecode.lastUnknownScenarios.indexOf('totally_unknown_scenario') >= 0).assertTrue();
    });

    it('decodes_array_shaped_scenarios_compat', 0, () => {
      const data = {
        'revision': 'r2',
        'scenarios': {
          'report_interpretation': [{
            'name': 'm1',
            'displayName': 'M1',
            'company': 'X',
            'supports_text': true,
            'isDefault': true
          }]
        },
        'smallTasks': []
      };
      const snap = AIConfigDecode.decodeBootstrap(data);
      expect(snap.scenarios.length).assertEqual(1);
      expect(snap.scenarios[0].defaultModel).assertEqual('m1');
      expect(AIScenario.isKnown('report_interpretation')).assertTrue();
      expect(AIScenario.isKnown('medical_exam_plan_generation')).assertTrue();
      expect(AIScenario.isKnown('generalChat')).assertFalse();
    });

    it('scenario_enum_has_19_keys', 0, () => {
      expect(AIScenario.allKnown().length).assertEqual(19);
    });
  });
}

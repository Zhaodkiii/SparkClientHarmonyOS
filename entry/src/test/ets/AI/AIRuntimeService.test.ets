import { describe, it, expect } from '@ohos/hypium';
import { AIConfigResolver } from '../../../main/ets/Core/AI/Application/AIConfigResolver';
import { AIConfigSeedLoader } from '../../../main/ets/Core/AI/Infrastructure/AIConfigSeedLoader';
import { AIRuntimeSnapshotStore } from '../../../main/ets/Core/AI/Runtime/AIRuntimeSnapshotStore';
import { AIRuntimeService } from '../../../main/ets/Core/AI/Runtime/AIRuntimeService';
import { AIKeyStore } from '../../../main/ets/Core/AI/Infrastructure/AIKeyStore';
import { AccountSessionRuntime } from '../../../main/ets/App/AccountSessionRuntime';
import { SessionSnapshotStore } from '../../../main/ets/Projects/Features/Auth/Infrastructure/SessionSnapshotStore';
import {
  AIScenario,
  AIRuntimeMessage,
  AIRuntimeTextRequest,
  AIResolvedConfig,
  AIRuntimeResponse,
  AIRuntimeToolDefinition,
  AIRuntimeEvent
} from '../../../main/ets/Core/AI/Domain/AIConfigModels';
import { AIProviderAdapter } from '../../../main/ets/Core/AI/Runtime/AIProviderAdapter';
import { ChatOrchestrator } from '../../../main/ets/Core/AI/Runtime/ChatOrchestrator';
import { ChatOrchestratorInferenceOptions } from '../../../main/ets/Core/AI/Runtime/ChatOrchestratorInferenceOptions';

class MockRemoteAdapter extends AIProviderAdapter {
  readonly providerKind: string = 'mock';
  lastConfig?: AIResolvedConfig;
  lastRequest?: AIRuntimeTextRequest;

  cancel(_requestId: string): void {
  }

  async send(request: AIRuntimeTextRequest, config: AIResolvedConfig): Promise<AIRuntimeResponse> {
    this.lastConfig = config;
    this.lastRequest = request;
    const r = new AIRuntimeResponse();
    r.requestId = request.requestId;
    r.text = `ok:${config.scenario}:${config.modelName}`;
    r.modelId = config.modelId;
    r.modelName = config.modelName;
    r.source = config.source;
    r.finishReason = 'stop';
    r.createdAt = new Date().toISOString();
    return r;
  }
}

export default function aiRuntimeServiceTest() {
  describe('AIRuntimeService', () => {
    it('routes_report_exam_and_small_task_scenarios', 0, async () => {
      const providers =
        '[{"id":"OPENAI","name":"OPENAI","company":"OPENAI","requestUrl":"https://api.openai.com/v1/chat/completions","isEnabled":true,"position":0,"source":"localSeed"}]';
      const models =
        '[{"id":"OPENAI:m1","name":"m1","displayName":"M1","providerId":"OPENAI","capabilities":{"supportsText":true,"supportsToolUse":true},"isEnabled":true}]';
      const bindings =
        '[{"scenario":"report_interpretation","modelId":"OPENAI:m1","isDefault":true,"enabled":true,"source":"localSeed"},{"scenario":"medical_exam_plan_generation","modelId":"OPENAI:m1","isDefault":true,"enabled":true,"source":"localSeed"},{"scenario":"chat","modelId":"OPENAI:m1","isDefault":true,"enabled":true,"source":"localSeed"}]';
      const snap = AIConfigSeedLoader.parseSeedBundle(providers, models, bindings, '[]', '{}', 7);
      snap.providers[0].isEnabled = true;
      const resolver = new AIConfigResolver();
      const runtime = resolver.buildRuntime(snap);
      const store = new AIRuntimeSnapshotStore();
      store.publish(runtime);
      const session = new AccountSessionRuntime(new SessionSnapshotStore('/tmp/ai-rt-test'));
      await session.activateUser(7);
      const mock = new MockRemoteAdapter();
      const keys = new AIKeyStore('/tmp/ai-rt-keys', true);
      const svc = new AIRuntimeService(store, keys, session, mock);

      const req1 = new AIRuntimeTextRequest();
      req1.requestId = 'r1';
      req1.accountId = 7;
      req1.scenario = AIScenario.REPORT_INTERPRETATION;
      const msg = new AIRuntimeMessage();
      msg.role = 'user';
      msg.content = '解释报告';
      req1.messages = [msg];
      const res1 = await svc.generateText(req1);
      expect(res1.errorCode === undefined).assertTrue();
      expect(res1.text.indexOf('report_interpretation') >= 0).assertTrue();

      const req2 = new AIRuntimeTextRequest();
      req2.requestId = 'r2';
      req2.accountId = 7;
      req2.scenario = AIScenario.MEDICAL_EXAM_PLAN_GENERATION;
      req2.messages = [msg];
      const res2 = await svc.generateText(req2);
      expect(res2.text.indexOf('medical_exam_plan_generation') >= 0).assertTrue();

      const req3 = new AIRuntimeTextRequest();
      req3.requestId = 'r3';
      req3.accountId = 7;
      req3.scenario = AIScenario.CHAT;
      const taskMsg = new AIRuntimeMessage();
      taskMsg.role = 'user';
      taskMsg.content = 'small-task';
      req3.messages = [taskMsg];
      const res3 = await svc.generateText(req3);
      expect(res3.errorCode === undefined).assertTrue();
    });

    it('preferred_model_is_exact_match_only', 0, async () => {
      const providers =
        '[{"id":"OPENAI","name":"OPENAI","company":"OPENAI","requestUrl":"https://api.openai.com/v1/chat/completions","isEnabled":true,"position":0,"source":"localSeed"}]';
      const models =
        '[{"id":"OPENAI:m1","name":"m1","displayName":"M1","providerId":"OPENAI","capabilities":{"supportsText":true},"isEnabled":true}]';
      const bindings =
        '[{"scenario":"chat","modelId":"OPENAI:m1","isDefault":true,"enabled":true,"source":"localSeed"}]';
      const snap = AIConfigSeedLoader.parseSeedBundle(providers, models, bindings, '[]', '{}', 8);
      snap.providers[0].isEnabled = true;
      const runtime = new AIConfigResolver().buildRuntime(snap);
      const store = new AIRuntimeSnapshotStore();
      store.publish(runtime);
      const session = new AccountSessionRuntime(new SessionSnapshotStore('/tmp/ai-rt-test2'));
      await session.activateUser(8);
      const mock = new MockRemoteAdapter();
      const svc = new AIRuntimeService(store, new AIKeyStore('/tmp/ai-rt-keys2', true), session, mock);

      const msg = new AIRuntimeMessage();
      msg.role = 'user';
      msg.content = 'hi';

      const miss = new AIRuntimeTextRequest();
      miss.requestId = 'miss';
      miss.accountId = 8;
      miss.scenario = AIScenario.CHAT;
      miss.preferredModelName = 'm'; // 旧 fuzzy 会误命中 m1
      miss.messages = [msg];
      const missRes = await svc.generateText(miss);
      expect(missRes.errorCode === 'noAvailableModel').assertTrue();

      const hit = new AIRuntimeTextRequest();
      hit.requestId = 'hit';
      hit.accountId = 8;
      hit.scenario = AIScenario.CHAT;
      hit.preferredModelName = 'm1';
      hit.messages = [msg];
      const hitRes = await svc.generateText(hit);
      expect(hitRes.errorCode === undefined).assertTrue();
    });

    it('tools_degrade_when_capability_false', 0, async () => {
      const providers =
        '[{"id":"OPENAI","name":"OPENAI","company":"OPENAI","requestUrl":"https://api.openai.com/v1/chat/completions","isEnabled":true,"position":0,"source":"localSeed"}]';
      const models =
        '[{"id":"OPENAI:m1","name":"m1","displayName":"M1","providerId":"OPENAI","capabilities":{"supportsText":true,"supportsToolUse":false},"isEnabled":true}]';
      const bindings =
        '[{"scenario":"chat","modelId":"OPENAI:m1","isDefault":true,"enabled":true,"source":"localSeed"}]';
      const snap = AIConfigSeedLoader.parseSeedBundle(providers, models, bindings, '[]', '{}', 9);
      snap.providers[0].isEnabled = true;
      const runtime = new AIConfigResolver().buildRuntime(snap);
      const store = new AIRuntimeSnapshotStore();
      store.publish(runtime);
      const session = new AccountSessionRuntime(new SessionSnapshotStore('/tmp/ai-rt-test3'));
      await session.activateUser(9);
      const mock = new MockRemoteAdapter();
      const svc = new AIRuntimeService(store, new AIKeyStore('/tmp/ai-rt-keys3', true), session, mock);

      const tool = new AIRuntimeToolDefinition();
      tool.name = 'search';
      tool.summary = 'web';
      const msg = new AIRuntimeMessage();
      msg.role = 'user';
      msg.content = 'hi';
      const req = new AIRuntimeTextRequest();
      req.requestId = 't1';
      req.accountId = 9;
      req.scenario = AIScenario.CHAT;
      req.messages = [msg];
      req.tools = [tool];
      req.toolChoice = 'auto';
      await svc.generateText(req);
      expect(mock.lastRequest !== undefined).assertTrue();
      expect(mock.lastRequest!.tools.length === 0).assertTrue();
      expect(mock.lastRequest!.toolChoice === 'none').assertTrue();
    });

    it('chat_orchestrator_pure_text_path', 0, async () => {
      const providers =
        '[{"id":"OPENAI","name":"OPENAI","company":"OPENAI","requestUrl":"https://api.openai.com/v1/chat/completions","isEnabled":true,"position":0,"source":"localSeed"}]';
      const models =
        '[{"id":"OPENAI:m1","name":"m1","displayName":"M1","providerId":"OPENAI","capabilities":{"supportsText":true},"isEnabled":true}]';
      const bindings =
        '[{"scenario":"chat","modelId":"OPENAI:m1","isDefault":true,"enabled":true,"source":"localSeed"}]';
      const snap = AIConfigSeedLoader.parseSeedBundle(providers, models, bindings, '[]', '{}', 10);
      snap.providers[0].isEnabled = true;
      const runtime = new AIConfigResolver().buildRuntime(snap);
      const store = new AIRuntimeSnapshotStore();
      store.publish(runtime);
      const session = new AccountSessionRuntime(new SessionSnapshotStore('/tmp/ai-rt-test4'));
      await session.activateUser(10);
      const mock = new MockRemoteAdapter();
      const svc = new AIRuntimeService(store, new AIKeyStore('/tmp/ai-rt-keys4', true), session, mock);
      const orch = new ChatOrchestrator(svc);
      const inference = ChatOrchestratorInferenceOptions.defaultOptions();
      inference.useTools = false;
      const out = await orch.generateReply('你好', [], '', 10, inference);
      expect(out.errorCode === undefined).assertTrue();
      expect(out.text.indexOf('ok:chat') >= 0).assertTrue();
    });

    it('generate_text_stream_emits_started_and_completed', 0, async () => {
      const providers =
        '[{"id":"OPENAI","name":"OPENAI","company":"OPENAI","requestUrl":"https://api.openai.com/v1/chat/completions","isEnabled":true,"position":0,"source":"localSeed"}]';
      const models =
        '[{"id":"OPENAI:m1","name":"m1","displayName":"M1","providerId":"OPENAI","capabilities":{"supportsText":true},"isEnabled":true}]';
      const bindings =
        '[{"scenario":"chat","modelId":"OPENAI:m1","isDefault":true,"enabled":true,"source":"localSeed"}]';
      const snap = AIConfigSeedLoader.parseSeedBundle(providers, models, bindings, '[]', '{}', 11);
      snap.providers[0].isEnabled = true;
      const runtime = new AIConfigResolver().buildRuntime(snap);
      const store = new AIRuntimeSnapshotStore();
      store.publish(runtime);
      const session = new AccountSessionRuntime(new SessionSnapshotStore('/tmp/ai-rt-test5'));
      await session.activateUser(11);
      const mock = new MockRemoteAdapter();
      const svc = new AIRuntimeService(store, new AIKeyStore('/tmp/ai-rt-keys5', true), session, mock);
      const kinds: string[] = [];
      const msg = new AIRuntimeMessage();
      msg.role = 'user';
      msg.content = 'hi';
      const req = new AIRuntimeTextRequest();
      req.requestId = 'stream1';
      req.accountId = 11;
      req.scenario = AIScenario.CHAT;
      req.messages = [msg];
      await svc.generateTextStream(req, (ev: AIRuntimeEvent) => {
        kinds.push(ev.kind);
      });
      expect(kinds.indexOf('started') >= 0).assertTrue();
      expect(kinds.indexOf('completed') >= 0).assertTrue();
    });
  });
}

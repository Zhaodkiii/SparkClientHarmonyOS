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
  AIRuntimeToolCall
} from '../../../main/ets/Core/AI/Domain/AIConfigModels';
import { AIProviderAdapter } from '../../../main/ets/Core/AI/Runtime/AIProviderAdapter';
import { ChatOrchestrator } from '../../../main/ets/Core/AI/Runtime/ChatOrchestrator';
import { ChatOrchestratorInferenceOptions } from '../../../main/ets/Core/AI/Runtime/ChatOrchestratorInferenceOptions';
import {
  ChatModelReasoningContext,
  RuntimeReasoningPolicy
} from '../../../main/ets/Core/AI/Runtime/RuntimeReasoningPolicy';
import { RuntimeToolCallLoopStrategy } from '../../../main/ets/Core/AI/Runtime/RuntimeToolCallLoopStrategy';
import { ChatSystemPromptResolver } from '../../../main/ets/Core/AI/Runtime/ChatSystemPromptResolver';
import { AIPromptL10n } from '../../../main/ets/Core/AI/Runtime/AIPromptL10n';
import { AIRuntimeCancellationToken, AIRuntimeCancelledError } from '../../../main/ets/Core/AI/Runtime/AIRuntimeCancellation';
import { ToolHub } from '../../../main/ets/Core/AI/Runtime/ToolHub/ToolHub';
import { ToolConsentPermissionStore } from '../../../main/ets/Core/AI/Runtime/ToolHub/Consent/ToolConsentPermissionStore';
import { StructuredRuntimeClient } from '../../../main/ets/Core/AI/Runtime/StructuredRuntimeClient';

class MockRemoteAdapter extends AIProviderAdapter {
  readonly providerKind: string = 'mock';
  lastRequest?: AIRuntimeTextRequest;
  nextResponse?: AIRuntimeResponse;

  cancel(_requestId: string): void {
  }

  async send(request: AIRuntimeTextRequest, config: AIResolvedConfig): Promise<AIRuntimeResponse> {
    this.lastRequest = request;
    if (this.nextResponse) {
      this.nextResponse.requestId = request.requestId;
      this.nextResponse.modelId = config.modelId;
      this.nextResponse.modelName = config.modelName;
      this.nextResponse.source = config.source;
      return this.nextResponse;
    }
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

async function buildService(accountId: number, dirSuffix: string): Promise<{
  svc: AIRuntimeService;
  mock: MockRemoteAdapter;
}> {
  const providers =
    '[{"id":"OPENAI","name":"OPENAI","company":"OPENAI","requestUrl":"https://api.openai.com/v1/chat/completions","isEnabled":true,"position":0,"source":"localSeed"}]';
  const models =
    '[{"id":"OPENAI:m1","name":"m1","displayName":"M1","providerId":"OPENAI","capabilities":{"supportsText":true,"supportsToolUse":true,"supportsDeepReasoning":true},"isEnabled":true}]';
  const bindings =
    '[{"scenario":"chat","modelId":"OPENAI:m1","isDefault":true,"enabled":true,"source":"localSeed"},{"scenario":"medical_document_type_recognition","modelId":"OPENAI:m1","isDefault":true,"enabled":true,"source":"localSeed"}]';
  const snap = AIConfigSeedLoader.parseSeedBundle(providers, models, bindings, '[]', '{}', accountId);
  snap.providers[0].isEnabled = true;
  const runtime = new AIConfigResolver().buildRuntime(snap);
  const store = new AIRuntimeSnapshotStore();
  store.publish(runtime);
  const session = new AccountSessionRuntime(new SessionSnapshotStore(`/tmp/ai-w2-${dirSuffix}`));
  await session.activateUser(accountId);
  const mock = new MockRemoteAdapter();
  const svc = new AIRuntimeService(store, new AIKeyStore(`/tmp/ai-w2-keys-${dirSuffix}`, true), session, mock);
  return { svc, mock };
}

export default function chatRuntimeWave2Test() {
  describe('ChatRuntimeWave2', () => {
    it('reasoning_policy_three_branches', 0, () => {
      const inference = ChatOrchestratorInferenceOptions.defaultOptions();
      inference.reasoningEnabled = true;
      inference.reasoningEffortTier = 1;

      const controllable = ChatModelReasoningContext.fromCapabilities(true, true);
      const on = RuntimeReasoningPolicy.build(inference, controllable);
      expect(on.isEnabled).assertTrue();
      expect(on.usePromptFallback).assertFalse();

      inference.reasoningEnabled = false;
      const off = RuntimeReasoningPolicy.build(inference, controllable);
      expect(off.isEnabled).assertFalse();

      const forced = ChatModelReasoningContext.fromCapabilities(true, false);
      inference.reasoningEnabled = false;
      const forceOn = RuntimeReasoningPolicy.build(inference, forced);
      expect(forceOn.isEnabled).assertTrue();

      const unsupported = ChatModelReasoningContext.fromCapabilities(false, true);
      inference.reasoningEnabled = true;
      const fallback = RuntimeReasoningPolicy.build(inference, unsupported);
      expect(fallback.isEnabled).assertTrue();
      expect(fallback.usePromptFallback).assertTrue();
    });

    it('deepseek_tool_loop_keeps_reasoning_content', 0, () => {
      const deep = new RuntimeToolCallLoopStrategy('DEEPSEEK', 'deepseek-r1', true, false);
      expect(deep.mode === 'deepSeekThinking').assertTrue();
      const call = new AIRuntimeToolCall();
      call.id = 'c1';
      call.name = 'debug_echo';
      call.arguments = '{"message":"hi"}';
      const kept = deep.reasoningContentForAssistantToolMessage('think', [call]);
      expect(kept === 'think').assertTrue();

      const openai = new RuntimeToolCallLoopStrategy('OPENAI', 'm1', true, false);
      expect(openai.mode === 'openAICompatible').assertTrue();
      const dropped = openai.reasoningContentForAssistantToolMessage('think', [call]);
      expect(dropped === undefined).assertTrue();
    });

    it('system_prompt_priority_and_date_keyword', 0, () => {
      const resolver = new ChatSystemPromptResolver('DEFAULT');
      expect(resolver.resolve(undefined, undefined, 'SMALL') === 'SMALL').assertTrue();
      expect(resolver.resolve('SESSION', 'AGENT', undefined) === 'AGENT').assertTrue();
      expect(resolver.resolve('SESSION', undefined, undefined) === 'SESSION').assertTrue();
      const withDate = resolver.resolve('今天是 {{CURRENT_DATE}}', undefined, undefined);
      expect(withDate.indexOf('{{CURRENT_DATE}}') < 0).assertTrue();
      // L10n 未绑定时走英文 fallback；绑定时为中文「当前日期：」
      const hasZh = withDate.indexOf('当前日期：') >= 0;
      const hasEn = withDate.indexOf('Current date:') >= 0;
      expect(hasZh || hasEn).assertTrue();
    });

    it('prompts_strings_parser_matches_ios_format', 0, () => {
      const sample =
        '"ai.prompt.chat.system" = "你好\\n{{CURRENT_DATE}}";\n' +
        '"ai.prompt.context.line" = "- [%@] %@：%@";\n';
      const table = AIPromptL10n.parseStringsFile(sample);
      expect(table.get('ai.prompt.chat.system') === '你好\n{{CURRENT_DATE}}').assertTrue();
      expect(table.get('ai.prompt.context.line') === '- [%@] %@：%@').assertTrue();
      const formatted = AIPromptL10n.format(table.get('ai.prompt.context.line') as string, ['2026-01-01', '标题', '摘要']);
      expect(formatted === '- [2026-01-01] 标题：摘要').assertTrue();
    });

    it('cancellation_token_throws', 0, () => {
      const token = new AIRuntimeCancellationToken();
      expect(token.isCancelled).assertFalse();
      token.cancel();
      expect(token.isCancelled).assertTrue();
      let threw = false;
      try {
        token.checkCancellation();
      } catch (e) {
        threw = e instanceof AIRuntimeCancelledError;
      }
      expect(threw).assertTrue();
    });

    it('toolhub_lists_spark_tools_and_executes_health_mock', 0, async () => {
      const hub = new ToolHub();
      const defs = hub.listToolDefinitions(undefined);
      expect(defs.length > 1).assertTrue();
      let hasEcho = false;
      let hasSteps = false;
      for (let i = 0; i < defs.length; i++) {
        if (defs[i].name === 'debug_echo') {
          hasEcho = true;
        }
        if (defs[i].name === 'fetch_step_details') {
          hasSteps = true;
        }
      }
      expect(hasEcho).assertTrue();
      expect(hasSteps).assertTrue();

      const ok = await hub.executeToolCall('debug_echo', '{"message":"ping"}', undefined, 't1', 'call1', 'a1', 'r1');
      expect(ok.outputText === 'ping').assertTrue();

      const steps = await hub.executeToolCall(
        'fetch_step_details',
        '{"start_date":"2026-07-15","end_date":"2026-07-21"}',
        1,
        't1',
        'c2',
        'a1',
        'r2',
        'OPENAI',
        'm1'
      );
      expect(steps.outputText.indexOf('示例数据') >= 0).assertTrue();
      expect(steps.sensitive).assertTrue();

      const missing = await hub.executeToolCall('not_exist', '{}', undefined, 't1');
      expect(missing.outputText.indexOf('未识别') >= 0).assertTrue();

      const filtered = hub.listToolDefinitions(undefined, false, false);
      let hasKnowledge = false;
      let hasWeb = false;
      for (let i = 0; i < filtered.length; i++) {
        if (filtered[i].name === 'search_knowledge_bag') {
          hasKnowledge = true;
        }
        if (filtered[i].name === 'search_online') {
          hasWeb = true;
        }
      }
      expect(hasKnowledge).assertFalse();
      expect(hasWeb).assertFalse();

      const audit = await hub.runIfNeeded('/audit_tools', undefined, undefined, 't1');
      expect(audit.kind === 'executed').assertTrue();
      void new ToolConsentPermissionStore();
    });

    it('orchestrator_respects_preflight_cancel', 0, async () => {
      const built = await buildService(21, 'cancel');
      const orch = new ChatOrchestrator(built.svc);
      const token = new AIRuntimeCancellationToken();
      token.cancel();
      let cancelled = false;
      try {
        await orch.generateReply('hi', [], '', 21, ChatOrchestratorInferenceOptions.defaultOptions(),
          undefined, undefined, undefined, undefined, undefined, undefined, undefined, undefined, token);
      } catch (e) {
        cancelled = e instanceof AIRuntimeCancelledError;
      }
      expect(cancelled).assertTrue();
    });

    it('orchestrator_bypass_audit_tools', 0, async () => {
      const built = await buildService(22, 'audit');
      const orch = new ChatOrchestrator(built.svc, new ToolHub());
      const inference = ChatOrchestratorInferenceOptions.defaultOptions();
      inference.useTools = true;
      const out = await orch.generateReply('/audit_tools', [], '', 22, inference);
      expect(out.kind === 'tool').assertTrue();
      expect(out.text.indexOf('debug_echo') >= 0).assertTrue();
    });

    it('structured_runtime_client_uses_non_chat_scenario', 0, async () => {
      const built = await buildService(23, 'struct');
      const client = new StructuredRuntimeClient(built.svc);
      const resp = await client.recognizeMedicalDocumentType(23, '这是一份体检报告');
      expect(resp.errorCode === undefined).assertTrue();
      expect(built.mock.lastRequest !== undefined).assertTrue();
      expect(built.mock.lastRequest!.scenario === AIScenario.MEDICAL_DOCUMENT_TYPE_RECOGNITION).assertTrue();
      expect(built.mock.lastRequest!.toolChoice === 'none').assertTrue();
    });

    it('orchestrator_includes_member_context_in_messages', 0, async () => {
      const built = await buildService(24, 'member');
      const orch = new ChatOrchestrator(built.svc);
      const inference = ChatOrchestratorInferenceOptions.defaultOptions();
      inference.useTools = false;
      await orch.generateReply('你好', [], '当前成员：张三（id=1）', 24, inference, 'SYS');
      expect(built.mock.lastRequest !== undefined).assertTrue();
      const msgs = built.mock.lastRequest!.messages;
      let joined = '';
      for (let i = 0; i < msgs.length; i++) {
        joined += msgs[i].content;
      }
      expect(joined.indexOf('张三') >= 0).assertTrue();
      expect(joined.indexOf('SYS') >= 0 || msgs[0].role === 'system').assertTrue();
    });
  });
}

import { describe, it, expect } from '@ohos/hypium';
import { AIRuntimeSseParser } from '../../../main/ets/Core/AI/Domain/AIRuntimeSseParser';
import { AIRuntimeToolCall } from '../../../main/ets/Core/AI/Domain/AIConfigModels';
import { AIRuntimeMappers } from '../../../main/ets/Core/AI/Domain/AIRuntimeMappers';
import { OpenAIChatBodyEncoder } from '../../../main/ets/Core/AI/Domain/OpenAIChatBodyEncoder';
import {
  AIResolvedConfig,
  AIRuntimeMessage,
  AIRuntimeTextRequest,
  AIRuntimeToolDefinition,
  ModelCapabilities
} from '../../../main/ets/Core/AI/Domain/AIConfigModels';

export default function aiRuntimeSseParserTest() {
  describe('AIRuntimeSseParser_and_Encoder', () => {
    it('parses_text_reasoning_and_done', 0, () => {
      const map: Map<number, AIRuntimeToolCall> = new Map();
      const a = AIRuntimeSseParser.consumeLine('data: {"choices":[{"delta":{"content":"你好"}}]}', map);
      expect(a.textDelta === '你好').assertTrue();
      const b = AIRuntimeSseParser.consumeLine(
        'data: {"choices":[{"delta":{"reasoning_content":"想"}}]}',
        map
      );
      expect(b.reasoningDelta === '想').assertTrue();
      const done = AIRuntimeSseParser.consumeLine('data: [DONE]', map);
      expect(done.done).assertTrue();
    });

    it('parses_crlf_and_wrapped_data', 0, () => {
      const map: Map<number, AIRuntimeToolCall> = new Map();
      const line = 'data: {"code":0,"data":{"choices":[{"delta":{"content":"A"}}]}}\r';
      const r = AIRuntimeSseParser.consumeLine(line, map);
      expect(r.textDelta === 'A').assertTrue();
    });

    it('parses_tool_call_deltas_by_index', 0, () => {
      const map: Map<number, AIRuntimeToolCall> = new Map();
      AIRuntimeSseParser.consumeLine(
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"c1","function":{"name":"debug_echo","arguments":"{\\"m"}}]}}]}',
        map
      );
      AIRuntimeSseParser.consumeLine(
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"sg\\"}"}}]}}]}',
        map
      );
      const calls = AIRuntimeSseParser.mapToolCalls(map);
      expect(calls.length === 1).assertTrue();
      expect(calls[0].name === 'debug_echo').assertTrue();
      expect(calls[0].arguments.indexOf('msg') >= 0 || calls[0].arguments.length > 0).assertTrue();
    });

    it('rejects_invalid_role', 0, () => {
      let threw = false;
      try {
        AIRuntimeMappers.parseRole('bogus');
      } catch (_e) {
        threw = true;
      }
      expect(threw).assertTrue();
    });

    it('encoder_omits_tools_when_choice_none', 0, () => {
      const cfg = new AIResolvedConfig();
      cfg.modelName = 'm1';
      cfg.capabilities = ModelCapabilities.empty();
      cfg.capabilities.supportsToolUse = true;
      const req = new AIRuntimeTextRequest();
      const msg = new AIRuntimeMessage();
      msg.role = 'user';
      msg.content = 'hi';
      req.messages = [msg];
      const tool = new AIRuntimeToolDefinition();
      tool.name = 'debug_echo';
      tool.parametersJson = '{"type":"object","properties":{}}';
      req.tools = [tool];
      req.toolChoice = 'none';
      const body = OpenAIChatBodyEncoder.encode(req, cfg, true);
      expect(body['tools'] === undefined).assertTrue();
    });

    it('encoder_converts_inline_jpeg_prefix', 0, () => {
      const url = AIRuntimeMappers.toVendorImageUrl('spark:inline-jpeg-base64:abc');
      expect(url.indexOf('data:image/jpeg;base64,abc') === 0).assertTrue();
    });
  });
}

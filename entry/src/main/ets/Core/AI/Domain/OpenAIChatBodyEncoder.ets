import {
  AIResolvedConfig,
  AIRuntimeMessage,
  AIRuntimeTextRequest,
  AIRuntimeToolDefinition
} from './AIConfigModels';
import { AIRuntimeMappers } from './AIRuntimeMappers';
import { OpenAIReasoningBuilder } from '../Runtime/OpenAIReasoningPayload';

/**
 * 可单测的 Chat Completions body encoder（工单 §5.3）。
 * Adapter 只负责 HTTP，不自行拼第二套 JSON 结构。
 */
export class OpenAIChatBodyEncoder {
  static encode(
    request: AIRuntimeTextRequest,
    config: AIResolvedConfig,
    stream: boolean
  ): Record<string, Object | string | number | boolean | Object[] | null> {
    const messages: Object[] = [];
    if (config.systemProvision && config.systemProvision.length > 0) {
      const sys: Record<string, string> = {};
      sys['role'] = 'system';
      sys['content'] = config.systemProvision;
      messages.push(sys);
    }
    for (let i = 0; i < request.messages.length; i++) {
      messages.push(OpenAIChatBodyEncoder.encodeMessage(request.messages[i]));
    }
    const body: Record<string, Object | string | number | boolean | Object[] | null> = {};
    body['model'] = config.modelName;
    body['messages'] = messages;
    body['stream'] = stream;

    const temperature = request.temperature !== undefined ? request.temperature : config.temperature;
    if (temperature !== undefined) {
      body['temperature'] = temperature;
    }
    if (request.topP !== undefined) {
      body['top_p'] = request.topP;
    }
    const maxTokens = request.maxTokens !== undefined ? request.maxTokens : config.maxTokens;
    if (maxTokens !== undefined) {
      body['max_tokens'] = maxTokens;
    }

    const tools = AIRuntimeMappers.sanitizeTools(request.tools);
    const toolChoice = AIRuntimeMappers.normalizeToolChoice(request.toolChoice, tools.length > 0);
    if (config.capabilities.supportsToolUse && tools.length > 0 && toolChoice !== 'none') {
      body['tools'] = OpenAIChatBodyEncoder.encodeTools(tools);
      body['tool_choice'] = toolChoice;
    }

    const company = request.providerCompanyUppercased ?? config.company;
    OpenAIReasoningBuilder.applyToBody(body, company, request.reasoning);
    return body;
  }

  static encodeMessage(message: AIRuntimeMessage): Object {
    const role = AIRuntimeMappers.parseRole(message.role);
    const out: Record<string, Object | string | null> = {};
    out['role'] = role;

    if (message.contentParts !== undefined && message.contentParts.length > 0) {
      const parts: Object[] = [];
      for (let i = 0; i < message.contentParts.length; i++) {
        const p = message.contentParts[i];
        if (p.type === 'text') {
          const textPart: Record<string, string> = {};
          textPart['type'] = 'text';
          textPart['text'] = p.text ?? '';
          parts.push(textPart);
        } else if (p.type === 'image_url' && p.imageURL) {
          const vendorUrl = AIRuntimeMappers.toVendorImageUrl(p.imageURL.url);
          if (vendorUrl.length === 0) {
            continue;
          }
          const image: Record<string, string> = {};
          image['url'] = vendorUrl;
          if (p.imageURL.detail) {
            image['detail'] = p.imageURL.detail;
          }
          const imagePart: Record<string, Object | string> = {};
          imagePart['type'] = 'image_url';
          imagePart['image_url'] = image;
          parts.push(imagePart);
        }
      }
      out['content'] = parts;
    } else if (message.toolCalls && message.toolCalls.length > 0) {
      out['content'] = null;
    } else {
      out['content'] = message.content ?? '';
    }

    if (message.toolCalls && message.toolCalls.length > 0) {
      const calls: Object[] = [];
      for (let i = 0; i < message.toolCalls.length; i++) {
        const c = message.toolCalls[i];
        const fn: Record<string, string> = {};
        fn['name'] = c.name;
        fn['arguments'] = c.arguments;
        const call: Record<string, Object | string> = {};
        call['id'] = c.id;
        call['type'] = 'function';
        call['function'] = fn;
        calls.push(call);
      }
      out['tool_calls'] = calls;
      if (out['content'] === undefined) {
        out['content'] = null;
      }
    }
    if (message.toolCallID) {
      out['tool_call_id'] = message.toolCallID;
    }
    if (message.name) {
      out['name'] = message.name;
    }
    if (message.reasoningContent) {
      out['reasoning_content'] = message.reasoningContent;
    }
    return out;
  }

  private static encodeTools(tools: AIRuntimeToolDefinition[]): Object[] {
    const out: Object[] = [];
    for (let i = 0; i < tools.length; i++) {
      const t = tools[i];
      let parameters: Object;
      try {
        parameters = JSON.parse(t.parametersJson) as Object;
      } catch (_e) {
        const emptyProps: Record<string, Object> = {};
        const fallback: Record<string, Object | string> = {};
        fallback['type'] = 'object';
        fallback['properties'] = emptyProps;
        parameters = fallback;
      }
      const fn: Record<string, Object | string> = {};
      fn['name'] = t.name;
      fn['description'] = t.summary;
      fn['parameters'] = parameters;
      const tool: Record<string, Object | string> = {};
      tool['type'] = 'function';
      tool['function'] = fn;
      out.push(tool);
    }
    return out;
  }
}

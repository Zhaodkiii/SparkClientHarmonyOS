import {
  AIRuntimeEvent,
  AIRuntimeToolCall,
  AIRuntimeToolCallDelta
} from './AIConfigModels';

export class SseParseResult {
  textDelta: string = '';
  reasoningDelta: string = '';
  finishReason: string = '';
  toolCallDeltas: AIRuntimeToolCallDelta[] = [];
  /** 服务端错误包裹（非 choices） */
  errorMessage?: string;
  errorCode?: string;
  done: boolean = false;
}

/**
 * 纯函数 SSE 行解析（可单测）。对齐 iOS OpenAICompatibleTextGateway 行为要点：
 * CRLF、data: 前缀、[DONE]、backend data 包裹、reasoning/tool_calls。
 */
export class AIRuntimeSseParser {
  static normalizeLine(raw: string): string {
    let line = raw;
    if (line.endsWith('\r')) {
      line = line.substring(0, line.length - 1);
    }
    return line.trim();
  }

  static consumeLine(
    rawLine: string,
    toolCallsByIndex: Map<number, AIRuntimeToolCall>
  ): SseParseResult {
    const result = new SseParseResult();
    const line = AIRuntimeSseParser.normalizeLine(rawLine);
    if (line.length === 0 || line.indexOf(':') === 0) {
      // 空行或 SSE 注释
      return result;
    }
    if (line === 'data: [DONE]' || line === 'data:[DONE]') {
      result.done = true;
      return result;
    }
    let payload = line;
    if (payload.indexOf('data:') === 0) {
      payload = payload.substring(5).trim();
    }
    if (payload.length === 0 || payload === '[DONE]') {
      result.done = payload === '[DONE]';
      return result;
    }
    let parsed: Record<string, Object>;
    try {
      parsed = JSON.parse(payload) as Record<string, Object>;
    } catch (_e) {
      return result;
    }

    // 错误包裹：{ error: { message } } 或 { code:非0, msg }
    const errObj = parsed['error'];
    if (errObj !== undefined && typeof errObj === 'object') {
      const e = errObj as Record<string, Object>;
      result.errorMessage = `${e['message'] ?? e['msg'] ?? 'provider error'}`;
      result.errorCode = `${e['code'] ?? 'providerError'}`;
      return result;
    }
    const codeVal = parsed['code'];
    if (codeVal !== undefined && typeof codeVal === 'number' && (codeVal as number) !== 0) {
      result.errorMessage = `${parsed['msg'] ?? parsed['message'] ?? 'server business error'}`;
      result.errorCode = `${codeVal}`;
      return result;
    }

    const dataObj = parsed['data'];
    const root = (dataObj !== undefined && typeof dataObj === 'object')
      ? dataObj as Record<string, Object>
      : parsed;
    const choices = root['choices'] as Object[] | undefined;
    if (!choices || choices.length === 0) {
      return result;
    }
    const choice = choices[0] as Record<string, Object>;
    const finish = choice['finish_reason'];
    if (finish !== undefined && `${finish}`.length > 0 && `${finish}` !== 'null') {
      result.finishReason = `${finish}`;
    }
    const delta = choice['delta'] as Record<string, Object> | undefined;
    if (!delta) {
      return result;
    }
    const content = delta['content'];
    if (content !== undefined && `${content}`.length > 0) {
      result.textDelta = `${content}`;
    }
    const reasoning = delta['reasoning_content'] ?? delta['reasoning'];
    if (reasoning !== undefined && `${reasoning}`.length > 0) {
      result.reasoningDelta = `${reasoning}`;
    }
    const toolDeltas = delta['tool_calls'] as Object[] | undefined;
    if (toolDeltas) {
      for (let i = 0; i < toolDeltas.length; i++) {
        const td = toolDeltas[i] as Record<string, Object>;
        const index = Number(td['index'] ?? i);
        let call = toolCallsByIndex.get(index);
        if (!call) {
          call = new AIRuntimeToolCall();
          call.id = `${td['id'] ?? ''}`;
          const fn = td['function'] as Record<string, Object> | undefined;
          call.name = fn ? `${fn['name'] ?? ''}` : '';
          call.arguments = fn ? `${fn['arguments'] ?? ''}` : '';
          toolCallsByIndex.set(index, call);
        } else {
          const fn = td['function'] as Record<string, Object> | undefined;
          if (td['id']) {
            call.id = `${td['id']}`;
          }
          if (fn && fn['name']) {
            call.name = `${fn['name']}`;
          }
          if (fn && fn['arguments']) {
            call.arguments = call.arguments + `${fn['arguments']}`;
          }
        }
        const d = new AIRuntimeToolCallDelta();
        d.index = index;
        d.id = call.id;
        d.name = call.name;
        const fn2 = td['function'] as Record<string, Object> | undefined;
        d.argumentsDelta = fn2 ? `${fn2['arguments'] ?? ''}` : undefined;
        result.toolCallDeltas.push(d);
      }
    }
    return result;
  }

  static emitParseEvents(
    requestId: string,
    parse: SseParseResult,
    onEvent: (ev: AIRuntimeEvent) => void
  ): void {
    if (parse.textDelta.length > 0) {
      const ev = new AIRuntimeEvent();
      ev.kind = 'textDelta';
      ev.requestId = requestId;
      ev.deltaText = parse.textDelta;
      onEvent(ev);
    }
    if (parse.reasoningDelta.length > 0) {
      const ev = new AIRuntimeEvent();
      ev.kind = 'reasoningDelta';
      ev.requestId = requestId;
      ev.reasoningDelta = parse.reasoningDelta;
      onEvent(ev);
    }
    for (let i = 0; i < parse.toolCallDeltas.length; i++) {
      const ev = new AIRuntimeEvent();
      ev.kind = 'toolCall';
      ev.requestId = requestId;
      ev.toolCallDelta = parse.toolCallDeltas[i];
      onEvent(ev);
    }
  }

  static mapToolCalls(map: Map<number, AIRuntimeToolCall>): AIRuntimeToolCall[] {
    const keys: number[] = [];
    map.forEach((_v: AIRuntimeToolCall, k: number) => {
      keys.push(k);
    });
    keys.sort((a: number, b: number) => a - b);
    const out: AIRuntimeToolCall[] = [];
    for (let i = 0; i < keys.length; i++) {
      const call = map.get(keys[i]);
      if (call) {
        out.push(call);
      }
    }
    return out;
  }
}

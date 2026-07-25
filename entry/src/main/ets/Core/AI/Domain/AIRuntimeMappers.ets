import { AIRuntimeToolDefinition } from './AIConfigModels';
import { AIRuntimeError, AIRuntimeErrorCodes } from './AIRuntimeErrors';

export type AIRuntimeRole = 'system' | 'user' | 'assistant' | 'tool';
export type AIRuntimeToolChoice = 'auto' | 'none';

/**
 * Runtime 边界校验 / mapper（工单 P0-B）。
 * role/toolChoice 允许 JSON 边界为 string，进入编排/出站前必须校验。
 */
export class AIRuntimeMappers {
  static parseRole(raw: string): AIRuntimeRole {
    if (raw === 'system' || raw === 'user' || raw === 'assistant' || raw === 'tool') {
      return raw;
    }
    throw new AIRuntimeError(AIRuntimeErrorCodes.INVALID_ROLE, `非法消息角色: ${raw}`);
  }

  static parseToolChoice(raw: string): AIRuntimeToolChoice {
    if (raw === 'auto' || raw === 'none') {
      return raw;
    }
    throw new AIRuntimeError(AIRuntimeErrorCodes.INVALID_TOOL_CHOICE, `非法 toolChoice: ${raw}`);
  }

  static normalizeToolChoice(raw: string | undefined, hasTools: boolean): AIRuntimeToolChoice {
    if (!hasTools) {
      return 'none';
    }
    if (!raw || raw.length === 0) {
      return 'auto';
    }
    return AIRuntimeMappers.parseToolChoice(raw);
  }

  /** 校验 tools parametersJson 可解析为 object；失败则剔除该工具 */
  static sanitizeTools(tools: AIRuntimeToolDefinition[]): AIRuntimeToolDefinition[] {
    const out: AIRuntimeToolDefinition[] = [];
    for (let i = 0; i < tools.length; i++) {
      const t = tools[i];
      if (!t.name || t.name.length === 0) {
        continue;
      }
      try {
        const parsed = JSON.parse(t.parametersJson) as Object;
        if (parsed === null || typeof parsed !== 'object') {
          continue;
        }
        out.push(t);
      } catch (_e) {
        // drop invalid schema
      }
    }
    return out;
  }

  static isInlineJpegUrl(url: string): boolean {
    return url.indexOf('spark:inline-jpeg-base64:') === 0;
  }

  /** 厂商可接受的 data URL；不支持内联时返回空串由调用方跳过 */
  static toVendorImageUrl(url: string): string {
    if (!AIRuntimeMappers.isInlineJpegUrl(url)) {
      return url;
    }
    const b64 = url.substring('spark:inline-jpeg-base64:'.length);
    if (b64.length === 0) {
      return '';
    }
    return `data:image/jpeg;base64,${b64}`;
  }
}

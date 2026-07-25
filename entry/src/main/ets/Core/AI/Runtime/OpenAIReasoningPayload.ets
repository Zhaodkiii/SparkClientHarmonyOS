import { AIRuntimeReasoningOptions } from '../Domain/AIConfigModels';

/**
 * 按厂商向 Chat Completions body 注入 reasoning 相关字段（对齐 iOS OpenAIReasoningBuilder 职责）。
 */
export class OpenAIReasoningBuilder {
  static applyToBody(
    body: Record<string, Object | string | number | boolean | Object[] | null>,
    providerCompany: string,
    options: AIRuntimeReasoningOptions
  ): void {
    if (!options.isEnabled) {
      return;
    }
    const company = (providerCompany || '').toUpperCase();
    const effort = OpenAIReasoningBuilder.effortLabel(options.effortTier);
    if (company.indexOf('OPENAI') >= 0) {
      body['reasoning_effort'] = effort;
      return;
    }
    if (company.indexOf('DEEPSEEK') >= 0) {
      const thinking: Record<string, string> = {};
      thinking['type'] = 'enabled';
      body['thinking'] = thinking;
      return;
    }
    if (company.indexOf('QWEN') >= 0 || company.indexOf('DASHCOPE') >= 0 || company.indexOf('ALI') >= 0) {
      body['enable_thinking'] = true;
      return;
    }
  }

  private static effortLabel(tier: number): string {
    if (tier <= 0) {
      return 'minimal';
    }
    if (tier === 1) {
      return 'low';
    }
    if (tier === 2) {
      return 'medium';
    }
    return 'high';
  }
}

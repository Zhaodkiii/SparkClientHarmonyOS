import { AIRuntimeToolCall } from '../Domain/AIConfigModels';

export type ToolCallLoopMode = 'openAICompatible' | 'deepSeekThinking';

/**
 * 对齐 iOS RuntimeToolCallLoopStrategy：DeepSeek 思考模式下 assistant tool_calls 回传 reasoning_content。
 */
export class RuntimeToolCallLoopStrategy {
  readonly mode: ToolCallLoopMode;
  private readonly reasoningEnabled: boolean;
  private readonly usePromptFallback: boolean;

  constructor(
    providerCompanyUppercased: string | undefined,
    preferredModelName: string | undefined,
    reasoningEnabled: boolean,
    usePromptFallback: boolean
  ) {
    this.reasoningEnabled = reasoningEnabled;
    this.usePromptFallback = usePromptFallback;
    if (RuntimeToolCallLoopStrategy.isDeepSeek(providerCompanyUppercased, preferredModelName) &&
      reasoningEnabled &&
      !usePromptFallback) {
      this.mode = 'deepSeekThinking';
    } else {
      this.mode = 'openAICompatible';
    }
  }

  reasoningContentForAssistantToolMessage(
    reasoningContent: string | undefined,
    toolCalls: AIRuntimeToolCall[]
  ): string | undefined {
    if (toolCalls.length === 0) {
      return undefined;
    }
    if (!reasoningContent || reasoningContent.length === 0) {
      return undefined;
    }
    if (this.mode === 'deepSeekThinking') {
      return reasoningContent;
    }
    return undefined;
  }

  private static isDeepSeek(providerCompanyUppercased?: string, modelName?: string): boolean {
    const company = (providerCompanyUppercased ?? '').toUpperCase();
    if (company.indexOf('DEEPSEEK') >= 0) {
      return true;
    }
    const model = (modelName ?? '').toUpperCase();
    return model.indexOf('DEEPSEEK') >= 0;
  }
}

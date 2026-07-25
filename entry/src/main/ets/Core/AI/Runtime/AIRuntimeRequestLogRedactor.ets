import { AIRuntimeResponse } from '../Domain/AIConfigModels';

export class AIRuntimeRequestLogRedactor {
  static summarizeResponse(
    scenario: string,
    inferenceSource: string,
    response: AIRuntimeResponse,
    modelName: string
  ): string {
    const textLen = response.text.length;
    const reasonLen = response.reasoningText ? response.reasoningText.length : 0;
    const tools = response.toolCalls.length;
    const err = response.errorCode ? ` err=${response.errorCode}` : '';
    return `scenario=${scenario} source=${inferenceSource} model=${modelName}` +
      ` finish=${response.finishReason} textLen=${textLen} reasoningLen=${reasonLen} tools=${tools}${err}`;
  }

  static redactSecret(value: string): string {
    if (value.length <= 8) {
      return '***';
    }
    return `${value.substring(0, 4)}***${value.substring(value.length - 2)}`;
  }
}

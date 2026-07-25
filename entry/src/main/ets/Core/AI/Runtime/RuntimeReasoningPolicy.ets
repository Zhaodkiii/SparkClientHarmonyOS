import { AIRuntimeReasoningOptions } from '../Domain/AIConfigModels';
import { ChatOrchestratorInferenceOptions } from './ChatOrchestratorInferenceOptions';

/**
 * 模型推理能力上下文（对齐 iOS ChatModelReasoningContext）。
 */
export class ChatModelReasoningContext {
  supportsReasoning: boolean = false;
  /** 支持且用户可控开关；不可控时强制开启原生 reasoning */
  reasoningControllable: boolean = true;

  static unknown(): ChatModelReasoningContext {
    return new ChatModelReasoningContext();
  }

  static fromCapabilities(supportsDeepReasoning: boolean, controllable: boolean = true): ChatModelReasoningContext {
    const c = new ChatModelReasoningContext();
    c.supportsReasoning = supportsDeepReasoning;
    c.reasoningControllable = controllable;
    return c;
  }
}

/**
 * 对齐 iOS buildRuntimeReasoningOptions 三分支。
 */
export class RuntimeReasoningPolicy {
  static build(
    inference: ChatOrchestratorInferenceOptions,
    model: ChatModelReasoningContext
  ): AIRuntimeReasoningOptions {
    const userWants = inference.reasoningEnabled;
    const tier = inference.reasoningEffortTier;
    if (model.supportsReasoning) {
      if (model.reasoningControllable) {
        if (userWants) {
          return AIRuntimeReasoningOptions.enabled(tier, false);
        }
        return AIRuntimeReasoningOptions.disabled();
      }
      // 支持但不可控：强制开启
      return AIRuntimeReasoningOptions.enabled(tier, false);
    }
    // 不支持：用户开启则 prompt fallback
    if (userWants) {
      return AIRuntimeReasoningOptions.enabled(tier, true);
    }
    return AIRuntimeReasoningOptions.disabled();
  }
}

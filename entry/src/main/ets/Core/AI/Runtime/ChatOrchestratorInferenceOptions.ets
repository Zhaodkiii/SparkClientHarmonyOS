/**
 * 对齐 iOS ChatOrchestratorInferenceOptions / ChatComposerRuntimeFlags。
 */
export class ChatOrchestratorInferenceOptions {
  useTools: boolean = true;
  useKnowledgeBag: boolean = true;
  useWebSearch: boolean = true;
  reasoningEnabled: boolean = false;
  /** 0=minimal … 3=high */
  reasoningEffortTier: number = 0;
  allowedToolNames: string[] | undefined = undefined;

  static defaultOptions(): ChatOrchestratorInferenceOptions {
    return new ChatOrchestratorInferenceOptions();
  }
}

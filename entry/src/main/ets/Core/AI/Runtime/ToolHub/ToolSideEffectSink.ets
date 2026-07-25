export class ToolSideEffect {
  kind: string = 'chatBlock';
  toolName: string = '';
  toolCallId: string = '';
  text: string = '';
  assistantMessageClientId?: string;
  accountId: number = 0;
}

export type ToolSideEffectHandler = (effect: ToolSideEffect) => void;

/**
 * 工具副作用统一 sink：Orchestrator/ToolHub 不直接写医疗/文件模块。
 */
export class ToolSideEffectSink {
  private handler?: ToolSideEffectHandler;

  setHandler(handler: ToolSideEffectHandler | undefined): void {
    this.handler = handler;
  }

  emit(effect: ToolSideEffect): void {
    if (this.handler) {
      this.handler(effect);
    }
  }
}

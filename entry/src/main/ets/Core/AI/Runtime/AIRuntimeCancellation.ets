/**
 * 对齐 iOS AIRuntimeCancellationToken：协作式取消。
 * UI / Orchestrator / Adapter 共用同一令牌；HTTP 取消还需 Adapter.destroy。
 */
export class AIRuntimeCancellationToken {
  private cancelledFlag: boolean = false;

  get isCancelled(): boolean {
    return this.cancelledFlag;
  }

  cancel(): void {
    this.cancelledFlag = true;
  }

  checkCancellation(): void {
    if (this.cancelledFlag) {
      throw new AIRuntimeCancelledError();
    }
  }
}

export class AIRuntimeCancelledError extends Error {
  constructor(message: string = 'cancelled') {
    super(message);
    this.name = 'AIRuntimeCancelledError';
  }
}

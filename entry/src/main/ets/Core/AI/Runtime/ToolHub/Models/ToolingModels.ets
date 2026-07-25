/**
 * 对齐 iOS ToolingModels：执行结果 / 副作用 / Hub 运行结果。
 */

export class ToolSideEffectRecord {
  /** 对齐 iOS ToolSideEffect case 名 */
  type: string = '';
  text?: string;
  resourceType?: string;
  resourceID?: number;
  memberID?: number;
  jsonPayload?: string;
}

export class ToolExecutionResult {
  toolName: string = '';
  outputText: string = '';
  sensitive: boolean = false;
  shouldBypassModel: boolean = false;
  isAwaitingUserInput: boolean = false;
  resolvedMemberID?: number;
  toolCallID?: string;
  anchorToolCallID?: string;
  /** 归一化调用参数 */
  invocationArguments?: Record<string, string>;
  sideEffects: ToolSideEffectRecord[] = [];

  static make(
    toolName: string,
    outputText: string,
    sensitive: boolean,
    shouldBypassModel: boolean,
    isAwaitingUserInput: boolean = false,
    sideEffects: ToolSideEffectRecord[] = []
  ): ToolExecutionResult {
    const r = new ToolExecutionResult();
    r.toolName = toolName;
    r.outputText = outputText;
    r.sensitive = sensitive;
    r.shouldBypassModel = shouldBypassModel;
    r.isAwaitingUserInput = isAwaitingUserInput;
    r.sideEffects = sideEffects;
    return r;
  }

  withToolCallID(toolCallID?: string): ToolExecutionResult {
    const r = this.clone();
    r.toolCallID = toolCallID;
    if (!r.anchorToolCallID) {
      r.anchorToolCallID = toolCallID;
    }
    return r;
  }

  withAnchorToolCallID(pendingAnchor?: string): ToolExecutionResult {
    const r = this.clone();
    if (!r.anchorToolCallID) {
      r.anchorToolCallID = pendingAnchor;
    }
    return r;
  }

  withInvocationArgumentsIfMissing(args: Record<string, string>): ToolExecutionResult {
    const keys = Object.keys(args);
    if (keys.length === 0) {
      return this;
    }
    if (this.invocationArguments && Object.keys(this.invocationArguments).length > 0) {
      return this;
    }
    const r = this.clone();
    r.invocationArguments = args;
    return r;
  }

  private clone(): ToolExecutionResult {
    const r = new ToolExecutionResult();
    r.toolName = this.toolName;
    r.outputText = this.outputText;
    r.sensitive = this.sensitive;
    r.shouldBypassModel = this.shouldBypassModel;
    r.isAwaitingUserInput = this.isAwaitingUserInput;
    r.resolvedMemberID = this.resolvedMemberID;
    r.toolCallID = this.toolCallID;
    r.anchorToolCallID = this.anchorToolCallID;
    r.invocationArguments = this.invocationArguments;
    r.sideEffects = this.sideEffects.slice();
    return r;
  }
}

export type ToolHubRunKind = 'none' | 'executed';

export class ToolHubRunResult {
  kind: ToolHubRunKind = 'none';
  executed?: ToolExecutionResult;

  static none(): ToolHubRunResult {
    return new ToolHubRunResult();
  }

  static executed(result: ToolExecutionResult): ToolHubRunResult {
    const r = new ToolHubRunResult();
    r.kind = 'executed';
    r.executed = result;
    return r;
  }
}

export class ToolInvocation {
  name: string = '';
  arguments: Record<string, string> = {};
}

export class ToolExecutionContext {
  accountID: number = 0;
  memberID?: number;
  locale: string = 'zh_CN';
  assistantMessageClientID?: string;
  threadID?: string;
  pendingToolCallID?: string;
  providerCompany?: string;
  modelName?: string;
  endpoint?: string;
  privacyPolicyURL?: string;
  requestId?: string;
}

export enum ToolAuditStatus {
  SUCCESS = 'success',
  DENIED = 'denied',
  FAILED = 'failed'
}

export class ToolAuditEvent {
  id: string = '';
  accountId: number = 0;
  toolName: string = '';
  memberID?: number;
  inputSummary: string = '';
  outputSummary: string = '';
  status: ToolAuditStatus = ToolAuditStatus.SUCCESS;
  createdAt: string = '';
  requestId?: string;
  threadId?: string;
}

export class ToolConsentDecision {
  allowed: boolean = false;
  rememberTool: boolean = false;
}

export type InteractionResultKind = 'success' | 'cancelled' | 'conflict';

export class InteractionResult {
  kind: InteractionResultKind = 'cancelled';
  decision?: ToolConsentDecision;

  static success(decision: ToolConsentDecision): InteractionResult {
    const r = new InteractionResult();
    r.kind = 'success';
    r.decision = decision;
    return r;
  }

  static cancelled(): InteractionResult {
    const r = new InteractionResult();
    r.kind = 'cancelled';
    return r;
  }

  static conflict(): InteractionResult {
    const r = new InteractionResult();
    r.kind = 'conflict';
    return r;
  }
}

/**
 * 人机交互协调器最小协议（UI 层后续实现 ToolInteractionCoordinator）。
 */
export interface ToolInteractionCoordinating {
  requestConsentDecision(
    threadID: string | undefined,
    result: ToolExecutionResult,
    callArguments: string,
    providerCompany: string | undefined,
    modelName: string | undefined,
    endpoint: string | undefined,
    privacyPolicyURL: string | undefined
  ): Promise<InteractionResult>;
}

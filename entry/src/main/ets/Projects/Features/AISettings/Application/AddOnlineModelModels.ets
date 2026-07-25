/** 对标 iOS AddOnlineModelDraft */
export class AddOnlineModelDraft {
  name: string = '';
  displayName: string = '';
  providerID: string = '';
  company: string = '';
  priceTier: number = 2;
  isHidden: boolean = false;
  supportsText: boolean = true;
  supportsMultimodal: boolean = false;
  supportsReasoning: boolean = false;
  reasoningControllable: boolean = false;
  supportsToolUse: boolean = false;
  supportsImageGen: boolean = false;
}

/** 对标 iOS ModelCapabilityProbeStep */
export enum ModelCapabilityProbeStep {
  CONNECTIVITY = 'connectivity',
  TEXT = 'text',
  MULTIMODAL = 'multimodal',
  REASONING = 'reasoning',
  TOOL_USE = 'toolUse',
  IMAGE_GEN = 'imageGen'
}

export enum ModelCapabilityProbeStatus {
  PENDING = 'pending',
  RUNNING = 'running',
  SUCCESS = 'success',
  FAILED = 'failed',
  SKIPPED = 'skipped'
}

export class ModelCapabilityProbeProgressItem {
  step: ModelCapabilityProbeStep = ModelCapabilityProbeStep.CONNECTIVITY;
  status: ModelCapabilityProbeStatus = ModelCapabilityProbeStatus.PENDING;
  message: string = '';

  constructor(
    step: ModelCapabilityProbeStep,
    status: ModelCapabilityProbeStatus = ModelCapabilityProbeStatus.PENDING,
    message: string = ''
  ) {
    this.step = step;
    this.status = status;
    this.message = message;
  }
}

export class ModelCapabilityProbeSummary {
  supportsText: boolean = false;
  supportsMultimodal: boolean = false;
  supportsReasoning: boolean = false;
  reasoningControllable: boolean = false;
  supportsToolUse: boolean = false;
  supportsImageGen: boolean = false;
}

export const ALL_PROBE_STEPS: ModelCapabilityProbeStep[] = [
  ModelCapabilityProbeStep.CONNECTIVITY,
  ModelCapabilityProbeStep.TEXT,
  ModelCapabilityProbeStep.MULTIMODAL,
  ModelCapabilityProbeStep.REASONING,
  ModelCapabilityProbeStep.TOOL_USE,
  ModelCapabilityProbeStep.IMAGE_GEN
];

export function probeStepTitle(step: ModelCapabilityProbeStep): string {
  if (step === ModelCapabilityProbeStep.CONNECTIVITY) {
    return '连通性';
  }
  if (step === ModelCapabilityProbeStep.TEXT) {
    return '文本生成';
  }
  if (step === ModelCapabilityProbeStep.MULTIMODAL) {
    return '多模态';
  }
  if (step === ModelCapabilityProbeStep.REASONING) {
    return '推理';
  }
  if (step === ModelCapabilityProbeStep.TOOL_USE) {
    return '工具调用';
  }
  if (step === ModelCapabilityProbeStep.IMAGE_GEN) {
    return '生图';
  }
  return step;
}

export function priceTierLabel(tier: number): string {
  const t = Math.min(Math.max(tier, 0), 3);
  if (t === 0) {
    return '免费';
  }
  if (t === 1) {
    return '经济';
  }
  if (t === 2) {
    return '标准';
  }
  return '高级';
}

export function priceTierColor(tier: number): string {
  const t = Math.min(Math.max(tier, 0), 3);
  if (t === 0) {
    return '#34C759';
  }
  if (t === 1) {
    return '#FFCC00';
  }
  if (t === 2) {
    return '#FF9500';
  }
  return '#FF3B30';
}

export function emptyProbeItems(): ModelCapabilityProbeProgressItem[] {
  const out: ModelCapabilityProbeProgressItem[] = [];
  for (let i = 0; i < ALL_PROBE_STEPS.length; i++) {
    out.push(new ModelCapabilityProbeProgressItem(ALL_PROBE_STEPS[i]));
  }
  return out;
}

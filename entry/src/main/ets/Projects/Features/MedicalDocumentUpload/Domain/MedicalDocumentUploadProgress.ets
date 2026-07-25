/**
 * 上传进度模型，对齐 iOS / 参考实现 SupportingModels 中的 Progress/Step。
 * 步骤枚举沿用本模块 `MedicalDocumentUploadFlowStepKind`，rawValue 与后端一致。
 */
import {
  MedicalDocumentUploadFlowStepKind,
  MedicalDocumentUploadStepOutcome
} from './MedicalDocumentUploadFlowStep';

const PIPELINE_ORDER: MedicalDocumentUploadFlowStepKind[] = [
  MedicalDocumentUploadFlowStepKind.UPLOAD,
  MedicalDocumentUploadFlowStepKind.OCR,
  MedicalDocumentUploadFlowStepKind.TYPE_RECOGNITION,
  MedicalDocumentUploadFlowStepKind.EXTRACT,
  MedicalDocumentUploadFlowStepKind.ATTACHMENT_BINDING
];

export function medicalUploadPipelineSteps(): MedicalDocumentUploadFlowStepKind[] {
  return PIPELINE_ORDER.slice();
}

export function medicalUploadPipelineOrder(step: MedicalDocumentUploadFlowStepKind): number {
  const idx = PIPELINE_ORDER.indexOf(step);
  return idx === -1 ? PIPELINE_ORDER.length : idx;
}

@Observed
export class MedicalDocumentUploadProgressStep {
  kind: MedicalDocumentUploadFlowStepKind;
  outcome: MedicalDocumentUploadStepOutcome = MedicalDocumentUploadStepOutcome.PENDING;
  resultSummary: string = '';
  elapsedMilliseconds: number = 0;

  constructor(kind: MedicalDocumentUploadFlowStepKind) {
    this.kind = kind;
  }

  get isTerminalSuccess(): boolean {
    return this.outcome === MedicalDocumentUploadStepOutcome.SUCCESS
      || this.outcome === MedicalDocumentUploadStepOutcome.SKIPPED;
  }
}

@Observed
export class MedicalDocumentUploadProgress {
  title: string = '';
  statusLabel: string = '';
  elapsedSeconds: number = 0;
  estimatedSeconds: number = 60;
  steps: MedicalDocumentUploadProgressStep[] = [];

  constructor(
    title: string,
    statusLabel: string,
    elapsedSeconds: number,
    estimatedSeconds: number,
    steps: MedicalDocumentUploadProgressStep[]
  ) {
    this.title = title;
    this.statusLabel = statusLabel;
    this.elapsedSeconds = elapsedSeconds;
    this.estimatedSeconds = estimatedSeconds;
    this.steps = steps;
  }

  static createInitial(estimatedSeconds: number = 60): MedicalDocumentUploadProgress {
    const steps = medicalUploadPipelineSteps().map(
      (kind: MedicalDocumentUploadFlowStepKind): MedicalDocumentUploadProgressStep =>
        new MedicalDocumentUploadProgressStep(kind)
    );
    return new MedicalDocumentUploadProgress('正在识别…', '处理中', 0, estimatedSeconds, steps);
  }
}

/** AI 上传报告流水线步骤；顺序必须与 iOS 保持一致。 */
export enum MedicalDocumentUploadFlowStepKind {
  UPLOAD = 'upload',
  OCR = 'ocr',
  TYPE_RECOGNITION = 'type_recognition',
  EXTRACT = 'extract',
  ATTACHMENT_BINDING = 'attachment_binding',
  SAVE = 'save'
}

export enum MedicalDocumentUploadStepOutcome {
  PENDING = 'pending',
  RUNNING = 'running',
  SUCCESS = 'success',
  SKIPPED = 'skipped',
  FAILED = 'failed'
}

export class MedicalDocumentUploadFlowStep {
  kind: MedicalDocumentUploadFlowStepKind;
  outcome: MedicalDocumentUploadStepOutcome;
  resultSummary: string = '';

  constructor(
    kind: MedicalDocumentUploadFlowStepKind,
    outcome: MedicalDocumentUploadStepOutcome = MedicalDocumentUploadStepOutcome.PENDING,
    resultSummary: string = ''
  ) {
    this.kind = kind;
    this.outcome = outcome;
    this.resultSummary = resultSummary;
  }

  static pipeline(): MedicalDocumentUploadFlowStep[] {
    return [
      new MedicalDocumentUploadFlowStep(MedicalDocumentUploadFlowStepKind.UPLOAD),
      new MedicalDocumentUploadFlowStep(MedicalDocumentUploadFlowStepKind.OCR),
      new MedicalDocumentUploadFlowStep(MedicalDocumentUploadFlowStepKind.TYPE_RECOGNITION),
      new MedicalDocumentUploadFlowStep(MedicalDocumentUploadFlowStepKind.EXTRACT),
      new MedicalDocumentUploadFlowStep(MedicalDocumentUploadFlowStepKind.ATTACHMENT_BINDING),
      new MedicalDocumentUploadFlowStep(MedicalDocumentUploadFlowStepKind.SAVE)
    ];
  }

  static label(kind: MedicalDocumentUploadFlowStepKind): string {
    switch (kind) {
      case MedicalDocumentUploadFlowStepKind.UPLOAD:
        return '上传文件';
      case MedicalDocumentUploadFlowStepKind.OCR:
        return 'OCR 识别';
      case MedicalDocumentUploadFlowStepKind.TYPE_RECOGNITION:
        return '类型判定';
      case MedicalDocumentUploadFlowStepKind.EXTRACT:
        return '结构化抽取';
      case MedicalDocumentUploadFlowStepKind.ATTACHMENT_BINDING:
        return '附件绑定';
      case MedicalDocumentUploadFlowStepKind.SAVE:
        return '保存结果';
      default:
        return kind;
    }
  }

  static outcomeLabel(outcome: MedicalDocumentUploadStepOutcome): string {
    switch (outcome) {
      case MedicalDocumentUploadStepOutcome.PENDING:
        return '待执行';
      case MedicalDocumentUploadStepOutcome.RUNNING:
        return '进行中';
      case MedicalDocumentUploadStepOutcome.SUCCESS:
        return '完成';
      case MedicalDocumentUploadStepOutcome.SKIPPED:
        return '已跳过';
      case MedicalDocumentUploadStepOutcome.FAILED:
        return '失败';
      default:
        return outcome;
    }
  }
}

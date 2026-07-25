import { MedicalDocumentKind } from './MedicalDocumentKind';

/**
 * 对齐 iOS `MedicalExtractionRetryFeedback`。
 * 字段保持可选，兼容 PromptLocalizer 的 `feedback.fieldPath ?? …` 写法。
 */
export class MedicalExtractionRetryFeedbackModel {
  kind: MedicalDocumentKind = MedicalDocumentKind.MEDICAL_REPORT;
  step: string = 'extract';
  errorCode: string = '';
  fieldPath?: string;
  expectedType?: string;
  actualType?: string;
  rawMessage: string = '';
  aiOutputPreview?: string;
  suggestion?: string;
  createdAt: Date = new Date();

  static make(
    kind: MedicalDocumentKind,
    step: string,
    errorCode: string,
    rawMessage: string,
    suggestion: string = '',
    fieldPath: string = '',
    aiOutputPreview: string = ''
  ): MedicalExtractionRetryFeedbackModel {
    const feedback = new MedicalExtractionRetryFeedbackModel();
    feedback.kind = kind;
    feedback.step = step;
    feedback.errorCode = errorCode;
    feedback.rawMessage = rawMessage;
    if (suggestion.length > 0) {
      feedback.suggestion = suggestion;
    }
    if (fieldPath.length > 0) {
      feedback.fieldPath = fieldPath;
    }
    if (aiOutputPreview.length > 0) {
      feedback.aiOutputPreview = aiOutputPreview;
    }
    feedback.createdAt = new Date();
    return feedback;
  }
}

/** 兼容旧 interface 命名。 */
export type MedicalExtractionRetryFeedback = MedicalExtractionRetryFeedbackModel;

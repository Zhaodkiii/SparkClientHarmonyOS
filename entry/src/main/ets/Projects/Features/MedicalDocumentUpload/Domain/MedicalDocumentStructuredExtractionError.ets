import { MedicalDocumentKind } from './MedicalDocumentKind';
import { MedicalExtractionRetryFeedbackModel } from './MedicalExtractionRetryFeedback';

/** 结构化抽取失败码。 */
export type MedicalDocumentStructuredExtractionErrorCode =
  'empty_input' |
  'unknown_kind' |
  'account_missing' |
  'runtime_failed' |
  'empty_output' |
  'invalid_json' |
  'schema_invalid' |
  'cancelled' |
  'unknown';

/**
 * 抽取阶段业务错误：携带可重试反馈，供 ViewModel / Banner 展示。
 */
export class MedicalDocumentStructuredExtractionError extends Error {
  code: MedicalDocumentStructuredExtractionErrorCode;
  fieldPath: string;
  retryable: boolean;
  feedback?: MedicalExtractionRetryFeedbackModel;

  constructor(
    code: MedicalDocumentStructuredExtractionErrorCode,
    message: string,
    fieldPath: string = '',
    retryable: boolean = true,
    feedback?: MedicalExtractionRetryFeedbackModel
  ) {
    super(message);
    this.name = 'MedicalDocumentStructuredExtractionError';
    this.code = code;
    this.fieldPath = fieldPath;
    this.retryable = retryable;
    this.feedback = feedback;
  }

  static emptyInput(kind: MedicalDocumentKind): MedicalDocumentStructuredExtractionError {
    const feedback = MedicalExtractionRetryFeedbackModel.make(
      kind,
      'extract',
      'empty_input',
      'OCR 文本为空，无法抽取',
      '请返回重新上传或识别后再试'
    );
    return new MedicalDocumentStructuredExtractionError(
      'empty_input',
      'OCR 文本为空，无法抽取',
      'mergedOCRText',
      true,
      feedback
    );
  }
}

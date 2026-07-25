import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import {
  MedicalDocumentStructuredExtractionError
} from '../Domain/MedicalDocumentStructuredExtractionError';
import { MedicalExtractionRetryFeedbackModel } from '../Domain/MedicalExtractionRetryFeedback';
import { MedicalDocumentStructuredJSONDecodeResult } from './MedicalDocumentStructuredJSONDecoder';
import { MedicalDocumentStructuredRuntimeResult } from './MedicalDocumentStructuredRuntimeClient';

/**
 * 抽取错误归一化：转成可重试、可展示、可记录的 StructuredExtractionError。
 */
export class MedicalDocumentExtractionErrorNormalizer {
  normalizeRuntime(
    kind: MedicalDocumentKind,
    runtime: MedicalDocumentStructuredRuntimeResult
  ): MedicalDocumentStructuredExtractionError {
    const preview = runtime.text.substring(0, 280);
    if (runtime.errorCode === 'account_missing') {
      const feedback = MedicalExtractionRetryFeedbackModel.make(
        kind, 'extract', 'account_missing', runtime.errorMessage,
        '请登录后重试抽取', '', preview
      );
      return new MedicalDocumentStructuredExtractionError(
        'account_missing', runtime.errorMessage, '', false, feedback
      );
    }
    const feedback = MedicalExtractionRetryFeedbackModel.make(
      kind, 'extract', runtime.errorCode.length > 0 ? runtime.errorCode : 'runtime_failed',
      runtime.errorMessage.length > 0 ? runtime.errorMessage : 'AI 抽取失败',
      '可重试抽取，或手动选择类型后重试', '', preview
    );
    return new MedicalDocumentStructuredExtractionError(
      'runtime_failed',
      feedback.rawMessage,
      '',
      true,
      feedback
    );
  }

  normalizeEmptyOutput(
    kind: MedicalDocumentKind,
    rawAIOutput: string
  ): MedicalDocumentStructuredExtractionError {
    const feedback = MedicalExtractionRetryFeedbackModel.make(
      kind,
      'extract',
      'empty_output',
      'AI 抽取输出为空',
      '请重试抽取；若多次失败请手动确认类型',
      'root',
      rawAIOutput.substring(0, 280)
    );
    return new MedicalDocumentStructuredExtractionError(
      'empty_output',
      'AI 抽取输出为空',
      'root',
      true,
      feedback
    );
  }

  normalizeDecode(
    kind: MedicalDocumentKind,
    decode: MedicalDocumentStructuredJSONDecodeResult,
    rawAIOutput: string
  ): MedicalDocumentStructuredExtractionError {
    const feedback = MedicalExtractionRetryFeedbackModel.make(
      kind,
      'extract',
      'invalid_json',
      decode.errorMessage.length > 0 ? decode.errorMessage : 'JSON 解码失败',
      '请重试抽取；若多次失败请手动确认类型',
      decode.fieldPath.length > 0 ? decode.fieldPath : 'root',
      rawAIOutput.substring(0, 280)
    );
    return new MedicalDocumentStructuredExtractionError(
      'invalid_json',
      feedback.rawMessage,
      feedback.fieldPath ?? 'root',
      true,
      feedback
    );
  }

  normalizeUnknown(kind: MedicalDocumentKind, error: Object | Error): MedicalDocumentStructuredExtractionError {
    if (error instanceof MedicalDocumentStructuredExtractionError) {
      return error;
    }
    const message = error instanceof Error ? error.message : `${error}`;
    if (message === 'CancellationError' || message.indexOf('cancel') >= 0) {
      return new MedicalDocumentStructuredExtractionError('cancelled', '已取消抽取', '', false);
    }
    const feedback = MedicalExtractionRetryFeedbackModel.make(
      kind, 'extract', 'unknown', message, '请重试抽取'
    );
    return new MedicalDocumentStructuredExtractionError('unknown', message, '', true, feedback);
  }
}

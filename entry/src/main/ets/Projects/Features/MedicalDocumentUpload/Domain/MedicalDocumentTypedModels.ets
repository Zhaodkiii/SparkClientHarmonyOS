import { MedicalDocumentKind } from './MedicalDocumentKind';
import { MedicalDocumentTypedDraftTree } from './MedicalDocumentRecognitionDrafts';
import { MedicalDocumentTypeResolutionSource } from './MedicalDocumentTypeResolverProtocol';
import { MedicalExtractionPromptSource } from './MedicalExtractionInputSource';
import { MedicalExtractionRetryFeedbackModel } from './MedicalExtractionRetryFeedback';

export {
  MedicalPreSubmitValidationIssue,
  MedicalPreSubmitValidationResourceType,
  MedicalPreSubmitValidationSeverity,
  MedicalPreSubmitValidationSectionID
} from './MedicalPreSubmitValidationIssue';

/** 对齐 iOS `MedicalDocumentTypeResolution`：类型识别结果检查点。 */
export class MedicalDocumentTypeResolution {
  kind: MedicalDocumentKind = MedicalDocumentKind.MEDICAL_REPORT;
  kindLabel: string = '';
  sourceLabel: string = '';
  confidence: number = 0;
  /** 仅允许 manual / localRules / ai。 */
  source: string = MedicalDocumentTypeResolutionSource.LOCAL_RULES;
  reason: string = '';
}

/**
 * Typed 抽取结果信封。对齐 iOS MedicalDocumentRecognitionEnvelope + HOS-0008 扩展。
 */
export class MedicalDocumentTypedEnvelope {
  memberID?: number;
  typeResolution: MedicalDocumentTypeResolution = new MedicalDocumentTypeResolution();
  uploadSessionId: string = '';
  ocrTextPreview: string = '';
  /** 源文件数。 */
  fileCount: number = 0;
  /** 文件边界摘要（如 File 1/2 名称）。 */
  fileBoundarySummary: string = '';
  /** 抽取输入来源。 */
  extractionSource: MedicalExtractionPromptSource = MedicalExtractionPromptSource.OCR_TEXT;
  /** 是否携带重试反馈。 */
  hasRetryFeedback: boolean = false;
}

/**
 * 统一预览载荷（兼容层）。完整业务草稿见 `typedDrafts`。
 */
export class MedicalTypedResultPayload {
  kind: MedicalDocumentKind = MedicalDocumentKind.MEDICAL_REPORT;
  title: string = '';
  summary: string = '';
  diagnosis: string = '';
  occurredAt: string = '';
  rawType: string = '';
  /** 规范化后的完整 JSON 对象/数组字符串。 */
  fieldsJSON: string = '{}';
  /** items 数组（若存在）的 JSON 字符串。 */
  itemsJSON: string = '[]';
  warningCount: number = 0;
  warnings: string[] = [];
}

/**
 * 对齐 iOS `MedicalDocumentTypedExtractionOutput`。
 * `typedResult` = 预览壳；`typedDrafts` = 分类型草稿树。
 */
export class MedicalDocumentTypedExtractionOutput {
  envelope: MedicalDocumentTypedEnvelope = new MedicalDocumentTypedEnvelope();
  typedResult: MedicalTypedResultPayload = new MedicalTypedResultPayload();
  /** 分类型草稿树（HOS-MED-UPLOAD-0008）。 */
  typedDrafts: MedicalDocumentTypedDraftTree = new MedicalDocumentTypedDraftTree();
  extractedJSON: string = '';
  payloadPreview: string = '';
  source: MedicalExtractionPromptSource = MedicalExtractionPromptSource.OCR_TEXT;
  retryFeedback?: MedicalExtractionRetryFeedbackModel;
  rawAIOutput: string = '';
}

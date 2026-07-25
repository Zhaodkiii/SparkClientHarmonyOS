import { MedicalDocumentKind, medicalDocumentKindPickerLabel } from '../Domain/MedicalDocumentKind';
import { MedicalDocumentDraftBuilders } from '../Domain/MedicalDocumentDraftBuilders';
import { MedicalDocumentTypedDraftTree } from '../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalExtractionPromptSource } from '../Domain/MedicalExtractionInputSource';
import { MedicalDocumentStructuredExtractionRequest } from '../Domain/MedicalDocumentStructuredExtractionRequest';
import {
  MedicalDocumentTypedEnvelope,
  MedicalDocumentTypedExtractionOutput,
  MedicalTypedResultPayload
} from '../Domain/MedicalDocumentTypedModels';
import { MedicalDocumentStructuredJSONDecodeResult } from './MedicalDocumentStructuredJSONDecoder';

/**
 * 将解码后的 JSON 映射为 Typed 输出：
 * 1) 分类型草稿树 typedDrafts（HOS-0008）
 * 2) 统一预览壳 typedResult（兼容结果页）
 */
export class MedicalDocumentTypedResultMapper {
  static map(
    request: MedicalDocumentStructuredExtractionRequest,
    kind: MedicalDocumentKind,
    decode: MedicalDocumentStructuredJSONDecodeResult,
    rawAIOutput: string
  ): MedicalDocumentTypedExtractionOutput {
    const output = new MedicalDocumentTypedExtractionOutput();
    const envelope = new MedicalDocumentTypedEnvelope();
    envelope.memberID = request.memberId;
    envelope.uploadSessionId = request.uploadSessionId;
    envelope.ocrTextPreview = request.mergedOCRText.substring(0, 400);
    envelope.fileCount = request.files.length;
    envelope.fileBoundarySummary =
      MedicalDocumentTypedResultMapper.buildFileBoundarySummary(request);
    envelope.extractionSource = request.promptSource;
    envelope.hasRetryFeedback = false;
    if (request.typeResolution !== undefined) {
      envelope.typeResolution = request.typeResolution;
    } else {
      envelope.typeResolution.kind = kind;
      envelope.typeResolution.kindLabel = medicalDocumentKindPickerLabel(kind);
    }
    output.envelope = envelope;
    output.source = request.promptSource;
    output.rawAIOutput = rawAIOutput;
    output.extractedJSON = decode.canonicalJSON;

    // 分类型草稿树
    const drafts = MedicalDocumentDraftBuilders.buildTree(kind, decode.canonicalJSON);
    output.typedDrafts = drafts;

    // 预览壳：优先从草稿树推导，再回退 JSON 字段
    const payload = new MedicalTypedResultPayload();
    payload.kind = drafts.kind;
    payload.fieldsJSON = decode.canonicalJSON;
    payload.title = drafts.displayTitle();
    payload.summary = drafts.displaySummary();
    if (payload.title.length === 0 || payload.summary.length === 0) {
      MedicalDocumentTypedResultMapper.fillPreviewFromDecode(payload, kind, decode);
    }
    if (decode.isArray) {
      payload.itemsJSON = decode.canonicalJSON;
    } else {
      const items = decode.objectFields.get('items');
      if (items !== undefined && items.length > 0) {
        payload.itemsJSON = items;
      }
      payload.diagnosis = decode.objectFields.get('diagnosis') ??
        decode.objectFields.get('初步诊断') ??
        (drafts.caseDraft?.diagnosis ?? '');
      payload.occurredAt = decode.objectFields.get('occurredAt') ??
        decode.objectFields.get('date') ??
        decode.objectFields.get('examDate') ??
        (drafts.caseDraft?.occurredAt ?? '');
      payload.rawType = decode.objectFields.get('rawType') ??
        decode.objectFields.get('type') ?? drafts.kind;
    }
    const warnings: string[] = [];
    if (payload.title.length === 0) {
      warnings.push('title');
    }
    if (payload.summary.length === 0 && payload.diagnosis.length === 0) {
      warnings.push('summary/diagnosis');
    }
    MedicalDocumentTypedResultMapper.appendDraftWarnings(warnings, drafts.kind, drafts);
    payload.warnings = warnings;
    payload.warningCount = warnings.length;
    output.typedResult = payload;
    output.payloadPreview = MedicalDocumentTypedResultMapper.buildPreview(
      request.memberId,
      drafts.kind,
      envelope.typeResolution.source,
      envelope.typeResolution.confidence,
      request.promptSource,
      decode.canonicalJSON,
      payload.title
    );
    return output;
  }

  private static fillPreviewFromDecode(
    payload: MedicalTypedResultPayload,
    kind: MedicalDocumentKind,
    decode: MedicalDocumentStructuredJSONDecodeResult
  ): void {
    if (decode.isArray) {
      if (payload.title.length === 0) {
        payload.title = medicalDocumentKindPickerLabel(kind);
      }
      if (payload.summary.length === 0) {
        payload.summary =
          `已抽取 ${MedicalDocumentTypedResultMapper.arrayLength(decode.canonicalJSON)} 条记录`;
      }
      return;
    }
    if (payload.title.length === 0) {
      payload.title = decode.objectFields.get('title') ??
        decode.objectFields.get('name') ??
        medicalDocumentKindPickerLabel(kind);
    }
    if (payload.summary.length === 0) {
      payload.summary = decode.objectFields.get('summary') ??
        decode.objectFields.get('conclusion') ??
        decode.objectFields.get('impression') ?? '';
    }
  }

  private static appendDraftWarnings(
    warnings: string[],
    kind: MedicalDocumentKind,
    drafts: MedicalDocumentTypedDraftTree
  ): void {
    if (kind === MedicalDocumentKind.CASE_DOCUMENT &&
      (drafts.caseDraft === undefined || drafts.caseDraft.title.length === 0)) {
      warnings.push('caseDraft.title');
    }
    if (kind === MedicalDocumentKind.HEALTH_EXAM_REPORT &&
      drafts.healthExamDraft !== undefined &&
      drafts.healthExamDraft.items.length === 0) {
      warnings.push('healthExamDraft.items');
    }
    if (kind === MedicalDocumentKind.PRESCRIPTION && drafts.prescriptionDrafts.length === 0) {
      warnings.push('prescriptionDrafts');
    }
    if (kind === MedicalDocumentKind.MEDICATION_PLAN && drafts.medicationPlanDrafts.length === 0) {
      warnings.push('medicationPlanDrafts');
    }
    if (kind === MedicalDocumentKind.MEDICINE_BOX && drafts.medicineBoxDrafts.length === 0) {
      warnings.push('medicineBoxDrafts');
    }
  }

  private static buildFileBoundarySummary(
    request: MedicalDocumentStructuredExtractionRequest
  ): string {
    const parts: string[] = [];
    const limit = Math.min(request.files.length, 3);
    for (let i = 0; i < limit; i++) {
      const name = request.files[i].originalName.length > 0 ?
        request.files[i].originalName : `file_${i + 1}`;
      parts.push(`File ${i + 1}: ${name}`);
    }
    if (request.files.length > 3) {
      parts.push(`…+${request.files.length - 3}`);
    }
    return parts.join(' | ');
  }

  private static arrayLength(json: string): number {
    try {
      const arr = JSON.parse(json) as Object[];
      return Array.isArray(arr) ? arr.length : 0;
    } catch (_e) {
      return 0;
    }
  }

  private static buildPreview(
    memberId: number,
    kind: MedicalDocumentKind,
    resolutionSource: string,
    confidence: number,
    promptSource: MedicalExtractionPromptSource,
    payloadJSON: string,
    title: string
  ): string {
    const clipped = payloadJSON.length > 1200 ?
      `${payloadJSON.substring(0, 1200)}…` : payloadJSON;
    return `{\n` +
      `  "memberID": ${memberId},\n` +
      `  "kind": "${kind}",\n` +
      `  "title": ${JSON.stringify(title)},\n` +
      `  "resolutionSource": "${resolutionSource}",\n` +
      `  "confidence": ${confidence.toFixed(2)},\n` +
      `  "extractionInputSource": "${promptSource}",\n` +
      `  "payload": ${clipped}\n` +
      `}`;
  }
}

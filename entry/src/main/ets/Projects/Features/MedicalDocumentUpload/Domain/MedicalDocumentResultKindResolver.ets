import { MedicalDocumentKind } from './MedicalDocumentKind';
import {
  MedicalDocumentTypeResolution,
  MedicalDocumentTypedExtractionOutput
} from './MedicalDocumentTypedModels';
import { MedicalUploadL10n } from './SupportingModels';

/**
 * 结果页分流：优先 typedDrafts.kind，其次 typeResolution，再次用户选择。
 * AUTO / 未知 → 走统一 Typed 兜底页。
 */
export class MedicalDocumentResultKindResolver {
  static resolve(
    output?: MedicalDocumentTypedExtractionOutput,
    typeResolution?: MedicalDocumentTypeResolution,
    selectedKind: MedicalDocumentKind = MedicalDocumentKind.AUTO
  ): MedicalDocumentKind {
    if (output !== undefined) {
      const fromDraft = output.typedDrafts.kind;
      if (fromDraft !== MedicalDocumentKind.AUTO &&
        MedicalDocumentResultKindResolver.isRoutable(fromDraft)) {
        return fromDraft;
      }
      const fromPreview = output.typedResult.kind;
      if (fromPreview !== MedicalDocumentKind.AUTO &&
        MedicalDocumentResultKindResolver.isRoutable(fromPreview)) {
        return fromPreview;
      }
    }
    if (typeResolution !== undefined &&
      typeResolution.kind !== MedicalDocumentKind.AUTO &&
      MedicalDocumentResultKindResolver.isRoutable(typeResolution.kind)) {
      return typeResolution.kind;
    }
    if (selectedKind !== MedicalDocumentKind.AUTO &&
      MedicalDocumentResultKindResolver.isRoutable(selectedKind)) {
      return selectedKind;
    }
    return MedicalDocumentKind.AUTO;
  }

  static isRoutable(kind: MedicalDocumentKind): boolean {
    return kind === MedicalDocumentKind.CASE_DOCUMENT ||
      kind === MedicalDocumentKind.HEALTH_EXAM_REPORT ||
      kind === MedicalDocumentKind.MEDICAL_REPORT ||
      kind === MedicalDocumentKind.PRESCRIPTION ||
      kind === MedicalDocumentKind.MEDICATION_PLAN ||
      kind === MedicalDocumentKind.MEDICINE_BOX;
  }

  static kindLabel(kind: MedicalDocumentKind): string {
    switch (kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        return '病例';
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        return '体检报告';
      case MedicalDocumentKind.MEDICAL_REPORT:
        return '检查报告';
      case MedicalDocumentKind.PRESCRIPTION:
        return '处方';
      case MedicalDocumentKind.MEDICATION_PLAN:
        return '用药计划';
      case MedicalDocumentKind.MEDICINE_BOX:
        return '药箱';
      default:
        return '未识别';
    }
  }

  /**
   * 结果页导航标题。对齐 iOS 各 `*RecognitionResultView.navigationTitle`。
   * picking/processing 阶段仍使用 `medical.upload.title`（AI 上传报告）。
   */
  static resultNavTitle(kind: MedicalDocumentKind): string {
    switch (kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        return MedicalUploadL10n.text('medical.upload.result.case.nav_title', '病例');
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        return MedicalUploadL10n.text('medical.upload.result.health_exam.nav_title', '体检报告');
      case MedicalDocumentKind.MEDICAL_REPORT:
        return MedicalUploadL10n.text('medical.upload.result.medical_report.nav_title', '检查报告');
      case MedicalDocumentKind.PRESCRIPTION:
        return MedicalUploadL10n.text('common.prescription', '处方');
      case MedicalDocumentKind.MEDICATION_PLAN:
        return MedicalUploadL10n.text('common.medicationPlan', '服药计划');
      case MedicalDocumentKind.MEDICINE_BOX:
        return MedicalUploadL10n.text('home.medical.list.medicine_box.title', '药箱');
      default:
        return MedicalUploadL10n.text('medical.upload.title', 'AI 上传报告');
    }
  }
}

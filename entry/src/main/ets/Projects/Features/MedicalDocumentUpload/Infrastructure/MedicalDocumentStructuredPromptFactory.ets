import { AIScenario } from '../../../../Core/AI/Domain/AIConfigModels';
import { PromptLocalizer } from '../../../../Core/AI/Runtime/PromptLocalizer';
import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import { MedicalExtractionPromptSource } from '../Domain/MedicalExtractionInputSource';
import { MedicalDocumentStructuredExtractionRequest } from '../Domain/MedicalDocumentStructuredExtractionRequest';

/** Prompt 工厂输出：完整 user prompt + 对应 AI 场景。 */
export class MedicalDocumentStructuredPromptBundle {
  prompt: string = '';
  scenario: string = AIScenario.MEDICAL_STRUCTURED_EXTRACTION;
  kind: MedicalDocumentKind = MedicalDocumentKind.MEDICAL_REPORT;
}

/**
 * 按文档类型组装抽取 Prompt，对齐 iOS MedicalPromptFactory。
 * 文案全部委托 PromptLocalizer，不另起常量。
 */
export class MedicalDocumentStructuredPromptFactory {
  private readonly localizer: PromptLocalizer;

  constructor(localizer: PromptLocalizer = new PromptLocalizer()) {
    this.localizer = localizer;
  }

  build(request: MedicalDocumentStructuredExtractionRequest): MedicalDocumentStructuredPromptBundle {
    const kind = request.typeResolution?.kind ?? request.selectedKind;
    const resolvedKind = kind === MedicalDocumentKind.AUTO ?
      MedicalDocumentKind.MEDICAL_REPORT : kind;
    const source = request.promptSource;
    let base = '';
    if (source === MedicalExtractionPromptSource.VISION_IMAGE) {
      base = this.visionPrompt(resolvedKind);
    } else {
      base = this.ocrPrompt(resolvedKind, request.mergedOCRText);
    }

    if (request.previousRetryFeedback !== undefined) {
      const correction = this.localizer.medicalExtractionRetryCorrectionPrompt(
        resolvedKind,
        request.previousRetryFeedback,
        source
      );
      if (correction.trim().length > 0) {
        base = `${base}\n\n---\n\n${correction}`;
      }
    }

    const bundle = new MedicalDocumentStructuredPromptBundle();
    bundle.prompt = base;
    bundle.kind = resolvedKind;
    bundle.scenario = MedicalDocumentStructuredPromptFactory.scenarioForKind(resolvedKind);
    return bundle;
  }

  private ocrPrompt(kind: MedicalDocumentKind, ocrText: string): string {
    switch (kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        return this.localizer.medicalCaseExtractionPrompt(ocrText);
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        return this.localizer.healthExamExtractionPrompt(ocrText);
      case MedicalDocumentKind.MEDICAL_REPORT:
        return this.localizer.medicalReportExtractionPrompt(ocrText);
      case MedicalDocumentKind.PRESCRIPTION:
        return this.localizer.prescriptionExtractionPrompt(ocrText);
      case MedicalDocumentKind.MEDICATION_PLAN:
        return this.localizer.medicationExtractionPrompt(ocrText);
      case MedicalDocumentKind.MEDICINE_BOX:
        return this.localizer.medicineBoxExtractionPrompt(ocrText);
      case MedicalDocumentKind.AUTO:
      default:
        return this.localizer.medicalDocumentExtractionPrompt(ocrText);
    }
  }

  private visionPrompt(kind: MedicalDocumentKind): string {
    switch (kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        return this.localizer.medicalCaseVisionExtractionPrompt();
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        return this.localizer.healthExamVisionExtractionPrompt();
      case MedicalDocumentKind.MEDICAL_REPORT:
        return this.localizer.medicalReportVisionExtractionPrompt();
      case MedicalDocumentKind.PRESCRIPTION:
        return this.localizer.prescriptionVisionExtractionPrompt();
      case MedicalDocumentKind.MEDICATION_PLAN:
        return this.localizer.medicationVisionExtractionPrompt();
      case MedicalDocumentKind.MEDICINE_BOX:
        return this.localizer.medicineBoxVisionExtractionPrompt();
      case MedicalDocumentKind.AUTO:
      default:
        return this.localizer.medicalDocumentVisionExtractionPrompt();
    }
  }

  static scenarioForKind(kind: MedicalDocumentKind): string {
    switch (kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        return AIScenario.MEDICAL_CASE_EXTRACTION;
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        return AIScenario.HEALTH_EXAM_EXTRACTION;
      case MedicalDocumentKind.MEDICAL_REPORT:
        return AIScenario.MEDICAL_REPORT_EXTRACTION;
      case MedicalDocumentKind.PRESCRIPTION:
        return AIScenario.PRESCRIPTION_EXTRACTION;
      case MedicalDocumentKind.MEDICATION_PLAN:
        return AIScenario.MEDICATION_EXTRACTION;
      case MedicalDocumentKind.MEDICINE_BOX:
        return AIScenario.MEDICINE_BOX_EXTRACTION;
      case MedicalDocumentKind.AUTO:
      default:
        return AIScenario.MEDICAL_STRUCTURED_EXTRACTION;
    }
  }
}

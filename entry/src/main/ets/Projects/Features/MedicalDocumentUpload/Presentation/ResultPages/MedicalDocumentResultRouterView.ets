import { MedicalDocumentKind } from '../../Domain/MedicalDocumentKind';
import { MedicalDocumentResultKindResolver } from '../../Domain/MedicalDocumentResultKindResolver';
import { MedicalDocumentUploadViewModel } from '../MedicalDocumentUploadViewModel';
import { MedicalDocumentTypedResultPage } from '../MedicalDocumentTypedResultPage';
import { CaseRecognitionResultView } from './CaseRecognitionResultView';
import { HealthExamRecognitionResultView } from './HealthExamRecognitionResultView';
import { MedicalReportRecognitionResultView } from './MedicalReportRecognitionResultView';
import { MedicationRecognitionResultView } from './MedicationRecognitionResultView';
import { MedicineBoxRecognitionResultView } from './MedicineBoxRecognitionResult/MedicineBoxRecognitionResultView';
import { PrescriptionRecognitionResultView } from './PrescriptionRecognitionResultView';

/**
 * 各类型识别结果路由。对齐 iOS MedicalDocumentResultRouterView。
 * AUTO / 未知 → 统一 Typed 兜底页。
 */
@Component
export struct MedicalDocumentResultRouterView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  private routeKind(): MedicalDocumentKind {
    return MedicalDocumentResultKindResolver.resolve(
      this.viewModel.typedOutput,
      this.viewModel.typeResolution,
      this.viewModel.selectedKind
    );
  }

  build() {
    if (this.routeKind() === MedicalDocumentKind.CASE_DOCUMENT) {
      CaseRecognitionResultView({ viewModel: this.viewModel })
    } else if (this.routeKind() === MedicalDocumentKind.HEALTH_EXAM_REPORT) {
      HealthExamRecognitionResultView({ viewModel: this.viewModel })
    } else if (this.routeKind() === MedicalDocumentKind.MEDICAL_REPORT) {
      MedicalReportRecognitionResultView({ viewModel: this.viewModel })
    } else if (this.routeKind() === MedicalDocumentKind.PRESCRIPTION) {
      PrescriptionRecognitionResultView({ viewModel: this.viewModel })
    } else if (this.routeKind() === MedicalDocumentKind.MEDICATION_PLAN) {
      MedicationRecognitionResultView({ viewModel: this.viewModel })
    } else if (this.routeKind() === MedicalDocumentKind.MEDICINE_BOX) {
      MedicineBoxRecognitionResultView({ viewModel: this.viewModel })
    } else {
      MedicalDocumentTypedResultPage({
        typedOutputJson: this.viewModel.typedOutput?.extractedJSON ?? '',
        typeLabel: this.viewModel.typeResolution?.kindLabel ??
          MedicalDocumentResultKindResolver.kindLabel(this.routeKind()),
        ocrPreview: this.viewModel.pipelineOCRText ?? '',
        resultTitle: this.viewModel.typedOutput?.typedResult.title ?? '',
        resultSummary: this.viewModel.typedOutput?.typedResult.summary ?? '',
        warningText: (this.viewModel.typedOutput?.typedResult.warnings ?? []).join('、'),
        payloadPreview: this.viewModel.typedOutput?.payloadPreview ?? '',
        hasExtractedJson: (this.viewModel.typedOutput?.extractedJSON.length ?? 0) > 0,
        validationIssueLines: this.viewModel.preSubmitValidationIssueLines(),
        canAttemptSave: this.viewModel.canAttemptSave,
        onReturnPicking: () => this.viewModel.returnToPickingPreservingFiles(),
        onAttemptSave: () => {
          this.viewModel.attemptSave();
        }
      })
    }
  }
}

import {
  MedicationPlanRecognitionDraft,
  PrescriptionRecognitionDraft
} from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';

export class PrescriptionRecognitionResultSupport {
  static batches(viewModel: MedicalDocumentUploadViewModel): PrescriptionRecognitionDraft[] {
    const tree = viewModel.ensureTypedDraftTree(MedicalDocumentKind.PRESCRIPTION);
    return tree.prescriptionDrafts;
  }

  static ensureFirst(viewModel: MedicalDocumentUploadViewModel): PrescriptionRecognitionDraft {
    const tree = viewModel.ensureTypedDraftTree(MedicalDocumentKind.PRESCRIPTION);
    if (tree.prescriptionDrafts.length === 0) {
      tree.prescriptionDrafts.push(new PrescriptionRecognitionDraft());
    }
    return tree.prescriptionDrafts[0];
  }

  static err(viewModel: MedicalDocumentUploadViewModel, fieldKey: string): string {
    return viewModel.preSubmitIssueMessage(fieldKey);
  }
}

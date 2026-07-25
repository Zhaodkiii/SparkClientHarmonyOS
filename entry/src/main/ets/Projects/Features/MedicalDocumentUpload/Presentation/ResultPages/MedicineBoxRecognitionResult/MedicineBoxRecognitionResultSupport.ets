import { MedicineBoxRecognitionDraft } from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';

export class MedicineBoxRecognitionResultSupport {
  static boxes(viewModel: MedicalDocumentUploadViewModel): MedicineBoxRecognitionDraft[] {
    const tree = viewModel.ensureTypedDraftTree(MedicalDocumentKind.MEDICINE_BOX);
    return tree.medicineBoxDrafts;
  }

  static ensureFirst(viewModel: MedicalDocumentUploadViewModel): MedicineBoxRecognitionDraft {
    const tree = viewModel.ensureTypedDraftTree(MedicalDocumentKind.MEDICINE_BOX);
    if (tree.medicineBoxDrafts.length === 0) {
      tree.medicineBoxDrafts.push(new MedicineBoxRecognitionDraft());
    }
    return tree.medicineBoxDrafts[0];
  }

  static err(viewModel: MedicalDocumentUploadViewModel, fieldKey: string): string {
    return viewModel.preSubmitIssueMessage(fieldKey);
  }
}

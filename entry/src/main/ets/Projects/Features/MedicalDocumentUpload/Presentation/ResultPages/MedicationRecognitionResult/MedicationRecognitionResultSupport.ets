import { MedicationPlanRecognitionDraft } from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';

export class MedicationRecognitionResultSupport {
  static plans(viewModel: MedicalDocumentUploadViewModel): MedicationPlanRecognitionDraft[] {
    const tree = viewModel.ensureTypedDraftTree(MedicalDocumentKind.MEDICATION_PLAN);
    return tree.medicationPlanDrafts;
  }

  static ensureFirst(viewModel: MedicalDocumentUploadViewModel): MedicationPlanRecognitionDraft {
    const tree = viewModel.ensureTypedDraftTree(MedicalDocumentKind.MEDICATION_PLAN);
    if (tree.medicationPlanDrafts.length === 0) {
      tree.medicationPlanDrafts.push(new MedicationPlanRecognitionDraft());
    }
    return tree.medicationPlanDrafts[0];
  }

  static err(viewModel: MedicalDocumentUploadViewModel, fieldKey: string): string {
    return viewModel.preSubmitIssueMessage(fieldKey);
  }

  static reminderText(plan: MedicationPlanRecognitionDraft): string {
    const times = plan.reminderTimes ?? [];
    if (times.length === 0) {
      return '';
    }
    const parts: string[] = [];
    for (let i = 0; i < times.length; i++) {
      parts.push(times[i].time);
    }
    return parts.join('、');
  }
}

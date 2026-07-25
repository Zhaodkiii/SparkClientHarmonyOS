import { CaseRecognitionDraft } from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';

export class CaseRecognitionResultSupport {
  static ensureDraft(viewModel: MedicalDocumentUploadViewModel): CaseRecognitionDraft {
    const tree = viewModel.ensureTypedDraftTree(MedicalDocumentKind.CASE_DOCUMENT);
    if (tree.caseDraft === undefined) {
      tree.caseDraft = new CaseRecognitionDraft();
    }
    return tree.caseDraft;
  }

  static err(viewModel: MedicalDocumentUploadViewModel, fieldKey: string): string {
    return viewModel.preSubmitIssueMessage(fieldKey);
  }

  static fieldScroll(fieldKey: string): string {
    return `preSubmitValidation.field.${fieldKey}`;
  }
}

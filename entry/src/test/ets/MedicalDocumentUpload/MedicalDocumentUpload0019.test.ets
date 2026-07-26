import { describe, it, expect } from '@ohos/hypium';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { MedicineBoxRecognitionDraft } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import {
  MedicalDocumentTypedExtractionOutput,
  MedicalDocumentTypedEnvelope
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentTypedModels';
import { MedicalAttachmentInput } from '../../../main/ets/Projects/Features/Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicineBoxRecognitionResultSupport } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicineBoxRecognitionResult/MedicineBoxRecognitionResultSupport';
import { MedicineBoxRecognitionResultRoutes } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicineBoxRecognitionResult/MedicineBoxRecognitionResultRoutes';
import { MedicalUploadL10n } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/SupportingModels';

class MedicineBoxResultViewModelStub {
  typedOutput?: MedicalDocumentTypedExtractionOutput;
  selectedFiles: MedicalAttachmentInput[] = [];
  selectedMemberID: number = 10;
  preSubmitValidationIssues: object[] = [];

  ensureTypedDraftTree(kind: MedicalDocumentKind) {
    if (this.typedOutput === undefined) {
      const output = new MedicalDocumentTypedExtractionOutput();
      output.envelope = new MedicalDocumentTypedEnvelope();
      output.typedDrafts.kind = kind;
      this.typedOutput = output;
    }
    return this.typedOutput.typedDrafts;
  }

  notifyTypedDraftChanged(): void {
  }

  preSubmitIssueMessage(_fieldKey: string): string {
    return '';
  }
}

export default function medicalDocumentUpload0019Test() {
  describe('HOS_MED_UPLOAD_0019_MEDICINE_BOX_RESULT_PAGE', () => {
    it('routes_and_targets_are_registered', 0, () => {
      expect(MedicineBoxRecognitionResultRoutes.LOCAL_DRAFT_DETAIL)
        .assertEqual('medical.upload.result.medicine_box.local_draft_detail');
    });

    it('support_helpers_cover_attachments_and_drafts', 0, () => {
      const vm = new MedicineBoxResultViewModelStub();
      const tree = vm.ensureTypedDraftTree(MedicalDocumentKind.MEDICINE_BOX);
      const draft = new MedicineBoxRecognitionDraft();
      draft.medicineName = '布洛芬';
      draft.attachmentFileIds = ['f1'];
      tree.medicineBoxDrafts.push(draft);

      const file = new MedicalAttachmentInput();
      file.previewId = 'f1';
      file.originalName = '药盒.jpg';
      vm.selectedFiles.push(file);

      const unlinkedFile = new MedicalAttachmentInput();
      unlinkedFile.previewId = 'f2';
      unlinkedFile.originalName = '未关联.pdf';
      vm.selectedFiles.push(unlinkedFile);

      expect(MedicineBoxRecognitionResultSupport.boxes(vm as object).length).assertEqual(1);
      expect(MedicineBoxRecognitionResultSupport.unlinkedAttachments(
        vm as object, tree.medicineBoxDrafts).length).assertEqual(1);
      expect(MedicineBoxRecognitionResultSupport.matchedAttachments(
        vm as object, ['f1']).length).assertEqual(1);
      expect(MedicineBoxRecognitionResultSupport.temporaryMedicineBoxID(0)).assertEqual(-20000);
    });

    it('l10n_keys_for_medicine_box_result_page_exist', 0, () => {
      expect(MedicalUploadL10n.text('medical.upload.result.medicine_box.member.title'))
        .assertEqual('确认成员');
      expect(MedicalUploadL10n.text('medical.upload.result.medicine_box.empty'))
        .assertEqual('暂无药品');
      expect(MedicalUploadL10n.text('medical.upload.result.medicine_box.section.title'))
        .assertEqual('药箱药品');
    });
  });
}

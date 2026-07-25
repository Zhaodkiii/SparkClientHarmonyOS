import { describe, it, expect } from '@ohos/hypium';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { MedicalDocumentDraftBuilders } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentDraftBuilders';
import {
  MedicalDocumentAttachmentBusinessTypes,
  MedicalDocumentSaveReceipt
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentAttachmentBindingModels';
import {
  MedicalDocumentSaveError,
  TypedMedicalDocumentSaving
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/TypedMedicalDocumentSaving';
import { MedicalDocumentTypedExtractionOutput } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentTypedModels';
import { MedicalDocumentDraftMappers } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentDraftMappers';
import { MedicalAttachmentInput } from '../../../main/ets/Projects/Features/Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { ManagedFileRecord } from '../../../main/ets/Core/FileStorage/FileStorageModels';
import { SaveTypedMedicalDocumentUseCase } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Application/SaveTypedMedicalDocumentUseCase';

class FakeSaver implements TypedMedicalDocumentSaving {
  lastKind: MedicalDocumentKind = MedicalDocumentKind.AUTO;
  lastFileCount: number = 0;

  async save(
    output: MedicalDocumentTypedExtractionOutput,
    sourceFiles: MedicalAttachmentInput[]
  ): Promise<MedicalDocumentSaveReceipt> {
    this.lastKind = output.typedDrafts.kind;
    this.lastFileCount = sourceFiles.length;
    const receipt = new MedicalDocumentSaveReceipt();
    receipt.isSuccess = true;
    receipt.recordID = 99;
    receipt.kind = output.typedDrafts.kind;
    receipt.savedAt = '2026-07-25T00:00:00.000Z';
    receipt.message = 'ok';
    return receipt;
  }
}

export default function medicalDocumentUpload0009Test() {
  describe('HOS_MED_UPLOAD_0009_SAVE', () => {
    it('save_error_factories', 0, () => {
      const noMember = MedicalDocumentSaveError.noMember();
      expect(noMember.code).assertEqual('no_member');
      const empty = MedicalDocumentSaveError.emptyDraft(MedicalDocumentKind.PRESCRIPTION);
      expect(empty.code).assertEqual('empty_draft');
    });

    it('business_types_map_for_bind', 0, () => {
      expect(MedicalDocumentAttachmentBusinessTypes.forKind(MedicalDocumentKind.CASE_DOCUMENT))
        .assertEqual('medical_case');
      expect(MedicalDocumentAttachmentBusinessTypes.forKind(MedicalDocumentKind.HEALTH_EXAM_REPORT))
        .assertEqual('health_exam_report');
      expect(MedicalDocumentAttachmentBusinessTypes.forKind(MedicalDocumentKind.MEDICAL_REPORT))
        .assertEqual('examination_report');
      expect(MedicalDocumentAttachmentBusinessTypes.forKind(MedicalDocumentKind.PRESCRIPTION))
        .assertEqual('prescription_batch');
      expect(MedicalDocumentAttachmentBusinessTypes.forKind(MedicalDocumentKind.MEDICATION_PLAN))
        .assertEqual('medication_plan');
      expect(MedicalDocumentAttachmentBusinessTypes.forKind(MedicalDocumentKind.MEDICINE_BOX))
        .assertEqual('medicine_box');
    });

    it('draft_mappers_ready_for_save_payloads', 0, () => {
      const caseTree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.CASE_DOCUMENT,
        JSON.stringify({
          title: '门诊病历',
          diagnosis: '上感',
          hospitalName: '独墅湖医院',
          ageAtVisit: '27',
          occurredAt: '2025-12-28'
        })
      );
      const caseReq = MedicalDocumentDraftMappers.caseToCreateRequest(caseTree.caseDraft!);
      expect(caseReq.title).assertEqual('门诊病历');
      expect(caseReq.hospitalName).assertEqual('独墅湖医院');
      expect(caseReq.ageAtVisit).assertEqual(27);
      expect(caseReq.extra.get('occurred_at')).assertEqual('2025-12-28');

      const examTree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.HEALTH_EXAM_REPORT,
        JSON.stringify({
          institution_name: '独墅湖医院',
          exam_date: '2025-12-28',
          items: [{ item_name: 'ALT', result_value: '14.6', unit: 'U/L' }]
        })
      );
      expect(examTree.healthExamDraft !== undefined).assertTrue();
      expect(examTree.healthExamDraft!.items.length).assertEqual(1);

      const rxTree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.PRESCRIPTION,
        JSON.stringify([{
          diagnosis: '上感',
          prescribedAt: '2025-12-28',
          medicationPlans: [{ medicineName: '阿莫西林', frequencyType: '每天', doseValue: '1' }]
        }])
      );
      expect(rxTree.prescriptionDrafts.length).assertEqual(1);
      const rxReq = MedicalDocumentDraftMappers.prescriptionToCreateRequest(rxTree.prescriptionDrafts[0]);
      expect(rxReq.medicationPlans.length).assertEqual(1);
      expect(rxReq.medicationPlans[0].frequencyType).assertEqual('daily');
    });

    it('save_use_case_delegates_to_saver', 0, async () => {
      const fake = new FakeSaver();
      const useCase = new SaveTypedMedicalDocumentUseCase(fake);
      const output = new MedicalDocumentTypedExtractionOutput();
      output.typedDrafts.kind = MedicalDocumentKind.MEDICINE_BOX;
      output.envelope.memberID = 7;
      const file = new MedicalAttachmentInput();
      file.previewId = 'p1';
      const remote = new ManagedFileRecord();
      remote.id = 55;
      remote.fileUuid = 'uuid-55';
      file.remoteFile = remote;
      const receipt = await useCase.execute(output, [file]);
      expect(receipt.isSuccess).assertTrue();
      expect(receipt.recordID).assertEqual(99);
      expect(fake.lastKind).assertEqual(MedicalDocumentKind.MEDICINE_BOX);
      expect(fake.lastFileCount).assertEqual(1);
    });

    it('receipt_model_fields', 0, () => {
      const receipt = new MedicalDocumentSaveReceipt();
      receipt.recordID = 12;
      receipt.kind = MedicalDocumentKind.HEALTH_EXAM_REPORT;
      receipt.isSuccess = true;
      receipt.message = '体检报告已保存';
      expect(receipt.recordID).assertEqual(12);
      expect(receipt.kind).assertEqual(MedicalDocumentKind.HEALTH_EXAM_REPORT);
      expect(receipt.isSuccess).assertTrue();
    });
  });
}

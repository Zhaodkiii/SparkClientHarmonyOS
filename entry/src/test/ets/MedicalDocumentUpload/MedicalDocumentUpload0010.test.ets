import { describe, it, expect } from '@ohos/hypium';
import { ManagedFileRecord } from '../../../main/ets/Core/FileStorage/FileStorageModels';
import { MedicalAttachmentInput } from '../../../main/ets/Projects/Features/Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalAttachmentBindingBridge } from '../../../main/ets/Projects/Features/Home/Presentation/MedicalLists/Shared/MedicalAttachmentBindingBridge';
import { MedicalDocumentAttachmentBindingMapper } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentAttachmentBindingMapper';
import {
  MedicalDocumentAttachmentBusinessTypes,
  MedicalDocumentSaveReceipt
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentAttachmentBindingModels';
import { MedicalDocumentAttachmentBusinessMatcher } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentAttachmentBusinessMatcher';
import { MedicalDocumentDraftBuilders } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentDraftBuilders';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import {
  HealthExamRecognitionDraft,
  MedicineBoxRecognitionDraft
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentTypedExtractionOutput } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentTypedModels';
import {
  HealthExamSavePayload,
  MedicineBoxWritePayload
} from '../../../main/ets/Projects/Core/Networking/API/Medical/MedicalWorkflowAPI';

function makeFile(previewId: string, ocrText: string, remoteId: number): MedicalAttachmentInput {
  const input = new MedicalAttachmentInput();
  input.previewId = previewId;
  input.sourceUri = `file://${previewId}.jpg`;
  input.originalName = `${previewId}.jpg`;
  input.mimeType = 'image/jpeg';
  input.ocrText = ocrText;
  if (remoteId > 0) {
    const remote = new ManagedFileRecord();
    remote.id = remoteId;
    remote.fileUuid = `uuid-${remoteId}`;
    remote.businessType = 'medical_document_upload_source';
    input.remoteFile = remote;
  }
  return input;
}

export default function medicalDocumentUpload0010Test() {
  describe('HOS_MED_UPLOAD_0010_ATTACHMENT_BINDING', () => {
    it('business_type_map_aligns_ios', 0, () => {
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

    it('draft_builders_keep_attachment_file_ids_on_all_kinds', 0, () => {
      const kinds: MedicalDocumentKind[] = [
        MedicalDocumentKind.CASE_DOCUMENT,
        MedicalDocumentKind.HEALTH_EXAM_REPORT,
        MedicalDocumentKind.MEDICAL_REPORT,
        MedicalDocumentKind.PRESCRIPTION,
        MedicalDocumentKind.MEDICATION_PLAN,
        MedicalDocumentKind.MEDICINE_BOX
      ];
      const jsons: string[] = [
        JSON.stringify({ title: '病历', attachmentFileIds: ['a1'] }),
        JSON.stringify({ institution_name: '医院', attachment_file_ids: ['h1'] }),
        JSON.stringify([{ title: '血常规', attachmentFileIds: ['r1'] }]),
        JSON.stringify([{ prescriptionNo: 'RX1', attachmentFileIds: ['p1'] }]),
        JSON.stringify([{ medicineName: '阿莫西林', attachmentFileIds: ['m1'] }]),
        JSON.stringify([{ medicineName: '布洛芬', attachmentFileIds: ['b1'] }])
      ];
      for (let i = 0; i < kinds.length; i++) {
        const tree = MedicalDocumentDraftBuilders.buildTree(kinds[i], jsons[i]);
        expect(tree.kind).assertEqual(kinds[i]);
        const ids = MedicalDocumentAttachmentBindingMapper.collectMatchedLocalIds(tree);
        expect(ids.length > 0).assertTrue();
      }
    });

    it('matcher_does_not_mutate_input_output', 0, () => {
      const tree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.HEALTH_EXAM_REPORT,
        JSON.stringify({ institution_name: '独墅湖医院', summary: '大致正常' })
      );
      const output = new MedicalDocumentTypedExtractionOutput();
      output.typedDrafts = tree;
      const beforeCount = output.typedDrafts.healthExamDraft!.attachmentFileIds.length;
      const files = [makeFile('f-immutable', '体检报告 血红蛋白', 51)];
      const matched = MedicalDocumentAttachmentBusinessMatcher.matchAndUpdate(files, output);
      expect(output.typedDrafts.healthExamDraft!.attachmentFileIds.length).assertEqual(beforeCount);
      expect(matched.typedDrafts.healthExamDraft!.attachmentFileIds.indexOf('f-immutable') >= 0)
        .assertTrue();
    });

    it('matcher_binds_medical_report_by_ocr_title', 0, () => {
      const tree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.MEDICAL_REPORT,
        JSON.stringify([{
          title: '血常规检验报告',
          category: 'laboratory',
          details: [{ itemName: '白细胞计数', resultValue: '6.2' }]
        }])
      );
      const output = new MedicalDocumentTypedExtractionOutput();
      output.typedDrafts = tree;
      const files = [makeFile('report-ocr', '检验报告单 血常规检验报告 白细胞计数', 61)];
      const matched = MedicalDocumentAttachmentBusinessMatcher.matchAndUpdate(files, output);
      expect(matched.typedDrafts.medicalReportDrafts[0].attachmentFileIds.indexOf('report-ocr') >= 0)
        .assertTrue();
    });

    it('matcher_binds_prescription_medication_plan', 0, () => {
      const tree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.PRESCRIPTION,
        JSON.stringify([{
          prescriptionNo: 'RX-1001',
          institutionName: '独墅湖医院',
          medicationPlans: [{ medicineName: '阿莫西林胶囊', dosePerTime: '2粒' }]
        }])
      );
      const output = new MedicalDocumentTypedExtractionOutput();
      output.typedDrafts = tree;
      const files = [makeFile('rx-plan', '处方笺 阿莫西林胶囊 2粒', 71)];
      const matched = MedicalDocumentAttachmentBusinessMatcher.matchAndUpdate(files, output);
      const plans = matched.typedDrafts.prescriptionDrafts[0].medicationPlans;
      expect(plans !== undefined).assertTrue();
      expect(plans![0].attachmentFileIds.indexOf('rx-plan') >= 0).assertTrue();
    });

    it('matcher_binds_health_exam_ocr_files_to_draft', 0, () => {
      const tree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.HEALTH_EXAM_REPORT,
        JSON.stringify({ institution_name: '独墅湖医院', summary: '大致正常' })
      );
      const output = new MedicalDocumentTypedExtractionOutput();
      output.typedDrafts = tree;
      output.extractedJSON = '{}';
      const files = [
        makeFile('f1', '体检报告 血红蛋白', 11),
        makeFile('f2', '', 12)
      ];
      const matched = MedicalDocumentAttachmentBusinessMatcher.matchAndUpdate(files, output);
      expect(matched.typedDrafts.healthExamDraft !== undefined).assertTrue();
      expect(matched.typedDrafts.healthExamDraft!.attachmentFileIds.indexOf('f1') >= 0).assertTrue();
      expect(matched.typedDrafts.healthExamDraft!.attachmentFileIds.indexOf('f2') < 0).assertTrue();
    });

    it('matcher_medicine_box_fallback_first_box', 0, () => {
      const tree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.MEDICINE_BOX,
        JSON.stringify([{ medicineName: '维生素C', strength: '100mg' }])
      );
      const output = new MedicalDocumentTypedExtractionOutput();
      output.typedDrafts = tree;
      const files = [makeFile('box1', '无关文本 xyz', 21)];
      const matched = MedicalDocumentAttachmentBusinessMatcher.matchAndUpdate(files, output);
      expect(matched.typedDrafts.medicineBoxDrafts[0].attachmentFileIds.indexOf('box1') >= 0)
        .assertTrue();
    });

    it('matcher_case_fallback_to_root', 0, () => {
      const tree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.CASE_DOCUMENT,
        JSON.stringify({ title: '门诊病历', diagnosis: '上感', hospitalName: '独墅湖医院' })
      );
      const output = new MedicalDocumentTypedExtractionOutput();
      output.typedDrafts = tree;
      const files = [makeFile('c1', '门诊病历 上感 独墅湖医院', 31)];
      const matched = MedicalDocumentAttachmentBusinessMatcher.matchAndUpdate(files, output);
      expect(matched.typedDrafts.caseDraft!.attachmentFileIds.indexOf('c1') >= 0).assertTrue();
    });

    it('mapper_resolves_local_preview_id_to_remote_file_ids', 0, () => {
      const files = [
        makeFile('l1', 'ocr', 101),
        makeFile('l2', 'ocr', 102),
        makeFile('l3', 'ocr', 0)
      ];
      const remote = MedicalDocumentAttachmentBindingMapper.remoteFileIdsFromLocal(
        ['l1', 'l2', 'l3', 'l1'], files
      );
      expect(remote.length).assertEqual(2);
      expect(remote[0]).assertEqual(101);
      expect(remote[1]).assertEqual(102);
    });

    it('mapper_prepare_health_exam_and_medicine_box_payloads', 0, () => {
      const healthDraft = new HealthExamRecognitionDraft();
      healthDraft.institutionName = '独墅湖医院';
      healthDraft.attachmentFileIds = ['h1'];
      const files = [makeFile('h1', '体检', 201)];
      const healthPayload = new HealthExamSavePayload();
      MedicalDocumentAttachmentBindingMapper.applyFileIdsToHealthExamPayload(
        healthPayload, healthDraft, files
      );
      expect(healthPayload.file_ids.length).assertEqual(1);
      expect(healthPayload.file_ids[0]).assertEqual(201);

      const boxDraft = new MedicineBoxRecognitionDraft();
      boxDraft.medicineName = '布洛芬';
      const boxFiles = [makeFile('b1', '药盒', 301)];
      const boxPayload = new MedicineBoxWritePayload();
      MedicalAttachmentBindingBridge.applyMedicineBoxFileIds(
        boxPayload, boxDraft, boxFiles, true
      );
      expect(boxPayload.file_ids.length).assertEqual(1);
      expect(boxPayload.file_ids[0]).assertEqual(301);
    });

    it('mapper_prepare_summary_from_typed_drafts', 0, () => {
      const tree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.HEALTH_EXAM_REPORT,
        JSON.stringify({ institution_name: '医院', attachmentFileIds: ['x1'] })
      );
      const files = [makeFile('x1', '体检', 401), makeFile('x2', '其它', 402)];
      const prepared = MedicalDocumentAttachmentBindingMapper.prepare(tree, files);
      expect(prepared.businessType).assertEqual('health_exam_report');
      expect(prepared.remoteFileIds.indexOf(401) >= 0).assertTrue();
      expect(prepared.fileIdsForSave.indexOf(401) >= 0).assertTrue();
      const summary = MedicalDocumentAttachmentBindingMapper.buildMatchSummary(tree, files);
      expect(summary.matchedLocalFileIds.indexOf('x1') >= 0).assertTrue();
      expect(summary.unmatchedLocalFileIds.indexOf('x2') >= 0).assertTrue();
    });

    it('save_receipt_model_ready_for_post_save_bind', 0, () => {
      const receipt = new MedicalDocumentSaveReceipt();
      receipt.recordID = 99;
      receipt.isSuccess = true;
      receipt.kind = MedicalDocumentKind.MEDICINE_BOX;
      expect(receipt.isSuccess).assertTrue();
      expect(MedicalDocumentAttachmentBusinessTypes.forKind(receipt.kind))
        .assertEqual('medicine_box');
    });
  });
}

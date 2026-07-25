import { describe, it, expect } from '@ohos/hypium';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { MedicalDocumentDraftBuilders } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentDraftBuilders';
import { MedicalDocumentDraftMappers } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentDraftMappers';
import {
  EXTRA_KEY_PAYMENT_STATUS_TEXT,
  PrescriptionFieldNormalization
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/PrescriptionFieldNormalization';
import { MedicalDocumentStructuredExtractionRequest } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentStructuredExtractionRequest';
import { MedicalDocumentStructuredJSONDecoder } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/MedicalDocumentStructuredJSONDecoder';
import { MedicalDocumentTypedResultMapper } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/MedicalDocumentTypedResultMapper';

export default function medicalDocumentUpload0008Test() {
  describe('HOS_MED_UPLOAD_0008', () => {
    it('case_draft_builds_nested_tree', 0, () => {
      const json = JSON.stringify({
        title: '门诊病历',
        summary: '咳嗽三天',
        diagnosis: '上呼吸道感染',
        hospitalName: '独墅湖医院',
        ageAtVisit: '27',
        occurredAt: '2025-12-28',
        symptom: {
          name: '咳嗽',
          severity: '轻度',
          bodyPart: '咽喉',
          durationValue: '3',
          durationUnit: '天'
        },
        visit: {
          visitType: '门诊',
          department: '呼吸内科',
          doctorName: '张医生'
        },
        surgery: {
          procedureName: '无'
        },
        followUps: [{ plannedAt: '2026-01-05', status: 'planned' }],
        prescriptions: [{
          diagnosis: '上感',
          status: 'active',
          medicationPlans: [{ medicineName: '阿莫西林', frequencyType: '每天' }]
        }],
        examinationReports: [{ title: '血常规', hospital: '独墅湖医院' }]
      });
      const tree = MedicalDocumentDraftBuilders.buildTree(MedicalDocumentKind.CASE_DOCUMENT, json);
      expect(tree.caseDraft !== undefined).assertTrue();
      expect(tree.caseDraft!.title).assertEqual('门诊病历');
      expect(tree.caseDraft!.symptom!.name).assertEqual('咳嗽');
      expect(tree.caseDraft!.visit!.department).assertEqual('呼吸内科');
      expect(tree.caseDraft!.followUps!.length).assertEqual(1);
      expect(tree.caseDraft!.prescriptions!.length).assertEqual(1);
      expect(tree.caseDraft!.prescriptions![0].medicationPlans![0].frequencyType)
        .assertEqual('daily');
      expect(tree.caseDraft!.examinationReports![0].title).assertEqual('血常规');
    });

    it('health_exam_draft_with_items', 0, () => {
      const json = JSON.stringify({
        institution_name: '独墅湖医院',
        report_no: 'HE-001',
        exam_date: '2025-12-28',
        exam_type: '入职体检',
        summary: '大致正常',
        items: [{
          category: '生化',
          item_name: 'ALT',
          result_value: '14.6',
          unit: 'U/L',
          reference_range: '9-50',
          flag: 'N'
        }]
      });
      const tree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.HEALTH_EXAM_REPORT, json);
      expect(tree.healthExamDraft !== undefined).assertTrue();
      expect(tree.healthExamDraft!.institutionName).assertEqual('独墅湖医院');
      expect(tree.healthExamDraft!.reportNo).assertEqual('HE-001');
      expect(tree.healthExamDraft!.items.length).assertEqual(1);
      expect(tree.healthExamDraft!.items[0].itemName).assertEqual('ALT');
    });

    it('medical_report_array_and_item_draft_bridge', 0, () => {
      const json = JSON.stringify([{
        title: '胸部CT',
        hospital: '独墅湖医院',
        doctor: '李医生',
        content: '双肺未见明显异常',
        date: '2025-12-28',
        details: [{ category: '影像', itemName: '肺野', diagnosis: '未见异常' }]
      }]);
      const tree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.MEDICAL_REPORT, json);
      expect(tree.medicalReportDrafts.length).assertEqual(1);
      expect(tree.medicalReportDrafts[0].title).assertEqual('胸部CT');
      expect(tree.medicalReportDrafts[0].details.length).assertEqual(1);
      const item = MedicalDocumentDraftMappers.itemDraftToMedicalReportItem(
        tree.medicalReportDrafts[0].details[0], '影像', '0');
      expect(item.category).assertEqual('影像');
      expect(item.itemName).assertEqual('肺野');
    });

    it('prescription_normalization_and_save_mapping', 0, () => {
      const json = JSON.stringify({
        prescriberName: '王医生',
        institutionName: '独墅湖医院',
        prescribedAt: '2025-12-28',
        diagnosis: '口腔溃疡',
        prescriptionNo: 'RX-1',
        status: '已支付',
        medicationPlans: [{
          medicineName: '维生素B2',
          doseValue: 1,
          frequencyType: '每周',
          reminderTimes: ['08:00', { time: '20:00', dose: 1 }],
          status: '执行中'
        }]
      });
      const tree = MedicalDocumentDraftBuilders.buildTree(MedicalDocumentKind.PRESCRIPTION, json);
      expect(tree.prescriptionDrafts.length).assertEqual(1);
      const rx = tree.prescriptionDrafts[0];
      expect(rx.status).assertEqual('active');
      expect(rx.extra!.get(EXTRA_KEY_PAYMENT_STATUS_TEXT)).assertEqual('已支付');
      expect(rx.medicationPlans![0].frequencyType).assertEqual('weekly');
      expect(rx.medicationPlans![0].status).assertEqual('active');
      expect(rx.medicationPlans![0].reminderTimes!.length).assertEqual(2);

      const req = MedicalDocumentDraftMappers.prescriptionToCreateRequest(rx);
      expect(req.status).assertEqual('active');
      expect(req.medicationPlans.length).assertEqual(1);
      expect(req.medicationPlans[0].medicineName).assertEqual('维生素B2');
      expect(req.medicationPlans[0].frequencyType).assertEqual('weekly');
    });

    it('medication_plan_and_medicine_box_drafts', 0, () => {
      const planJson = JSON.stringify([{
        medicine_name: '阿司匹林',
        frequency_type: 'interval',
        every_n_days: 2,
        medicine_box: {
          medicine_name: '阿司匹林肠溶片',
          brand_name: '拜耳',
          total_quantity: 30
        }
      }]);
      const planTree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.MEDICATION_PLAN, planJson);
      expect(planTree.medicationPlanDrafts.length).assertEqual(1);
      expect(planTree.medicationPlanDrafts[0].frequencyType).assertEqual('every_n_days');
      expect(planTree.medicationPlanDrafts[0].medicineBox!.brandName).assertEqual('拜耳');

      const boxJson = JSON.stringify([{
        medicineName: '布洛芬',
        dosageForm: '胶囊',
        strength: '0.2g',
        expireDate: '2027-01-01'
      }]);
      const boxTree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.MEDICINE_BOX, boxJson);
      expect(boxTree.medicineBoxDrafts.length).assertEqual(1);
      expect(boxTree.medicineBoxDrafts[0].medicineName).assertEqual('布洛芬');
      const boxReq = MedicalDocumentDraftMappers.medicineBoxToCreateRequest(
        boxTree.medicineBoxDrafts[0]);
      expect(boxReq.dosageForm).assertEqual('胶囊');
    });

    it('case_save_mapper_merges_diagnosis_summary', 0, () => {
      const tree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.CASE_DOCUMENT,
        JSON.stringify({
          title: '病历A',
          summary: '摘要',
          diagnosis: '诊断',
          ageAtVisit: '27',
          occurredAt: '2025-12-28'
        })
      );
      const req = MedicalDocumentDraftMappers.caseToCreateRequest(tree.caseDraft!);
      expect(req.title).assertEqual('病历A');
      expect(req.diagnosisSummary).assertEqual('摘要\n诊断');
      expect(req.ageAtVisit).assertEqual(27);
      expect(req.extra.get('occurred_at')).assertEqual('2025-12-28');
    });

    it('typed_mapper_fills_draft_tree_and_preview', 0, () => {
      const request = new MedicalDocumentStructuredExtractionRequest();
      request.memberId = 450;
      request.uploadSessionId = 'sess-8';
      request.mergedOCRText = '检验报告单 ALT 14.6';
      const decode = new MedicalDocumentStructuredJSONDecoder().decode(JSON.stringify({
        title: '检验报告',
        hospital: '独墅湖医院',
        content: 'ALT 14.6',
        details: [{ itemName: 'ALT', resultValue: '14.6', unit: 'U/L' }]
      }));
      expect(decode.ok).assertTrue();
      const output = MedicalDocumentTypedResultMapper.map(
        request,
        MedicalDocumentKind.MEDICAL_REPORT,
        decode,
        '{"title":"检验报告"}'
      );
      expect(output.typedDrafts.medicalReportDrafts.length).assertEqual(1);
      expect(output.typedDrafts.medicalReportDrafts[0].title).assertEqual('检验报告');
      expect(output.typedResult.title).assertEqual('检验报告');
      expect(output.envelope.fileCount).assertEqual(0);
      expect(output.payloadPreview.indexOf('检验报告') >= 0).assertTrue();
    });

    it('frequency_and_status_normalization_edges', 0, () => {
      expect(PrescriptionFieldNormalization.normalizeFrequencyType('每天')).assertEqual('daily');
      expect(PrescriptionFieldNormalization.normalizeFrequencyType('每周')).assertEqual('weekly');
      expect(PrescriptionFieldNormalization.normalizeFrequencyType(undefined)).assertEqual('daily');
      expect(PrescriptionFieldNormalization.normalizeMedicationPlanStatus('暂停')).assertEqual('暂停');
      expect(PrescriptionFieldNormalization.normalizeMedicationPlanStatus('paused'))
        .assertEqual('paused');
      const st = PrescriptionFieldNormalization.normalizePrescriptionStatus('门诊');
      expect(st.status).assertEqual('active');
      expect(st.extraUpdates.get('prescriptionTypeText')).assertEqual('门诊');
    });
  });
}

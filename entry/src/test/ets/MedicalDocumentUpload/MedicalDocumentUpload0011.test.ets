import { describe, it, expect } from '@ohos/hypium';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { HealthExamRecognitionDraft } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentResultKindResolver } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentResultKindResolver';
import {
  MedicalPreSubmitValidationIssue,
  MedicalPreSubmitValidationResourceType,
  MedicalPreSubmitValidationSectionID
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalPreSubmitValidationIssue';
import { MedicalDocumentResultSupport } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalDocumentResultSupport';
import { CaseRecognitionResultSupport } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/CaseRecognitionResult/CaseRecognitionResultSupport';
import { HealthExamResultSupport } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/HealthExamRecognitionResult/HealthExamResultSupport';
import { MedicalReportResultSupport } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportResultSupport';
import { PrescriptionRecognitionResultSupport } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/PrescriptionRecognitionResult/PrescriptionRecognitionResultSupport';
import { MedicationRecognitionResultSupport } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicationRecognitionResult/MedicationRecognitionResultSupport';
import { MedicineBoxRecognitionResultSupport } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicineBoxRecognitionResult/MedicineBoxRecognitionResultSupport';

export default function medicalDocumentUpload0011Test() {
  describe('HOS_MED_UPLOAD_0011_RESULT_PAGES_STRUCTURE', () => {
    it('router_kind_labels_match_ios_semantics', 0, () => {
      expect(MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.CASE_DOCUMENT))
        .assertEqual('病例');
      expect(MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.HEALTH_EXAM_REPORT))
        .assertEqual('体检报告');
      expect(MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.MEDICAL_REPORT))
        .assertEqual('检查报告');
      expect(MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.PRESCRIPTION))
        .assertEqual('处方');
      expect(MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.MEDICATION_PLAN))
        .assertEqual('用药计划');
      expect(MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.MEDICINE_BOX))
        .assertEqual('药箱');
    });

    it('auto_kind_is_not_routable_and_falls_back', 0, () => {
      expect(MedicalDocumentResultKindResolver.resolve(
        undefined, undefined, MedicalDocumentKind.AUTO
      )).assertEqual(MedicalDocumentKind.AUTO);
      expect(MedicalDocumentResultKindResolver.isRoutable(MedicalDocumentKind.AUTO))
        .assertFalse();
      expect(MedicalDocumentResultKindResolver.isRoutable(MedicalDocumentKind.PRESCRIPTION))
        .assertTrue();
    });

    it('shared_scaffold_and_router_modules_registered', 0, () => {
      expect(MedicalDocumentResultSupport.TYPED_SCAFFOLD_MODULE)
        .assertEqual('MedicalDocumentTypedResultScaffoldView');
      expect(MedicalDocumentResultSupport.ROUTER_VIEW_MODULE)
        .assertEqual('MedicalDocumentResultRouterView');
    });

    it('typed_support_helpers_exist_for_each_kind', 0, () => {
      expect(CaseRecognitionResultSupport.fieldScroll('medical_case.title'))
        .assertEqual('preSubmitValidation.field.medical_case.title');
      const draft = new HealthExamRecognitionDraft();
      expect(HealthExamResultSupport.riskCounts(draft).high).assertEqual(0);
      expect(MedicalReportResultSupport.categoryStats([]))
        .assertEqual('检验 0 · 影像 0 · 病理 0');
      expect(PrescriptionRecognitionResultSupport !== undefined).assertTrue();
      expect(MedicationRecognitionResultSupport !== undefined).assertTrue();
      expect(MedicineBoxRecognitionResultSupport !== undefined).assertTrue();
    });
  });
}

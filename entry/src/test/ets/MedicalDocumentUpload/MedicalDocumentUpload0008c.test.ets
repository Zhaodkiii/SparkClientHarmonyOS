import { describe, it, expect } from '@ohos/hypium';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { MedicalDocumentResultKindResolver } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentResultKindResolver';
import {
  MedicalDocumentTypeResolution,
  MedicalDocumentTypedExtractionOutput
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentTypedModels';
import { MedicalDocumentDraftBuilders } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentDraftBuilders';
import {
  MedicalPreSubmitValidationIssue,
  MedicalPreSubmitValidationResourceType,
  MedicalPreSubmitValidationSectionID
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalPreSubmitValidationIssue';
import { MedicalDocumentResultChromeHelper } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/Shared/MedicalDocumentResultChrome';
import { MedicalAttachmentInput } from '../../../main/ets/Projects/Features/Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';

export default function medicalDocumentUpload0008cTest() {
  describe('HOS_MED_UPLOAD_0008_RESULT_PAGES', () => {
    it('resolver_routes_by_typed_drafts_kind', 0, () => {
      const output = new MedicalDocumentTypedExtractionOutput();
      output.typedDrafts.kind = MedicalDocumentKind.HEALTH_EXAM_REPORT;
      expect(MedicalDocumentResultKindResolver.resolve(output)).assertEqual(
        MedicalDocumentKind.HEALTH_EXAM_REPORT
      );
    });

    it('resolver_falls_back_to_type_resolution', 0, () => {
      const resolution = new MedicalDocumentTypeResolution();
      resolution.kind = MedicalDocumentKind.MEDICINE_BOX;
      expect(MedicalDocumentResultKindResolver.resolve(undefined, resolution))
        .assertEqual(MedicalDocumentKind.MEDICINE_BOX);
    });

    it('resolver_auto_goes_to_fallback', 0, () => {
      expect(MedicalDocumentResultKindResolver.resolve(
        undefined, undefined, MedicalDocumentKind.AUTO
      )).assertEqual(MedicalDocumentKind.AUTO);
      expect(MedicalDocumentResultKindResolver.isRoutable(MedicalDocumentKind.AUTO))
        .assertFalse();
      expect(MedicalDocumentResultKindResolver.isRoutable(MedicalDocumentKind.CASE_DOCUMENT))
        .assertTrue();
    });

    it('resolver_kind_labels_cover_all_business_kinds', 0, () => {
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
      expect(MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.AUTO))
        .assertEqual('未识别');
    });

    it('draft_tree_display_title_feeds_result_headers', 0, () => {
      const caseTree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.CASE_DOCUMENT,
        JSON.stringify({ title: '门诊病历', diagnosis: '上感' })
      );
      expect(caseTree.displayTitle()).assertEqual('门诊病历');

      const examTree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.HEALTH_EXAM_REPORT,
        JSON.stringify({ institution_name: '独墅湖医院', items: [] })
      );
      expect(examTree.displayTitle()).assertEqual('独墅湖医院');

      const boxTree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.MEDICINE_BOX,
        JSON.stringify([{ medicineName: '阿莫西林', totalQuantity: '2' }])
      );
      expect(boxTree.medicineBoxDrafts.length).assertEqual(1);
      expect(boxTree.displayTitle()).assertEqual('阿莫西林');
    });

    it('scroll_target_ids_match_result_page_anchors', 0, () => {
      const titleIssue = MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.CASE_DOCUMENT,
        'medical_case.title', '标题', '标题为空', '病历'
      );
      expect(titleIssue.scrollTargetID()).assertEqual(
        'preSubmitValidation.field.medical_case.title'
      );
      expect(titleIssue.collapseSectionID()).assertEqual(
        MedicalPreSubmitValidationSectionID.CASE_HISTORY
      );

      const examItem = MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.HEALTH_EXAM_REPORT,
        'health_exam.items[0].item_name', '项目名称', '项目名缺失', '体检', 0
      );
      expect(examItem.scrollTargetID()).assertEqual(
        'preSubmitValidation.card.healthExamReport.item.0'
      );

      const boxIssue = MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.MEDICINE_BOX,
        'medicine_boxes[0].medicine_name', '药品名称', '药名缺失', '药箱', 0
      );
      expect(boxIssue.scrollTargetID()).assertEqual(
        'preSubmitValidation.card.medicineBox.0'
      );
      expect(boxIssue.collapseSectionID()).assertEqual(
        MedicalPreSubmitValidationSectionID.MEDICINE_BOX_LIST
      );
    });

    it('attachment_helper_lists_source_file_names', 0, () => {
      const a = new MedicalAttachmentInput();
      a.previewId = 'p1';
      a.originalName = 'report.pdf';
      const b = new MedicalAttachmentInput();
      b.previewId = 'p2';
      b.originalName = '';
      const names = MedicalDocumentResultChromeHelper.fileNames([a, b]);
      expect(names.length).assertEqual(2);
      expect(names[0]).assertEqual('report.pdf');
      expect(names[1]).assertEqual('p2');
    });

    it('all_six_kinds_are_routable', 0, () => {
      const kinds: MedicalDocumentKind[] = [
        MedicalDocumentKind.CASE_DOCUMENT,
        MedicalDocumentKind.HEALTH_EXAM_REPORT,
        MedicalDocumentKind.MEDICAL_REPORT,
        MedicalDocumentKind.PRESCRIPTION,
        MedicalDocumentKind.MEDICATION_PLAN,
        MedicalDocumentKind.MEDICINE_BOX
      ];
      for (let i = 0; i < kinds.length; i++) {
        const output = new MedicalDocumentTypedExtractionOutput();
        output.typedDrafts.kind = kinds[i];
        expect(MedicalDocumentResultKindResolver.resolve(output)).assertEqual(kinds[i]);
      }
    });
  });
}

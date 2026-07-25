import { describe, it, expect } from '@ohos/hypium';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { MedicalDocumentDraftBuilders } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentDraftBuilders';
import {
  MedicalPreSubmitValidationIssue,
  MedicalPreSubmitValidationResourceType,
  MedicalPreSubmitValidationSectionID
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalPreSubmitValidationIssue';
import { MedicalDocumentUploadViewModel } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/MedicalDocumentUploadViewModel';
import { MedicalDocumentResultDetailNavigationSupport } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalDocumentResultDetailNavigationSupport';
import { CaseRecognitionResultSupport } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/CaseRecognitionResult/CaseRecognitionResultSupport';
import { PrescriptionRecognitionResultPreviewFixtures } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/PrescriptionRecognitionResult/PrescriptionRecognitionResultPreviewFixtures';
import { PrescriptionRecognitionResultSupport } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/PrescriptionRecognitionResult/PrescriptionRecognitionResultSupport';
import { MedicalPreSubmitValidationNavigation } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/PreSubmitValidation/MedicalPreSubmitValidationNavigation';
import { MedicalPreSubmitValidationSummaryBannerHelper } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/PreSubmitValidation/MedicalPreSubmitValidationSummaryBanner';
import { MemberContextStore } from '../../../main/ets/Projects/Features/MemberContext/Presentation/MemberContextStore';
import { SelectedMemberIDStore } from '../../../main/ets/Projects/Features/MemberContext/Infrastructure/SelectedMemberIDStore';

class TestSelectedMemberIDStore {
  async ensureReady(): Promise<void> {}

  async load(_accountID: number): Promise<number | undefined> {
    return undefined;
  }

  async save(_memberID: number | undefined, _accountID: number): Promise<void> {}

  async clear(_accountID: number): Promise<void> {}
}

class RevealNavigationHarness {
  expandedPreSubmitSections: string[] = [];
  preSubmitValidationIssues: MedicalPreSubmitValidationIssue[] = [];

  preSubmitIssues(): MedicalPreSubmitValidationIssue[] {
    return this.preSubmitValidationIssues.slice();
  }

  expandPreSubmitSection(sectionID: string): void {
    if (sectionID.length === 0) {
      return;
    }
    if (this.expandedPreSubmitSections.indexOf(sectionID) < 0) {
      this.expandedPreSubmitSections = this.expandedPreSubmitSections.concat([sectionID]);
    }
  }
}

export default function medicalDocumentUpload0012Test() {
  describe('HOS_MED_UPLOAD_0012_RESULT_PAGES_PARITY', () => {
    it('prescription_preview_fixtures_parse', 0, () => {
      const tree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.PRESCRIPTION,
        PrescriptionRecognitionResultPreviewFixtures.PRESCRIPTION_DRAFTS_JSON
      );
      expect(tree.prescriptionDrafts.length).assertEqual(1);
      expect(tree.prescriptionDrafts[0].institutionName)
        .assertEqual('苏州大学附属第四医院');
      expect((tree.prescriptionDrafts[0].medicationPlans ?? []).length).assertEqual(1);
      expect(PrescriptionRecognitionResultPreviewFixtures.FAMILY_MEDICINE_BOXES_JSON.length > 0)
        .assertTrue();
    });

    it('case_support_ensure_draft_and_field_scroll', 0, () => {
      const store = new MemberContextStore(new TestSelectedMemberIDStore() as SelectedMemberIDStore);
      const vm = new MedicalDocumentUploadViewModel(store);
      const draft = CaseRecognitionResultSupport.ensureDraft(vm);
      draft.title = '门诊病历';
      expect(draft.title).assertEqual('门诊病历');
      expect(CaseRecognitionResultSupport.fieldScroll('symptom.name'))
        .assertEqual('preSubmitValidation.field.symptom.name');
    });

    it('prescription_support_err_reads_view_model', 0, () => {
      const store = new MemberContextStore(new TestSelectedMemberIDStore() as SelectedMemberIDStore);
      const vm = new MedicalDocumentUploadViewModel(store);
      const issue = MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.PRESCRIPTION,
        'prescriptions[0].prescribed_at',
        '开方日期',
        '请填写开方日期',
        '处方'
      );
      vm.preSubmitValidationIssues = [issue];
      expect(PrescriptionRecognitionResultSupport.err(vm, 'prescriptions[0].prescribed_at'))
        .assertEqual('请填写开方日期');
    });

    it('summary_banner_helper_builds_lines', 0, () => {
      const issue = MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.SYMPTOM,
        'symptom.name',
        '主诉',
        '请补充主诉',
        '病史'
      );
      const lines = MedicalPreSubmitValidationSummaryBannerHelper.lines([issue]);
      expect(lines.length).assertEqual(1);
      expect(lines[0]).assertEqual('主诉：请补充主诉');
    });

    it('navigation_reveal_expands_blocking_section', 0, () => {
      const harness = new RevealNavigationHarness();
      const issue = MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.SYMPTOM,
        'symptom.name',
        '主诉',
        '请补充主诉',
        '病史'
      );
      harness.preSubmitValidationIssues = [issue];
      MedicalPreSubmitValidationNavigation.reveal(
        harness as MedicalDocumentUploadViewModel,
        0
      );
      expect(harness.expandedPreSubmitSections.indexOf(
        MedicalPreSubmitValidationSectionID.CASE_HISTORY) >= 0).assertTrue();
    });

    it('detail_navigation_support_stub', 0, () => {
      const store = new MemberContextStore(new TestSelectedMemberIDStore() as SelectedMemberIDStore);
      const vm = new MedicalDocumentUploadViewModel(store);
      expect(MedicalDocumentResultDetailNavigationSupport.makeContext(0, vm))
        .assertUndefined();
      const ctx = MedicalDocumentResultDetailNavigationSupport.makeContext(42, vm);
      expect(ctx !== undefined).assertTrue();
      if (ctx !== undefined) {
        expect(ctx.memberId).assertEqual(42);
      }
      expect(MedicalDocumentResultDetailNavigationSupport.shouldOpenDetailAfterSave(vm))
        .assertFalse();
    });
  });
}

import { describe, it, expect } from '@ohos/hypium';
import {
  InMemoryMedicalDocumentUploadCheckpointStore,
  MedicalCheckpointFileSnapshot,
  MedicalDocumentUploadCheckpoint
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Application/MedicalDocumentUploadCheckpointStore';
import { MedicalDocumentDraftBuilders } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentDraftBuilders';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { MedicalDocumentUploadEntrySource } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentUploadModels';
import {
  MedicalPreSubmitValidationIssue,
  MedicalPreSubmitValidationResourceType,
  MedicalPreSubmitValidationSectionID
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalPreSubmitValidationIssue';
import { MedicalPreSubmitValidationRules } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalPreSubmitValidationRules';
import { MedicalPreSubmitValidator } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalPreSubmitValidator';
import { MedicalDocumentTypedExtractionOutput } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentTypedModels';

export default function medicalDocumentUpload0008bTest() {
  describe('HOS_MED_UPLOAD_0008_PRESUBMIT_CHECKPOINT', () => {
    it('rules_complete_date_rejects_year_or_month_only', 0, () => {
      expect(MedicalPreSubmitValidationRules.isCompleteDate('2025-12-28')).assertTrue();
      expect(MedicalPreSubmitValidationRules.isCompleteDate('2025-12')).assertFalse();
      expect(MedicalPreSubmitValidationRules.isCompleteDate('2025')).assertFalse();
      expect(MedicalPreSubmitValidationRules.requiresCompleteDateIfPresent('')).assertTrue();
      expect(MedicalPreSubmitValidationRules.requiresCompleteDateIfPresent('2025-12')).assertFalse();
      expect(MedicalPreSubmitValidationRules.isValidIntegerString('27')).assertTrue();
      expect(MedicalPreSubmitValidationRules.isValidIntegerString('27.5')).assertFalse();
      expect(MedicalPreSubmitValidationRules.isValidDecimalString('1.5')).assertTrue();
      expect(MedicalPreSubmitValidationRules.isBlank('  ')).assertTrue();
    });

    it('issue_scroll_and_collapse_ids_align_ios', 0, () => {
      const issue = MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.SYMPTOM,
        'symptom.name',
        '症状名称',
        '主诉为空',
        '病历'
      );
      expect(issue.blocking).assertTrue();
      expect(issue.scrollTargetID().indexOf('symptom.name') >= 0).assertTrue();
      expect(issue.collapseSectionID()).assertEqual(
        MedicalPreSubmitValidationSectionID.CASE_HISTORY
      );
      expect(issue.summaryLine()).assertEqual('症状名称：主诉为空');
    });

    it('validator_blocks_case_missing_title_and_incomplete_date', 0, () => {
      const json = JSON.stringify({
        title: '',
        occurredAt: '2025-12',
        ageAtVisit: 'abc',
        symptom: { name: '' }
      });
      const tree = MedicalDocumentDraftBuilders.buildTree(MedicalDocumentKind.CASE_DOCUMENT, json);
      const output = new MedicalDocumentTypedExtractionOutput();
      output.extractedJSON = json;
      output.typedDrafts = tree;
      const issues = new MedicalPreSubmitValidator().validate(output);
      const keys = issues.map((i: MedicalPreSubmitValidationIssue): string => i.fieldKey);
      expect(keys.indexOf('medical_case.title') >= 0).assertTrue();
      expect(keys.indexOf('medical_case.occurred_at') >= 0).assertTrue();
      expect(keys.indexOf('medical_case.age_at_visit') >= 0).assertTrue();
      expect(keys.indexOf('symptom.name') >= 0).assertTrue();
      expect(MedicalPreSubmitValidationIssue.blockingIssues(issues).length > 0).assertTrue();
    });

    it('validator_passes_minimal_valid_case', 0, () => {
      const json = JSON.stringify({
        title: '门诊病历',
        occurredAt: '2025-12-28',
        ageAtVisit: '27',
        symptom: { name: '咳嗽', startedAt: '2025-12-25' }
      });
      const tree = MedicalDocumentDraftBuilders.buildTree(MedicalDocumentKind.CASE_DOCUMENT, json);
      const output = new MedicalDocumentTypedExtractionOutput();
      output.extractedJSON = json;
      output.typedDrafts = tree;
      const issues = new MedicalPreSubmitValidator().validate(output);
      expect(issues.length).assertEqual(0);
    });

    it('validator_blocks_health_exam_missing_institution_and_item', 0, () => {
      const json = JSON.stringify({
        institution_name: '',
        exam_date: '2025-12',
        items: [{ item_name: '', result_value: '' }]
      });
      const tree = MedicalDocumentDraftBuilders.buildTree(
        MedicalDocumentKind.HEALTH_EXAM_REPORT, json);
      const output = new MedicalDocumentTypedExtractionOutput();
      output.extractedJSON = json;
      output.typedDrafts = tree;
      const issues = new MedicalPreSubmitValidator().validate(output);
      const keys = issues.map((i: MedicalPreSubmitValidationIssue): string => i.fieldKey);
      expect(keys.indexOf('health_exam.institution_name') >= 0).assertTrue();
      expect(keys.indexOf('health_exam.exam_date') >= 0).assertTrue();
      expect(keys.indexOf('health_exam.items[0].item_name') >= 0).assertTrue();
      expect(keys.indexOf('health_exam.items[0].result_value') >= 0).assertTrue();
    });

    it('validator_blocks_empty_extracted_without_draft_title', 0, () => {
      const output = new MedicalDocumentTypedExtractionOutput();
      output.extractedJSON = '';
      const issues = new MedicalPreSubmitValidator().validate(output);
      expect(issues.length).assertEqual(1);
      expect(issues[0].fieldKey).assertEqual('typed_output');
    });

    it('checkpoint_persists_ocr_type_extract_fields', 0, async () => {
      const store = new InMemoryMedicalDocumentUploadCheckpointStore();
      const snap = new MedicalDocumentUploadCheckpoint();
      snap.uploadSessionId = 'sess_ocr_1';
      snap.accountId = 11;
      snap.memberId = 22;
      snap.source = MedicalDocumentUploadEntrySource.HOME;
      snap.stage = 'extracted';
      snap.updatedAt = '2026-07-25T00:00:00.000Z';
      snap.selectedKind = MedicalDocumentKind.CASE_DOCUMENT;
      snap.pipelineOCRText = '门诊病历 咳嗽三天';
      snap.typeResolutionJSON = JSON.stringify({
        kind: MedicalDocumentKind.CASE_DOCUMENT,
        kindLabel: '病历',
        sourceLabel: '本地规则',
        confidence: 0.9,
        source: 'localRules',
        reason: 'keyword'
      });
      snap.extractedJSON = JSON.stringify({ title: '门诊病历', diagnosis: '上感' });
      snap.failedStep = '';
      const file = new MedicalCheckpointFileSnapshot();
      file.localId = 'local_ocr';
      file.uri = 'file://report.jpg';
      file.displayName = 'report.jpg';
      file.mimeType = 'image/jpeg';
      file.remoteFileId = 101;
      file.fileUuid = 'uuid-ocr';
      file.ocrText = '门诊病历';
      snap.uploadedFiles = [file];
      snap.selectedFiles = [file];
      await store.save(snap);

      const loaded = await store.load('sess_ocr_1');
      expect(loaded !== undefined).assertTrue();
      expect(loaded!.stage).assertEqual('extracted');
      expect(loaded!.pipelineOCRText).assertEqual('门诊病历 咳嗽三天');
      expect(loaded!.selectedKind).assertEqual(MedicalDocumentKind.CASE_DOCUMENT);
      expect(loaded!.typeResolutionJSON.indexOf('localRules') >= 0).assertTrue();
      expect(loaded!.extractedJSON.indexOf('门诊病历') >= 0).assertTrue();
      expect(loaded!.uploadedFiles[0].ocrText).assertEqual('门诊病历');

      const latest = await store.loadLatest(11, 22);
      expect(latest !== undefined).assertTrue();
      expect(latest!.uploadSessionId).assertEqual('sess_ocr_1');
      expect(latest!.extractedJSON.length > 0).assertTrue();
    });

    it('checkpoint_file_snapshot_roundtrip_keeps_ocr_text', 0, () => {
      const snap = new MedicalCheckpointFileSnapshot();
      snap.localId = 'f1';
      snap.uri = 'file://a.jpg';
      snap.displayName = 'a.jpg';
      snap.mimeType = 'image/jpeg';
      snap.remoteFileId = 55;
      snap.fileUuid = 'uuid-55';
      snap.ocrText = '血常规 WBC 6.2';
      const attachment = snap.toAttachment();
      expect(attachment.ocrText).assertEqual('血常规 WBC 6.2');
      const back = MedicalCheckpointFileSnapshot.fromAttachment(attachment);
      expect(back.ocrText).assertEqual('血常规 WBC 6.2');
      expect(back.remoteFileId).assertEqual(55);
    });
  });
}

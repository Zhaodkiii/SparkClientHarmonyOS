import { RemoteExaminationReportWithAttachments } from
  '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { MedicalReportRecognitionDraft } from
  '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { ExaminationReportServerMutationService } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportServerMutationService';
import { ExamReportFormModeKind } from './ExamReportFormMode';

/**
 * 检查报告表单上下文。对齐 iOS `ExamReportFormView.Mode` + `CreateContext`，
 * 将模式、实体、成员与提交服务收拢为单一对象。
 */
export class ExamReportFormContext {
  modeKind: ExamReportFormModeKind = ExamReportFormModeKind.SERVER_EDIT;
  memberID: number = 0;
  medicalCaseID?: number = undefined;
  existingReport?: RemoteExaminationReportWithAttachments = undefined;
  existingDraft?: MedicalReportRecognitionDraft = undefined;
  mutationService?: ExaminationReportServerMutationService = undefined;
}

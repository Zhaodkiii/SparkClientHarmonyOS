import { SparkMedicalQueryAPI } from '../../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import {
  MedicalReportDetailPayload,
  MedicalReportSavePayload,
  SparkMedicalWorkflowAPI
} from '../../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import {
  RemoteExaminationReportWithAttachments,
  RemoteMedExamDetail
} from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { SparkMedicalResourceKind } from '../../../../../Core/Networking/API/Medical/SparkMedicalResourceKind';
import { MedicalReportRecognitionDraft } from
  '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentDraftMappers } from
  '../../../../MedicalDocumentUpload/Domain/MedicalDocumentDraftMappers';
import { MedicalReportResultSupport } from
  '../../../../MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportResultSupport';
import { nonEmptyText } from '../Shared/HealthExamFlagSupport';

class ExaminationReportRawOCRPayload {
  text: string = '';
}

class ExaminationReportUpdatePayload {
  member: number = 0;
  medical_record?: number;
  category: string = '';
  sub_category: string = '';
  item_name: string = '';
  performed_at?: string;
  reported_at?: string;
  organization_name: string = '';
  department_name: string = '';
  doctor_name: string = '';
  findings: string = '';
  impression: string = '';
  source: number = 2;
  raw_ocr: ExaminationReportRawOCRPayload = new ExaminationReportRawOCRPayload();
  status: number = 1;
  extra: Map<string, string> = new Map();
}

class MedExamDetailCreatePayload {
  business_type: string = '';
  business_id: number = 0;
  member: number = 0;
  category: string = '';
  sub_category: string = '';
  item_name: string = '';
  item_code: string = '';
  result_value: string = '';
  unit: string = '';
  reference_range: string = '';
  flag: string = '';
  result_at?: string;
  modality: string = '';
  body_part: string = '';
  diagnosis: string = '';
  sort_order: number = 0;
  extra: Map<string, string> = new Map();
}

/**
 * 检查报告服务端更新。对齐 iOS `ExaminationReportServerMutationService`。
 */
export class ExaminationReportServerMutationService {
  private readonly workflowAPI: SparkMedicalWorkflowAPI;
  private readonly queryAPI?: SparkMedicalQueryAPI;

  constructor(workflowAPI: SparkMedicalWorkflowAPI, queryAPI?: SparkMedicalQueryAPI) {
    this.workflowAPI = workflowAPI;
    this.queryAPI = queryAPI;
  }

  async deleteReport(reportID: number): Promise<void> {
    await this.workflowAPI.deleteResource(SparkMedicalResourceKind.EXAMINATION_REPORTS, reportID);
  }

  /** 手工新建检查报告。对齐 iOS `MedicalRecordFormSubmissionService.submitMedicalReportCreate`。 */
  async createReportWithDraft(
    memberID: number,
    draft: MedicalReportRecognitionDraft,
    medicalCaseID?: number
  ): Promise<number> {
    const findings = MedicalReportResultSupport.resolvedFindingsText(draft);
    const impression = MedicalReportResultSupport.resolvedImpressionText(draft);
    const fallbackCategory = nonEmptyText(draft.category).length > 0 ?
      nonEmptyText(draft.category) : 'laboratory';
    const payload = new MedicalReportSavePayload();
    payload.member = memberID;
    if (medicalCaseID !== undefined) {
      payload.medical_case = medicalCaseID;
    }
    payload.category = fallbackCategory;
    payload.sub_category = '';
    payload.item_name = draft.title;
    const dateText = nonEmptyText(draft.date);
    if (dateText.length > 0) {
      payload.performed_at = dateText;
      payload.reported_at = dateText;
    }
    payload.organization_name = draft.hospital;
    payload.doctor_name = draft.doctor ?? '';
    payload.findings = findings;
    payload.impression = impression;
    payload.file_ids = [];
    payload.details = [];
    for (let index = 0; index < draft.details.length; index++) {
      const item = draft.details[index];
      const apiItem = MedicalDocumentDraftMappers.itemDraftToMedicalReportItem(
        item,
        fallbackCategory,
        `${index}`
      );
      const detailReq = MedicalDocumentDraftMappers.medicalReportItemToDetailRequest(apiItem);
      const row = new MedicalReportDetailPayload();
      row.category = detailReq.category;
      row.sub_category = detailReq.subCategory ?? '';
      row.item_name = detailReq.itemName ?? '';
      row.item_code = detailReq.itemCode ?? '';
      row.result_value = detailReq.resultValue ?? '';
      row.unit = detailReq.unit ?? '';
      row.reference_range = detailReq.referenceRange ?? '';
      row.flag = detailReq.flag ?? '';
      row.result_at = detailReq.resultAt;
      row.modality = detailReq.modality ?? '';
      row.body_part = detailReq.bodyPart ?? '';
      row.diagnosis = detailReq.diagnosis ?? '';
      row.sort_order = detailReq.sortOrder ?? index;
      if (detailReq.extra.size > 0) {
        const extra: Record<string, string> = {};
        detailReq.extra.forEach((value: string, key: string) => {
          extra[key] = value;
        });
        row.extra = extra;
      }
      payload.details.push(row);
    }
    return await this.workflowAPI.createMedicalReport(payload);
  }

  async updateReportWithDraft(
    report: RemoteExaminationReportWithAttachments,
    draft: MedicalReportRecognitionDraft
  ): Promise<void> {
    const findings = MedicalReportResultSupport.resolvedFindingsText(draft);
    const impression = MedicalReportResultSupport.resolvedImpressionText(draft);
    const body = new ExaminationReportUpdatePayload();
    body.member = report.member;
    if (report.medicalRecord !== undefined) {
      body.medical_record = report.medicalRecord;
    }
    body.category = nonEmptyText(draft.category).length > 0 ?
      nonEmptyText(draft.category) : (report.category ?? 'laboratory');
    body.sub_category = '';
    body.item_name = draft.title;
    body.performed_at = nonEmptyText(draft.date).length > 0 ? draft.date : report.performedAt;
    body.reported_at = nonEmptyText(draft.date).length > 0 ? draft.date : report.reportedAt;
    body.organization_name = draft.hospital ?? '';
    body.department_name = report.departmentName ?? '';
    body.doctor_name = draft.doctor ?? '';
    body.findings = findings;
    body.impression = impression;
    body.source = report.source ?? 2;
    body.raw_ocr.text = findings.length > 0 ? findings : impression;
    body.status = report.status ?? 1;

    await this.workflowAPI.updateResource(
      SparkMedicalResourceKind.EXAMINATION_REPORTS,
      report.id,
      body as Object
    );

    const existingDetails = await this.listExistingDetails(report);
    for (let i = 0; i < existingDetails.length; i++) {
      const row = existingDetails[i];
      const normalized = row.businessType.toLowerCase();
      if (normalized === 'examination_report' || normalized === 'examination') {
        await this.workflowAPI.deleteResource(SparkMedicalResourceKind.MED_EXAM_DETAILS, row.id);
      }
    }

    const fallbackCategory = nonEmptyText(draft.category).length > 0 ?
      nonEmptyText(draft.category) : 'laboratory';
    for (let index = 0; index < draft.details.length; index++) {
      const item = draft.details[index];
      const apiItem = MedicalDocumentDraftMappers.itemDraftToMedicalReportItem(
        item,
        fallbackCategory,
        `${index}`
      );
      const detailReq = MedicalDocumentDraftMappers.medicalReportItemToDetailRequest(apiItem);
      const detailBody = new MedExamDetailCreatePayload();
      detailBody.business_type = 'examination_report';
      detailBody.business_id = report.id;
      detailBody.member = report.member;
      detailBody.category = detailReq.category;
      detailBody.sub_category = detailReq.subCategory ?? '';
      detailBody.item_name = detailReq.itemName ?? '';
      detailBody.item_code = detailReq.itemCode ?? '';
      detailBody.result_value = detailReq.resultValue ?? '';
      detailBody.unit = detailReq.unit ?? '';
      detailBody.reference_range = detailReq.referenceRange ?? '';
      detailBody.flag = detailReq.flag ?? '';
      if (detailReq.resultAt !== undefined) {
        detailBody.result_at = detailReq.resultAt;
      }
      detailBody.modality = detailReq.modality ?? '';
      detailBody.body_part = detailReq.bodyPart ?? '';
      detailBody.diagnosis = detailReq.diagnosis ?? '';
      detailBody.sort_order = detailReq.sortOrder ?? index;
      await this.workflowAPI.createResource(
        SparkMedicalResourceKind.MED_EXAM_DETAILS,
        detailBody as Object
      );
    }
  }

  private async listExistingDetails(
    report: RemoteExaminationReportWithAttachments
  ): Promise<RemoteMedExamDetail[]> {
    if (this.queryAPI) {
      return await this.queryAPI.listMedExamDetails(report.member, undefined, report.id);
    }
    if (report.medExamDetails.length > 0 && report.detailsLoaded) {
      return report.medExamDetails.slice();
    }
    return [];
  }
}

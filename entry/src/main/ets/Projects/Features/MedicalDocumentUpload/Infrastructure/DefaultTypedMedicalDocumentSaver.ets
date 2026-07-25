import {
  CombinedExaminationDetailRequest,
  CombinedExaminationReportRequest,
  CombinedFollowUpRequest,
  CombinedMedicalCaseRequest,
  CombinedMedicalCreateRequest,
  CombinedMemberRequest,
  CombinedPrescriptionRequest,
  CombinedSurgeryRequest,
  CombinedSymptomRequest,
  CombinedVisitRequest,
  SparkCombinedMedicalCreateAPI
} from '../../../Core/Networking/API/Medical/CombinedMedicalCreateAPI';
import {
  HealthExamDetailSaveRow,
  HealthExamSavePayload,
  MedicalReportDetailPayload,
  MedicalReportSavePayload,
  MedicationPlanBundleItemNetworkPayload,
  MedicationPlanBundleSavePayload,
  MedicationPlanMedicineBoxPayload,
  MedicineBoxWritePayload,
  PrescriptionBatchItemPayload,
  PrescriptionBatchSavePayload,
  ReminderTimeNetworkPayload,
  SparkMedicalWorkflowAPI
} from '../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalDocumentDraftMappers } from '../Domain/MedicalDocumentDraftMappers';
import {
  HealthExamRecognitionDraft,
  MedicalReportRecognitionDraft,
  MedicationPlanRecognitionDraft,
  MedicineBoxRecognitionDraft,
  PrescriptionRecognitionDraft,
  ReminderTime
} from '../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import {
  MedicalDocumentSaveReceipt
} from '../Domain/MedicalDocumentAttachmentBindingModels';
import { MedicalDocumentTypedExtractionOutput } from '../Domain/MedicalDocumentTypedModels';
import { PrescriptionFieldNormalization } from '../Domain/PrescriptionFieldNormalization';
import {
  MedicalDocumentSaveError,
  TypedMedicalDocumentSaving
} from '../Domain/TypedMedicalDocumentSaving';

/**
 * 默认 Typed 保存器。对齐 iOS DefaultTypedMedicalDocumentSaver。
 * 附件优先写入各接口 file_ids / source_file_ids；绑定 UseCase 为次要路径。
 */
export class DefaultTypedMedicalDocumentSaver implements TypedMedicalDocumentSaving {
  private readonly workflowAPI: SparkMedicalWorkflowAPI;
  private readonly combinedAPI: SparkCombinedMedicalCreateAPI;

  constructor(
    workflowAPI: SparkMedicalWorkflowAPI,
    combinedAPI: SparkCombinedMedicalCreateAPI
  ) {
    this.workflowAPI = workflowAPI;
    this.combinedAPI = combinedAPI;
  }

  async save(
    output: MedicalDocumentTypedExtractionOutput,
    sourceFiles: MedicalAttachmentInput[]
  ): Promise<MedicalDocumentSaveReceipt> {
    const memberID = output.envelope.memberID ?? 0;
    if (memberID <= 0) {
      throw MedicalDocumentSaveError.noMember();
    }
    const kind = output.typedDrafts.kind;
    const now = new Date().toISOString();
    switch (kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        return this.saveCombinedCase(memberID, output, sourceFiles, now);
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        return this.saveHealthExam(memberID, output, sourceFiles, now);
      case MedicalDocumentKind.MEDICAL_REPORT:
        return this.saveMedicalReports(memberID, output, sourceFiles, now);
      case MedicalDocumentKind.PRESCRIPTION:
        return this.savePrescriptions(memberID, output, sourceFiles, now);
      case MedicalDocumentKind.MEDICATION_PLAN:
        return this.saveMedicationPlans(memberID, output, sourceFiles, now);
      case MedicalDocumentKind.MEDICINE_BOX:
        return this.saveMedicineBoxes(memberID, output, sourceFiles, now);
      default:
        throw MedicalDocumentSaveError.unsupported(kind);
    }
  }

  private async saveCombinedCase(
    memberID: number,
    output: MedicalDocumentTypedExtractionOutput,
    sourceFiles: MedicalAttachmentInput[],
    now: string
  ): Promise<MedicalDocumentSaveReceipt> {
    const draft = output.typedDrafts.caseDraft;
    if (draft === undefined) {
      throw MedicalDocumentSaveError.emptyDraft(MedicalDocumentKind.CASE_DOCUMENT);
    }
    const caseReq = MedicalDocumentDraftMappers.caseToCreateRequest(draft);
    const request = new CombinedMedicalCreateRequest();
    const member = new CombinedMemberRequest();
    member.id = memberID;
    request.member = member;
    const medicalCase = new CombinedMedicalCaseRequest();
    medicalCase.title = caseReq.title;
    medicalCase.hospital_name = caseReq.hospitalName;
    medicalCase.diagnosis_summary = caseReq.diagnosisSummary;
    medicalCase.age_at_visit = caseReq.ageAtVisit;
    medicalCase.extra = DefaultTypedMedicalDocumentSaver.mapToRecord(caseReq.extra);
    medicalCase.extra['source'] = 'typed_upload';
    medicalCase.source_file_ids = this.resolveFileIds(caseReq.sourceFileIds, sourceFiles);
    request.medical_case = medicalCase;

    if (draft.symptom !== undefined) {
      const s = MedicalDocumentDraftMappers.symptomToCreateRequest(draft.symptom);
      const row = new CombinedSymptomRequest();
      row.name = s.name;
      row.code = s.code;
      row.severity = s.severity;
      row.started_at = s.startedAt;
      row.duration_value = s.durationValue;
      row.duration_unit = s.durationUnit;
      row.body_part = s.bodyPart;
      row.notes = s.notes;
      row.source_file_ids = this.resolveFileIds(s.sourceFileIds, sourceFiles);
      request.symptom = row;
    }
    if (draft.visit !== undefined) {
      const v = MedicalDocumentDraftMappers.visitToCreateRequest(draft.visit);
      const row = new CombinedVisitRequest();
      row.visit_type = v.visitType;
      row.visited_at = v.visitedAt;
      row.department = v.department;
      row.doctor_name = v.doctorName;
      row.visit_no = v.visitNo;
      row.notes = v.notes;
      row.source_file_ids = this.resolveFileIds(v.sourceFileIds, sourceFiles);
      request.visit = row;
    }
    if (draft.surgery !== undefined) {
      const s = MedicalDocumentDraftMappers.surgeryToCreateRequest(draft.surgery);
      const row = new CombinedSurgeryRequest();
      row.procedure_name = s.procedureName;
      row.procedure_code = s.procedureCode;
      row.site = s.site;
      row.performed_at = s.performedAt;
      row.surgeon = s.surgeon;
      row.anesthesia_type = s.anesthesiaType;
      row.incision_level = s.incisionLevel;
      row.asa_class = s.asaClass;
      row.notes = s.notes;
      row.source_file_ids = this.resolveFileIds(s.sourceFileIds, sourceFiles);
      request.surgery = row;
    }
    if (draft.followUps !== undefined && draft.followUps.length > 0) {
      const f = MedicalDocumentDraftMappers.followUpToCreateRequest(draft.followUps[0]);
      const row = new CombinedFollowUpRequest();
      row.planned_at = f.plannedAt;
      row.completed_at = f.completedAt;
      row.status = f.status;
      row.method = f.method;
      row.outcome = f.outcome;
      row.next_action = f.nextAction;
      row.source_file_ids = this.resolveFileIds(f.sourceFileIds, sourceFiles);
      request.follow_up = row;
    }
    if (draft.examinationReports !== undefined && draft.examinationReports.length > 0) {
      const reports: CombinedExaminationReportRequest[] = [];
      for (let i = 0; i < draft.examinationReports.length; i++) {
        reports.push(this.toCombinedExam(draft.examinationReports[i], sourceFiles));
      }
      request.examination_reports = reports;
    }
    if (draft.prescriptions !== undefined && draft.prescriptions.length > 0) {
      const rxs: CombinedPrescriptionRequest[] = [];
      for (let i = 0; i < draft.prescriptions.length; i++) {
        rxs.push(this.toCombinedPrescription(draft.prescriptions[i], sourceFiles));
      }
      request.prescriptions = rxs;
    }

    const response = await this.combinedAPI.createCombinedMedical(request);
    return this.receipt(
      MedicalDocumentKind.CASE_DOCUMENT,
      response.medical_case_id,
      now,
      '病例已保存'
    );
  }

  private async saveHealthExam(
    memberID: number,
    output: MedicalDocumentTypedExtractionOutput,
    sourceFiles: MedicalAttachmentInput[],
    now: string
  ): Promise<MedicalDocumentSaveReceipt> {
    const draft = output.typedDrafts.healthExamDraft;
    if (draft === undefined) {
      throw MedicalDocumentSaveError.emptyDraft(MedicalDocumentKind.HEALTH_EXAM_REPORT);
    }
    const payload = this.buildHealthExamPayload(memberID, draft, output, sourceFiles);
    const id = await this.workflowAPI.saveHealthExam(payload);
    return this.receipt(MedicalDocumentKind.HEALTH_EXAM_REPORT, id, now, '体检报告已保存');
  }

  private async saveMedicalReports(
    memberID: number,
    output: MedicalDocumentTypedExtractionOutput,
    sourceFiles: MedicalAttachmentInput[],
    now: string
  ): Promise<MedicalDocumentSaveReceipt> {
    const drafts = output.typedDrafts.medicalReportDrafts;
    if (drafts.length === 0) {
      throw MedicalDocumentSaveError.emptyDraft(MedicalDocumentKind.MEDICAL_REPORT);
    }
    let lastId = 0;
    for (let i = 0; i < drafts.length; i++) {
      lastId = await this.workflowAPI.createMedicalReport(
        this.buildMedicalReportPayload(memberID, drafts[i], sourceFiles)
      );
    }
    return this.receipt(MedicalDocumentKind.MEDICAL_REPORT, lastId, now, '检查报告已保存');
  }

  private async savePrescriptions(
    memberID: number,
    output: MedicalDocumentTypedExtractionOutput,
    sourceFiles: MedicalAttachmentInput[],
    now: string
  ): Promise<MedicalDocumentSaveReceipt> {
    const drafts = output.typedDrafts.prescriptionDrafts;
    if (drafts.length === 0) {
      throw MedicalDocumentSaveError.emptyDraft(MedicalDocumentKind.PRESCRIPTION);
    }
    const payload = new PrescriptionBatchSavePayload();
    payload.member = memberID;
    for (let i = 0; i < drafts.length; i++) {
      payload.prescriptions.push(this.toBatchPrescription(drafts[i], sourceFiles));
    }
    const response = await this.workflowAPI.savePrescriptionsBatch(payload);
    const recordID = response.prescription_ids.length > 0 ?
      response.prescription_ids[0] :
      (response.medication_plan_ids.length > 0 ?
        response.medication_plan_ids[0] : response.member_id);
    return this.receipt(MedicalDocumentKind.PRESCRIPTION, recordID, now, '处方已保存');
  }

  private async saveMedicationPlans(
    memberID: number,
    output: MedicalDocumentTypedExtractionOutput,
    sourceFiles: MedicalAttachmentInput[],
    now: string
  ): Promise<MedicalDocumentSaveReceipt> {
    const drafts = output.typedDrafts.medicationPlanDrafts;
    if (drafts.length === 0) {
      throw MedicalDocumentSaveError.emptyDraft(MedicalDocumentKind.MEDICATION_PLAN);
    }
    const payload = new MedicationPlanBundleSavePayload();
    payload.member = memberID;
    payload.items = [];
    for (let i = 0; i < drafts.length; i++) {
      payload.items.push(this.toPlanNetworkItem(drafts[i], i, sourceFiles, now));
    }
    payload.file_ids = [];
    const response = await this.workflowAPI.saveMedicationPlanBundleResponse(payload);
    const recordID = response.prescription_id !== undefined && response.prescription_id > 0 ?
      response.prescription_id : response.id;
    return this.receipt(MedicalDocumentKind.MEDICATION_PLAN, recordID, now, '用药计划已保存');
  }

  private async saveMedicineBoxes(
    memberID: number,
    output: MedicalDocumentTypedExtractionOutput,
    sourceFiles: MedicalAttachmentInput[],
    now: string
  ): Promise<MedicalDocumentSaveReceipt> {
    const drafts = output.typedDrafts.medicineBoxDrafts;
    if (drafts.length === 0) {
      throw MedicalDocumentSaveError.emptyDraft(MedicalDocumentKind.MEDICINE_BOX);
    }
    let firstId = 0;
    for (let i = 0; i < drafts.length; i++) {
      const saved = await this.workflowAPI.createMedicineBox(
        this.buildMedicineBoxPayload(memberID, drafts[i], sourceFiles, i === 0)
      );
      if (firstId <= 0) {
        firstId = saved.id;
      }
    }
    return this.receipt(MedicalDocumentKind.MEDICINE_BOX, firstId, now, '药箱已保存');
  }

  private buildHealthExamPayload(
    memberID: number,
    draft: HealthExamRecognitionDraft,
    output: MedicalDocumentTypedExtractionOutput,
    sourceFiles: MedicalAttachmentInput[]
  ): HealthExamSavePayload {
    const payload = new HealthExamSavePayload();
    payload.member = memberID;
    payload.institution_name = draft.institutionName ?? '';
    payload.report_no = draft.reportNo ?? '';
    payload.exam_date = draft.examDate;
    payload.exam_type = DefaultTypedMedicalDocumentSaver.parseExamType(draft.examType);
    payload.summary = draft.summary;
    payload.source = 2;
    const ocr: Record<string, string> = {};
    ocr['text'] = output.envelope.ocrTextPreview ?? '';
    payload.raw_ocr = ocr;
    payload.status = 1;
    payload.extra = { 'source': 'typed_upload' };
    payload.file_ids = this.resolveFileIds(draft.attachmentFileIds, sourceFiles);
    payload.details = [];
    for (let i = 0; i < draft.items.length; i++) {
      const item = draft.items[i];
      const row = new HealthExamDetailSaveRow();
      row.category = item.category;
      row.sub_category = item.subCategory ?? '';
      row.item_name = item.itemName ?? '';
      row.item_code = item.itemCode ?? '';
      row.result_value = item.resultValue ?? '';
      row.unit = item.unit ?? '';
      row.reference_range = item.referenceRange ?? '';
      row.flag = item.flag ?? '';
      row.result_at = item.resultAt;
      row.modality = item.modality ?? '';
      row.body_part = item.bodyPart ?? '';
      row.diagnosis = item.diagnosis ?? '';
      row.sort_order = DefaultTypedMedicalDocumentSaver.parseIntOr(item.sortOrder, i);
      payload.details.push(row);
    }
    return payload;
  }

  private buildMedicalReportPayload(
    memberID: number,
    draft: MedicalReportRecognitionDraft,
    sourceFiles: MedicalAttachmentInput[]
  ): MedicalReportSavePayload {
    const mapped = MedicalDocumentDraftMappers.medicalReportToCreateRequest(draft);
    const payload = new MedicalReportSavePayload();
    payload.member = memberID;
    payload.category = mapped.category ?? '';
    payload.item_name = mapped.itemName ?? draft.title;
    payload.performed_at = mapped.performedAt;
    payload.reported_at = mapped.performedAt;
    payload.organization_name = mapped.organizationName;
    payload.doctor_name = mapped.doctorName ?? '';
    payload.findings = mapped.findings ?? '';
    payload.impression = mapped.impression ?? '';
    payload.file_ids = this.resolveFileIds(mapped.sourceFileIds, sourceFiles);
    payload.details = [];
    for (let i = 0; i < mapped.details.length; i++) {
      const d = mapped.details[i];
      const row = new MedicalReportDetailPayload();
      row.category = d.category;
      row.sub_category = d.subCategory ?? '';
      row.item_name = d.itemName ?? '';
      row.item_code = d.itemCode ?? '';
      row.result_value = d.resultValue ?? '';
      row.unit = d.unit ?? '';
      row.reference_range = d.referenceRange ?? '';
      row.flag = d.flag ?? '';
      row.result_at = d.resultAt;
      row.modality = d.modality ?? '';
      row.body_part = d.bodyPart ?? '';
      row.diagnosis = d.diagnosis ?? '';
      row.sort_order = d.sortOrder ?? i;
      row.extra = DefaultTypedMedicalDocumentSaver.mapToRecord(d.extra);
      payload.details.push(row);
    }
    return payload;
  }

  private buildMedicineBoxPayload(
    memberID: number,
    draft: MedicineBoxRecognitionDraft,
    sourceFiles: MedicalAttachmentInput[],
    attachAllSourceFiles: boolean
  ): MedicineBoxWritePayload {
    const payload = new MedicineBoxWritePayload();
    payload.member = memberID;
    payload.entry_member_id = memberID;
    payload.medicine_name = draft.medicineName ?? draft.brandName ?? '未命名药品';
    payload.medicine_type = draft.medicineType;
    payload.brand_name = draft.brandName ?? '';
    payload.dosage_form = draft.dosageForm ?? '';
    payload.strength = draft.strength ?? '';
    payload.dose_unit = draft.doseUnit ?? '';
    payload.total_quantity = DefaultTypedMedicalDocumentSaver.parseOptionalNumber(draft.totalQuantity);
    payload.expire_date = draft.expireDate;
    payload.notes = draft.notes ?? '';
    payload.extra = DefaultTypedMedicalDocumentSaver.mergeTypedExtra(
      DefaultTypedMedicalDocumentSaver.mapToRecord(draft.extra)
    );
    if (draft.attachmentFileIds.length > 0) {
      payload.file_ids = this.resolveFileIds(draft.attachmentFileIds, sourceFiles);
    } else if (attachAllSourceFiles) {
      payload.file_ids = this.allRemoteFileIds(sourceFiles);
    } else {
      payload.file_ids = [];
    }
    return payload;
  }

  private toBatchPrescription(
    draft: PrescriptionRecognitionDraft,
    sourceFiles: MedicalAttachmentInput[]
  ): PrescriptionBatchItemPayload {
    const mapped = MedicalDocumentDraftMappers.prescriptionToCreateRequest(draft);
    const item = new PrescriptionBatchItemPayload();
    item.medical_case = mapped.medicalCase;
    item.prescriber_name = mapped.prescriberName;
    item.institution_name = mapped.institutionName;
    item.prescribed_at = mapped.prescribedAt;
    item.diagnosis = mapped.diagnosis;
    item.prescription_no = mapped.prescriptionNo;
    item.status = mapped.status;
    item.extra = DefaultTypedMedicalDocumentSaver.mergeTypedExtra(
      DefaultTypedMedicalDocumentSaver.mapToRecord(mapped.extra)
    );
    item.source_file_ids = this.resolveFileIds(mapped.sourceFileIds, sourceFiles);
    item.medication_plans = [];
    const plans = draft.medicationPlans ?? [];
    for (let i = 0; i < plans.length; i++) {
      item.medication_plans.push(
        this.toPlanNetworkItem(plans[i], i, sourceFiles, new Date().toISOString())
      );
    }
    return item;
  }

  private toCombinedPrescription(
    draft: PrescriptionRecognitionDraft,
    sourceFiles: MedicalAttachmentInput[]
  ): CombinedPrescriptionRequest {
    const batch = this.toBatchPrescription(draft, sourceFiles);
    const row = new CombinedPrescriptionRequest();
    row.medical_case = batch.medical_case;
    row.prescriber_name = batch.prescriber_name;
    row.institution_name = batch.institution_name;
    row.prescribed_at = batch.prescribed_at;
    row.diagnosis = batch.diagnosis;
    row.prescription_no = batch.prescription_no;
    row.status = batch.status;
    row.extra = batch.extra;
    row.medication_plans = batch.medication_plans;
    row.source_file_ids = batch.source_file_ids;
    return row;
  }

  private toCombinedExam(
    draft: MedicalReportRecognitionDraft,
    sourceFiles: MedicalAttachmentInput[]
  ): CombinedExaminationReportRequest {
    const mapped = MedicalDocumentDraftMappers.medicalReportToCreateRequest(draft);
    const row = new CombinedExaminationReportRequest();
    row.category = mapped.category ?? '';
    row.item_name = mapped.itemName;
    row.findings = mapped.findings;
    row.impression = mapped.impression;
    row.performed_at = mapped.performedAt;
    row.organization_name = mapped.organizationName;
    row.doctor_name = mapped.doctorName;
    row.source_file_ids = this.resolveFileIds(mapped.sourceFileIds, sourceFiles);
    row.details = [];
    for (let i = 0; i < mapped.details.length; i++) {
      const d = mapped.details[i];
      const detail = new CombinedExaminationDetailRequest();
      detail.category = d.category;
      detail.sub_category = d.subCategory;
      detail.item_name = d.itemName;
      detail.item_code = d.itemCode;
      detail.result_value = d.resultValue ?? '';
      detail.unit = d.unit;
      detail.reference_range = d.referenceRange;
      detail.flag = d.flag;
      detail.result_at = d.resultAt;
      detail.modality = d.modality;
      detail.body_part = d.bodyPart;
      detail.diagnosis = d.diagnosis;
      detail.sort_order = d.sortOrder;
      detail.extra = DefaultTypedMedicalDocumentSaver.mapToRecord(d.extra);
      row.details.push(detail);
    }
    return row;
  }

  private toPlanNetworkItem(
    draft: MedicationPlanRecognitionDraft,
    index: number,
    sourceFiles: MedicalAttachmentInput[],
    nowIso: string
  ): MedicationPlanBundleItemNetworkPayload {
    const mapped = MedicalDocumentDraftMappers.medicationPlanToBundleItem(draft);
    const item = new MedicationPlanBundleItemNetworkPayload();
    const medicineName = mapped.medicineName ?? mapped.brandName ??
      mapped.medicineBox?.medicineName ?? '未命名药品';
    const doseUnit = mapped.doseUnit ?? mapped.medicineBox?.doseUnit ?? '片';
    item.drug_name = medicineName;
    item.dose_unit = doseUnit;
    item.dose_value = mapped.doseValue;
    item.dose_per_time = mapped.dosePerTime ??
      ((mapped.doseValue !== undefined && mapped.doseValue.length > 0) ?
        `${mapped.doseValue}${doseUnit}` : '按医嘱');
    item.frequency_type = PrescriptionFieldNormalization.normalizeFrequencyType(mapped.frequencyType);
    item.every_n_days = DefaultTypedMedicalDocumentSaver.parseOptionalInt(mapped.everyNDays);
    item.weekly_weekdays = mapped.weeklyWeekdays ?? [];
    item.frequency_text = mapped.frequencyText ?? '按医嘱';
    item.start_date = mapped.startDate ?? nowIso.substring(0, 10);
    item.end_date = mapped.endDate;
    item.instructions = mapped.instructions ?? '';
    item.reminder_enabled = mapped.reminderEnabled;
    item.status = PrescriptionFieldNormalization.normalizeMedicationPlanStatus(mapped.status);
    item.extra = DefaultTypedMedicalDocumentSaver.mergeTypedExtra(
      DefaultTypedMedicalDocumentSaver.mapToRecord(mapped.extra)
    );
    item.extra['sort_order'] = `${index}`;
    item.file_ids = this.resolveFileIds(mapped.sourceFileIds, sourceFiles);
    item.reminder_times = DefaultTypedMedicalDocumentSaver.toReminderPayloads(mapped.reminderTimes);
    if (mapped.medicineBox !== undefined) {
      const box = new MedicationPlanMedicineBoxPayload();
      box.medicine_name = mapped.medicineBox.medicineName ?? medicineName;
      box.medicine_type = mapped.medicineBox.medicineType;
      box.brand_name = mapped.medicineBox.brandName ?? '';
      box.dosage_form = mapped.medicineBox.dosageForm ?? '';
      box.strength = mapped.medicineBox.strength ?? '';
      box.dose_unit = mapped.medicineBox.doseUnit ?? doseUnit;
      box.total_quantity = DefaultTypedMedicalDocumentSaver.parseOptionalNumber(
        mapped.medicineBox.totalQuantity);
      box.expire_date = mapped.medicineBox.expireDate;
      box.notes = mapped.medicineBox.notes ?? '';
      box.extra = DefaultTypedMedicalDocumentSaver.mergeTypedExtra(
        DefaultTypedMedicalDocumentSaver.mapToRecord(mapped.medicineBox.extra)
      );
      box.file_ids = this.resolveFileIds(mapped.medicineBox.sourceFileIds, sourceFiles);
      item.medicine_box = box;
    }
    return item;
  }

  private resolveFileIds(localIds: string[], sourceFiles: MedicalAttachmentInput[]): number[] {
    if (localIds.length === 0) {
      return this.allRemoteFileIds(sourceFiles);
    }
    const out: number[] = [];
    for (let i = 0; i < localIds.length; i++) {
      const local = localIds[i];
      for (let j = 0; j < sourceFiles.length; j++) {
        const file = sourceFiles[j];
        const remote = file.remoteFile;
        if (remote === undefined || remote.id <= 0) {
          continue;
        }
        if (file.previewId === local || remote.fileUuid === local ||
          `${remote.id}` === local) {
          if (out.indexOf(remote.id) < 0) {
            out.push(remote.id);
          }
        }
      }
    }
    return out.length > 0 ? out : this.allRemoteFileIds(sourceFiles);
  }

  private allRemoteFileIds(sourceFiles: MedicalAttachmentInput[]): number[] {
    const out: number[] = [];
    for (let i = 0; i < sourceFiles.length; i++) {
      const remote = sourceFiles[i].remoteFile;
      if (remote !== undefined && remote.id > 0 && out.indexOf(remote.id) < 0) {
        out.push(remote.id);
      }
    }
    return out;
  }

  private receipt(
    kind: MedicalDocumentKind,
    recordID: number,
    savedAt: string,
    message: string
  ): MedicalDocumentSaveReceipt {
    const receipt = new MedicalDocumentSaveReceipt();
    receipt.kind = kind;
    receipt.recordID = recordID;
    receipt.savedAt = savedAt;
    receipt.isSuccess = recordID > 0;
    receipt.message = message;
    return receipt;
  }

  private static mapToRecord(map: Map<string, string> | undefined): Record<string, string> {
    const out: Record<string, string> = {};
    if (map === undefined) {
      return out;
    }
    map.forEach((v: string, k: string) => {
      out[k] = v;
    });
    return out;
  }

  private static mergeTypedExtra(extra: Record<string, string>): Record<string, string> {
    const out: Record<string, string> = {};
    const keys = Object.keys(extra);
    for (let i = 0; i < keys.length; i++) {
      out[keys[i]] = extra[keys[i]];
    }
    out['source'] = 'typed_upload';
    return out;
  }

  private static parseExamType(raw: string | undefined): number {
    if (raw === undefined) {
      return 1;
    }
    const v = raw.trim().toLowerCase();
    if (v === '2' || v === 'onboarding' || v.indexOf('入职') >= 0) {
      return 2;
    }
    if (v === '3' || v === 'special' || v.indexOf('专项') >= 0) {
      return 3;
    }
    if (v === '4' || v === 'senior' || v.indexOf('老年') >= 0) {
      return 4;
    }
    return 1;
  }

  private static parseIntOr(raw: string | undefined, fallback: number): number {
    if (raw === undefined || raw.trim().length === 0) {
      return fallback;
    }
    const n = parseInt(raw.trim(), 10);
    return isNaN(n) ? fallback : n;
  }

  private static parseOptionalInt(raw: string | undefined): number | undefined {
    if (raw === undefined || raw.trim().length === 0) {
      return undefined;
    }
    const n = parseInt(raw.trim(), 10);
    return isNaN(n) ? undefined : n;
  }

  private static parseOptionalNumber(raw: string | undefined): number | undefined {
    if (raw === undefined || raw.trim().length === 0) {
      return undefined;
    }
    const n = Number(raw.trim());
    return n !== n ? undefined : n;
  }

  private static toReminderPayloads(times: ReminderTime[]): ReminderTimeNetworkPayload[] {
    const out: ReminderTimeNetworkPayload[] = [];
    for (let i = 0; i < times.length; i++) {
      const row = new ReminderTimeNetworkPayload();
      row.time = times[i].time;
      row.dose = times[i].dose;
      row.dose_text = times[i].doseText;
      out.push(row);
    }
    return out;
  }
}

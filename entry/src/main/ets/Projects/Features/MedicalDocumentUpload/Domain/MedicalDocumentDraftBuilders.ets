import { MedicalDocumentKind } from './MedicalDocumentKind';
import {
  CaseRecognitionDraft,
  FollowUpRecognitionDraft,
  HealthExamRecognitionDraft,
  ItemDraft,
  MedicalDocumentTypedDraftTree,
  MedicalReportItem,
  MedicalReportRecognitionDraft,
  MedicationPlanRecognitionDraft,
  MedicineBoxRecognitionDraft,
  PrescriptionRecognitionDraft,
  ReminderTime,
  SurgeryRecognitionDraft,
  SymptomRecognitionDraft,
  VisitRecognitionDraft
} from './MedicalDocumentRecognitionDrafts';
import { PrescriptionFieldNormalization } from './PrescriptionFieldNormalization';

/**
 * AI JSON → 分类型草稿树。对齐 iOS DefaultTypedMedicalDocumentExtractor 解码目标。
 * 支持 camelCase / snake_case；数值类字段以 FlexibleOptionalString 语义落为 string。
 */
export class MedicalDocumentDraftBuilders {
  static buildTree(kind: MedicalDocumentKind, canonicalJSON: string): MedicalDocumentTypedDraftTree {
    const tree = new MedicalDocumentTypedDraftTree();
    tree.kind = kind;
    const root = MedicalDocumentDraftBuilders.parseRoot(canonicalJSON);
    switch (kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        tree.caseDraft = MedicalDocumentDraftBuilders.buildCaseDraft(
          MedicalDocumentDraftBuilders.asRecord(root)
        );
        if (tree.caseDraft.prescriptions !== undefined) {
          tree.caseDraft.prescriptions =
            PrescriptionFieldNormalization.normalizePrescriptionDrafts(tree.caseDraft.prescriptions);
        }
        break;
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        tree.healthExamDraft = MedicalDocumentDraftBuilders.buildHealthExamDraft(
          MedicalDocumentDraftBuilders.asRecord(root)
        );
        break;
      case MedicalDocumentKind.MEDICAL_REPORT:
      case MedicalDocumentKind.AUTO:
        tree.kind = MedicalDocumentKind.MEDICAL_REPORT;
        tree.medicalReportDrafts = MedicalDocumentDraftBuilders.buildMedicalReportDrafts(root);
        break;
      case MedicalDocumentKind.PRESCRIPTION:
        tree.prescriptionDrafts = PrescriptionFieldNormalization.normalizePrescriptionDrafts(
          MedicalDocumentDraftBuilders.buildPrescriptionDrafts(root)
        );
        break;
      case MedicalDocumentKind.MEDICATION_PLAN:
        tree.medicationPlanDrafts = PrescriptionFieldNormalization.normalizeMedicationPlanDrafts(
          MedicalDocumentDraftBuilders.buildMedicationPlanDrafts(root)
        );
        break;
      case MedicalDocumentKind.MEDICINE_BOX:
        tree.medicineBoxDrafts = MedicalDocumentDraftBuilders.buildMedicineBoxDrafts(root);
        break;
      default:
        break;
    }
    return tree;
  }

  static buildCaseDraft(raw: Record<string, Object | string | number | boolean | null> |
    undefined): CaseRecognitionDraft {
    const draft = new CaseRecognitionDraft();
    if (raw === undefined) {
      draft.title = '病例';
      return draft;
    }
    draft.title = MedicalDocumentDraftBuilders.reqString(raw, ['title'], '病例');
    draft.summary = MedicalDocumentDraftBuilders.optString(raw, ['summary']);
    draft.diagnosis = MedicalDocumentDraftBuilders.optString(raw, ['diagnosis']);
    draft.hospitalName = MedicalDocumentDraftBuilders.optString(raw, ['hospitalName', 'hospital_name']);
    draft.ageAtVisit = MedicalDocumentDraftBuilders.optString(raw, ['ageAtVisit', 'age_at_visit']);
    draft.occurredAt = MedicalDocumentDraftBuilders.optString(raw, ['occurredAt', 'occurred_at']);
    draft.attachmentFileIds = MedicalDocumentDraftBuilders.uuidArray(raw,
      ['attachmentFileIds', 'attachment_file_ids']);
    const symptom = MedicalDocumentDraftBuilders.childRecord(raw, ['symptom']);
    if (symptom !== undefined) {
      draft.symptom = MedicalDocumentDraftBuilders.buildSymptom(symptom);
    }
    const visit = MedicalDocumentDraftBuilders.childRecord(raw, ['visit']);
    if (visit !== undefined) {
      draft.visit = MedicalDocumentDraftBuilders.buildVisit(visit);
    }
    const surgery = MedicalDocumentDraftBuilders.childRecord(raw, ['surgery']);
    if (surgery !== undefined) {
      draft.surgery = MedicalDocumentDraftBuilders.buildSurgery(surgery);
    }
    draft.followUps = MedicalDocumentDraftBuilders.mapArray(raw, ['followUps', 'follow_ups'],
      (item): FollowUpRecognitionDraft => MedicalDocumentDraftBuilders.buildFollowUp(item));
    draft.prescriptions = MedicalDocumentDraftBuilders.mapArray(raw, ['prescriptions'],
      (item): PrescriptionRecognitionDraft => MedicalDocumentDraftBuilders.buildPrescription(item));
    draft.examinationReports = MedicalDocumentDraftBuilders.mapArray(raw,
      ['examinationReports', 'examination_reports'],
      (item): MedicalReportRecognitionDraft => MedicalDocumentDraftBuilders.buildMedicalReport(item));
    return draft;
  }

  static buildHealthExamDraft(raw: Record<string, Object | string | number | boolean | null> |
    undefined): HealthExamRecognitionDraft {
    const draft = new HealthExamRecognitionDraft();
    if (raw === undefined) {
      return draft;
    }
    draft.institutionName = MedicalDocumentDraftBuilders.optString(raw,
      ['institutionName', 'institution_name', 'organizationName', 'organization_name']);
    draft.reportNo = MedicalDocumentDraftBuilders.optString(raw, ['reportNo', 'report_no']);
    draft.examDate = MedicalDocumentDraftBuilders.optString(raw, ['examDate', 'exam_date']);
    draft.examType = MedicalDocumentDraftBuilders.optString(raw, ['examType', 'exam_type']);
    draft.summary = MedicalDocumentDraftBuilders.optString(raw, ['summary']);
    draft.items = MedicalDocumentDraftBuilders.mapArray(raw, ['items'],
      (item): MedicalReportItem => MedicalDocumentDraftBuilders.buildReportItem(item)) ?? [];
    draft.attachmentFileIds = MedicalDocumentDraftBuilders.uuidArray(raw,
      ['attachmentFileIds', 'attachment_file_ids']);
    return draft;
  }

  static buildMedicalReportDrafts(root: Object | Object[]): MedicalReportRecognitionDraft[] {
    if (Array.isArray(root)) {
      const out: MedicalReportRecognitionDraft[] = [];
      for (let i = 0; i < root.length; i++) {
        out.push(MedicalDocumentDraftBuilders.buildMedicalReport(
          MedicalDocumentDraftBuilders.asRecord(root[i])));
      }
      return out;
    }
    return [MedicalDocumentDraftBuilders.buildMedicalReport(
      MedicalDocumentDraftBuilders.asRecord(root))];
  }

  static buildPrescriptionDrafts(root: Object | Object[]): PrescriptionRecognitionDraft[] {
    if (Array.isArray(root)) {
      const out: PrescriptionRecognitionDraft[] = [];
      for (let i = 0; i < root.length; i++) {
        out.push(MedicalDocumentDraftBuilders.buildPrescription(
          MedicalDocumentDraftBuilders.asRecord(root[i])));
      }
      return out;
    }
    // 兼容 { drafts: [...] } 包装
    const record = MedicalDocumentDraftBuilders.asRecord(root);
    if (record !== undefined) {
      const wrapped = MedicalDocumentDraftBuilders.mapArray(record, ['drafts'],
        (item): PrescriptionRecognitionDraft => MedicalDocumentDraftBuilders.buildPrescription(item));
      if (wrapped !== undefined && wrapped.length > 0) {
        return wrapped;
      }
    }
    return [MedicalDocumentDraftBuilders.buildPrescription(record)];
  }

  static buildMedicationPlanDrafts(root: Object | Object[]): MedicationPlanRecognitionDraft[] {
    if (Array.isArray(root)) {
      const out: MedicationPlanRecognitionDraft[] = [];
      for (let i = 0; i < root.length; i++) {
        out.push(MedicalDocumentDraftBuilders.buildMedicationPlan(
          MedicalDocumentDraftBuilders.asRecord(root[i])));
      }
      return out;
    }
    return [MedicalDocumentDraftBuilders.buildMedicationPlan(
      MedicalDocumentDraftBuilders.asRecord(root))];
  }

  static buildMedicineBoxDrafts(root: Object | Object[]): MedicineBoxRecognitionDraft[] {
    if (Array.isArray(root)) {
      const out: MedicineBoxRecognitionDraft[] = [];
      for (let i = 0; i < root.length; i++) {
        out.push(MedicalDocumentDraftBuilders.buildMedicineBox(
          MedicalDocumentDraftBuilders.asRecord(root[i])));
      }
      return out;
    }
    return [MedicalDocumentDraftBuilders.buildMedicineBox(
      MedicalDocumentDraftBuilders.asRecord(root))];
  }

  static buildMedicalReport(raw: Record<string, Object | string | number | boolean | null> |
    undefined): MedicalReportRecognitionDraft {
    const draft = new MedicalReportRecognitionDraft();
    if (raw === undefined) {
      draft.title = '医疗报告';
      return draft;
    }
    draft.category = MedicalDocumentDraftBuilders.optString(raw, ['category']);
    draft.title = MedicalDocumentDraftBuilders.reqString(raw, ['title'], '医疗报告');
    draft.hospital = MedicalDocumentDraftBuilders.optString(raw, ['hospital', 'hospitalName']);
    draft.doctor = MedicalDocumentDraftBuilders.optString(raw, ['doctor', 'doctorName']);
    draft.content = MedicalDocumentDraftBuilders.optString(raw, ['content', 'findings']);
    draft.date = MedicalDocumentDraftBuilders.optString(raw, ['date', 'performedAt', 'performed_at']);
    draft.details = MedicalDocumentDraftBuilders.mapArray(raw, ['details', 'items'],
      (item): ItemDraft => MedicalDocumentDraftBuilders.buildItemDraft(item)) ?? [];
    draft.attachmentFileIds = MedicalDocumentDraftBuilders.uuidArray(raw,
      ['attachmentFileIds', 'attachment_file_ids']);
    return draft;
  }

  static buildPrescription(raw: Record<string, Object | string | number | boolean | null> |
    undefined): PrescriptionRecognitionDraft {
    const draft = new PrescriptionRecognitionDraft();
    if (raw === undefined) {
      return draft;
    }
    draft.medicalCase = MedicalDocumentDraftBuilders.optNumber(raw, ['medicalCase', 'medical_case']);
    draft.prescriberName = MedicalDocumentDraftBuilders.optString(raw,
      ['prescriberName', 'prescriber_name']);
    draft.institutionName = MedicalDocumentDraftBuilders.optString(raw,
      ['institutionName', 'institution_name']);
    draft.prescribedAt = MedicalDocumentDraftBuilders.optString(raw,
      ['prescribedAt', 'prescribed_at']);
    draft.diagnosis = MedicalDocumentDraftBuilders.optString(raw, ['diagnosis']);
    draft.prescriptionNo = MedicalDocumentDraftBuilders.optString(raw,
      ['prescriptionNo', 'prescription_no']);
    draft.status = MedicalDocumentDraftBuilders.optString(raw, ['status']);
    draft.extra = MedicalDocumentDraftBuilders.stringMap(raw, ['extra']);
    draft.medicationPlans = MedicalDocumentDraftBuilders.mapArray(raw,
      ['medicationPlans', 'medication_plans'],
      (item): MedicationPlanRecognitionDraft => MedicalDocumentDraftBuilders.buildMedicationPlan(item));
    draft.attachmentFileIds = MedicalDocumentDraftBuilders.uuidArray(raw,
      ['attachmentFileIds', 'attachment_file_ids']);
    return draft;
  }

  static buildMedicationPlan(raw: Record<string, Object | string | number | boolean | null> |
    undefined): MedicationPlanRecognitionDraft {
    const draft = new MedicationPlanRecognitionDraft();
    if (raw === undefined) {
      return draft;
    }
    draft.medicineName = MedicalDocumentDraftBuilders.optString(raw,
      ['medicineName', 'medicine_name']);
    draft.medicineType = MedicalDocumentDraftBuilders.optString(raw,
      ['medicineType', 'medicine_type']);
    draft.totalQuantity = MedicalDocumentDraftBuilders.optString(raw,
      ['totalQuantity', 'total_quantity']);
    draft.expireDate = MedicalDocumentDraftBuilders.optString(raw, ['expireDate', 'expire_date']);
    const box = MedicalDocumentDraftBuilders.childRecord(raw, ['medicineBox', 'medicine_box']);
    if (box !== undefined) {
      draft.medicineBox = MedicalDocumentDraftBuilders.buildMedicineBox(box);
    }
    draft.brandName = MedicalDocumentDraftBuilders.optString(raw, ['brandName', 'brand_name']);
    draft.dosageForm = MedicalDocumentDraftBuilders.optString(raw, ['dosageForm', 'dosage_form']);
    draft.strength = MedicalDocumentDraftBuilders.optString(raw, ['strength']);
    draft.doseUnit = MedicalDocumentDraftBuilders.optString(raw, ['doseUnit', 'dose_unit']);
    draft.dosePerTime = MedicalDocumentDraftBuilders.optString(raw, ['dosePerTime', 'dose_per_time']);
    draft.doseValue = MedicalDocumentDraftBuilders.optString(raw, ['doseValue', 'dose_value']);
    draft.frequencyType = MedicalDocumentDraftBuilders.optString(raw,
      ['frequencyType', 'frequency_type']);
    draft.everyNDays = MedicalDocumentDraftBuilders.optString(raw, ['everyNDays', 'every_n_days']);
    draft.weeklyWeekdays = MedicalDocumentDraftBuilders.numberArray(raw,
      ['weeklyWeekdays', 'weekly_weekdays']);
    draft.frequencyText = MedicalDocumentDraftBuilders.optString(raw,
      ['frequencyText', 'frequency_text']);
    draft.startDate = MedicalDocumentDraftBuilders.optString(raw, ['startDate', 'start_date']);
    draft.endDate = MedicalDocumentDraftBuilders.optString(raw, ['endDate', 'end_date']);
    draft.instructions = MedicalDocumentDraftBuilders.optString(raw, ['instructions']);
    draft.reminderEnabled = MedicalDocumentDraftBuilders.optBool(raw,
      ['reminderEnabled', 'reminder_enabled']);
    draft.reminderTimes = MedicalDocumentDraftBuilders.parseReminderTimes(raw,
      ['reminderTimes', 'reminder_times']);
    draft.status = MedicalDocumentDraftBuilders.optString(raw, ['status']);
    draft.sortOrder = MedicalDocumentDraftBuilders.optString(raw, ['sortOrder', 'sort_order']);
    draft.extra = MedicalDocumentDraftBuilders.stringMap(raw, ['extra']);
    draft.attachmentFileIds = MedicalDocumentDraftBuilders.uuidArray(raw,
      ['attachmentFileIds', 'attachment_file_ids']);
    return draft;
  }

  static buildMedicineBox(raw: Record<string, Object | string | number | boolean | null> |
    undefined): MedicineBoxRecognitionDraft {
    const draft = new MedicineBoxRecognitionDraft();
    if (raw === undefined) {
      return draft;
    }
    draft.medicineName = MedicalDocumentDraftBuilders.optString(raw,
      ['medicineName', 'medicine_name']);
    draft.medicineType = MedicalDocumentDraftBuilders.optString(raw,
      ['medicineType', 'medicine_type']);
    draft.brandName = MedicalDocumentDraftBuilders.optString(raw, ['brandName', 'brand_name']);
    draft.dosageForm = MedicalDocumentDraftBuilders.optString(raw, ['dosageForm', 'dosage_form']);
    draft.strength = MedicalDocumentDraftBuilders.optString(raw, ['strength']);
    draft.doseUnit = MedicalDocumentDraftBuilders.optString(raw, ['doseUnit', 'dose_unit']);
    draft.totalQuantity = MedicalDocumentDraftBuilders.optString(raw,
      ['totalQuantity', 'total_quantity']);
    draft.expireDate = MedicalDocumentDraftBuilders.optString(raw, ['expireDate', 'expire_date']);
    draft.notes = MedicalDocumentDraftBuilders.optString(raw, ['notes']);
    draft.extra = MedicalDocumentDraftBuilders.stringMap(raw, ['extra']);
    draft.sortOrder = MedicalDocumentDraftBuilders.optString(raw, ['sortOrder', 'sort_order']);
    draft.attachmentFileIds = MedicalDocumentDraftBuilders.uuidArray(raw,
      ['attachmentFileIds', 'attachment_file_ids']);
    return draft;
  }

  static buildReportItem(raw: Record<string, Object | string | number | boolean | null> |
    undefined): MedicalReportItem {
    const item = new MedicalReportItem();
    if (raw === undefined) {
      return item;
    }
    item.category = MedicalDocumentDraftBuilders.reqString(raw, ['category'], '');
    item.subCategory = MedicalDocumentDraftBuilders.optString(raw, ['subCategory', 'sub_category']);
    item.itemName = MedicalDocumentDraftBuilders.optString(raw, ['itemName', 'item_name']);
    item.itemCode = MedicalDocumentDraftBuilders.optString(raw, ['itemCode', 'item_code']);
    item.resultValue = MedicalDocumentDraftBuilders.optString(raw, ['resultValue', 'result_value']);
    item.unit = MedicalDocumentDraftBuilders.optString(raw, ['unit']);
    item.referenceRange = MedicalDocumentDraftBuilders.optString(raw,
      ['referenceRange', 'reference_range']);
    item.flag = MedicalDocumentDraftBuilders.optString(raw, ['flag']);
    item.resultAt = MedicalDocumentDraftBuilders.optString(raw, ['resultAt', 'result_at']);
    item.modality = MedicalDocumentDraftBuilders.optString(raw, ['modality']);
    item.bodyPart = MedicalDocumentDraftBuilders.optString(raw, ['bodyPart', 'body_part']);
    item.diagnosis = MedicalDocumentDraftBuilders.optString(raw, ['diagnosis']);
    item.extra = MedicalDocumentDraftBuilders.stringMap(raw, ['extra']);
    item.attachmentFileIds = MedicalDocumentDraftBuilders.uuidArray(raw,
      ['attachmentFileIds', 'attachment_file_ids']);
    item.sortOrder = MedicalDocumentDraftBuilders.optString(raw, ['sortOrder', 'sort_order']);
    return item;
  }

  static buildItemDraft(raw: Record<string, Object | string | number | boolean | null> |
    undefined): ItemDraft {
    const item = new ItemDraft();
    if (raw === undefined) {
      item.id = MedicalDocumentDraftBuilders.newId();
      return item;
    }
    item.id = MedicalDocumentDraftBuilders.optString(raw, ['id']) ??
      MedicalDocumentDraftBuilders.newId();
    item.category = MedicalDocumentDraftBuilders.optString(raw, ['category']);
    item.subCategory = MedicalDocumentDraftBuilders.optString(raw, ['subCategory', 'sub_category']);
    item.itemName = MedicalDocumentDraftBuilders.optString(raw, ['itemName', 'item_name']);
    item.resultValue = MedicalDocumentDraftBuilders.optString(raw, ['resultValue', 'result_value']);
    item.unit = MedicalDocumentDraftBuilders.optString(raw, ['unit']);
    item.referenceRange = MedicalDocumentDraftBuilders.optString(raw,
      ['referenceRange', 'reference_range']);
    item.flag = MedicalDocumentDraftBuilders.optString(raw, ['flag']);
    item.modality = MedicalDocumentDraftBuilders.optString(raw, ['modality']);
    item.bodyPart = MedicalDocumentDraftBuilders.optString(raw, ['bodyPart', 'body_part']);
    item.resultAt = MedicalDocumentDraftBuilders.optString(raw, ['resultAt', 'result_at']);
    item.diagnosis = MedicalDocumentDraftBuilders.optString(raw, ['diagnosis']);
    return item;
  }

  static buildSymptom(raw: Record<string, Object | string | number | boolean | null>):
    SymptomRecognitionDraft {
    const draft = new SymptomRecognitionDraft();
    draft.name = MedicalDocumentDraftBuilders.reqString(raw, ['name'], '');
    draft.code = MedicalDocumentDraftBuilders.optString(raw, ['code']);
    draft.severity = MedicalDocumentDraftBuilders.optString(raw, ['severity']);
    draft.startedAt = MedicalDocumentDraftBuilders.optString(raw, ['startedAt', 'started_at']);
    draft.durationValue = MedicalDocumentDraftBuilders.optString(raw,
      ['durationValue', 'duration_value']);
    draft.durationUnit = MedicalDocumentDraftBuilders.optString(raw,
      ['durationUnit', 'duration_unit']);
    draft.bodyPart = MedicalDocumentDraftBuilders.optString(raw, ['bodyPart', 'body_part']);
    draft.notes = MedicalDocumentDraftBuilders.optString(raw, ['notes']);
    draft.attachmentFileIds = MedicalDocumentDraftBuilders.uuidArray(raw,
      ['attachmentFileIds', 'attachment_file_ids']);
    return draft;
  }

  static buildVisit(raw: Record<string, Object | string | number | boolean | null>):
    VisitRecognitionDraft {
    const draft = new VisitRecognitionDraft();
    draft.visitType = MedicalDocumentDraftBuilders.optString(raw, ['visitType', 'visit_type']);
    draft.visitedAt = MedicalDocumentDraftBuilders.optString(raw, ['visitedAt', 'visited_at']);
    draft.department = MedicalDocumentDraftBuilders.optString(raw, ['department']);
    draft.doctorName = MedicalDocumentDraftBuilders.optString(raw, ['doctorName', 'doctor_name']);
    draft.visitNo = MedicalDocumentDraftBuilders.optString(raw, ['visitNo', 'visit_no']);
    draft.notes = MedicalDocumentDraftBuilders.optString(raw, ['notes']);
    draft.attachmentFileIds = MedicalDocumentDraftBuilders.uuidArray(raw,
      ['attachmentFileIds', 'attachment_file_ids']);
    return draft;
  }

  static buildSurgery(raw: Record<string, Object | string | number | boolean | null>):
    SurgeryRecognitionDraft {
    const draft = new SurgeryRecognitionDraft();
    draft.procedureName = MedicalDocumentDraftBuilders.reqString(raw,
      ['procedureName', 'procedure_name'], '');
    draft.procedureCode = MedicalDocumentDraftBuilders.optString(raw,
      ['procedureCode', 'procedure_code']);
    draft.site = MedicalDocumentDraftBuilders.optString(raw, ['site']);
    draft.performedAt = MedicalDocumentDraftBuilders.optString(raw, ['performedAt', 'performed_at']);
    draft.surgeon = MedicalDocumentDraftBuilders.optString(raw, ['surgeon']);
    draft.anesthesiaType = MedicalDocumentDraftBuilders.optString(raw,
      ['anesthesiaType', 'anesthesia_type']);
    draft.incisionLevel = MedicalDocumentDraftBuilders.optString(raw,
      ['incisionLevel', 'incision_level']);
    draft.asaClass = MedicalDocumentDraftBuilders.optString(raw, ['asaClass', 'asa_class']);
    draft.notes = MedicalDocumentDraftBuilders.optString(raw, ['notes']);
    draft.attachmentFileIds = MedicalDocumentDraftBuilders.uuidArray(raw,
      ['attachmentFileIds', 'attachment_file_ids']);
    return draft;
  }

  static buildFollowUp(raw: Record<string, Object | string | number | boolean | null> |
    undefined): FollowUpRecognitionDraft {
    const draft = new FollowUpRecognitionDraft();
    if (raw === undefined) {
      return draft;
    }
    draft.plannedAt = MedicalDocumentDraftBuilders.optString(raw, ['plannedAt', 'planned_at']);
    draft.completedAt = MedicalDocumentDraftBuilders.optString(raw, ['completedAt', 'completed_at']);
    draft.status = MedicalDocumentDraftBuilders.optString(raw, ['status']);
    draft.method = MedicalDocumentDraftBuilders.optString(raw, ['method']);
    draft.outcome = MedicalDocumentDraftBuilders.optString(raw, ['outcome']);
    draft.nextAction = MedicalDocumentDraftBuilders.optString(raw, ['nextAction', 'next_action']);
    draft.attachmentFileIds = MedicalDocumentDraftBuilders.uuidArray(raw,
      ['attachmentFileIds', 'attachment_file_ids']);
    return draft;
  }

  // —— helpers ——

  private static parseRoot(canonicalJSON: string): Object | Object[] {
    try {
      const parsed = JSON.parse(canonicalJSON) as Object | Object[];
      return parsed;
    } catch (_e) {
      const empty: Record<string, Object> = {};
      return empty;
    }
  }

  private static asRecord(value: Object | Object[] | undefined):
    Record<string, Object | string | number | boolean | null> | undefined {
    if (value === undefined || value === null || Array.isArray(value)) {
      return undefined;
    }
    if (typeof value === 'object') {
      return value as Record<string, Object | string | number | boolean | null>;
    }
    return undefined;
  }

  private static childRecord(
    raw: Record<string, Object | string | number | boolean | null>,
    keys: string[]
  ): Record<string, Object | string | number | boolean | null> | undefined {
    for (let i = 0; i < keys.length; i++) {
      const value = raw[keys[i]];
      if (value !== undefined && value !== null && typeof value === 'object' &&
        !Array.isArray(value)) {
        return value as Record<string, Object | string | number | boolean | null>;
      }
    }
    return undefined;
  }

  private static mapArray<T>(
    raw: Record<string, Object | string | number | boolean | null>,
    keys: string[],
    mapItem: (item: Record<string, Object | string | number | boolean | null> | undefined) => T
  ): T[] | undefined {
    for (let i = 0; i < keys.length; i++) {
      const value = raw[keys[i]];
      if (Array.isArray(value)) {
        const arr = value as Array<Object | string | number | boolean | null>;
        const out: T[] = [];
        for (let j = 0; j < arr.length; j++) {
          out.push(mapItem(MedicalDocumentDraftBuilders.asRecord(arr[j] as Object)));
        }
        return out;
      }
    }
    return undefined;
  }

  private static optString(
    raw: Record<string, Object | string | number | boolean | null>,
    keys: string[]
  ): string | undefined {
    for (let i = 0; i < keys.length; i++) {
      const value = raw[keys[i]];
      if (value === undefined || value === null) {
        continue;
      }
      if (typeof value === 'string') {
        const trimmed = value.trim();
        return trimmed.length > 0 ? trimmed : undefined;
      }
      if (typeof value === 'number' || typeof value === 'boolean') {
        return `${value}`;
      }
    }
    return undefined;
  }

  private static reqString(
    raw: Record<string, Object | string | number | boolean | null>,
    keys: string[],
    fallback: string
  ): string {
    return MedicalDocumentDraftBuilders.optString(raw, keys) ?? fallback;
  }

  private static optNumber(
    raw: Record<string, Object | string | number | boolean | null>,
    keys: string[]
  ): number | undefined {
    for (let i = 0; i < keys.length; i++) {
      const value = raw[keys[i]];
      if (typeof value === 'number') {
        return value;
      }
      if (typeof value === 'string' && value.trim().length > 0) {
        const n = Number(value);
        if (!(n !== n)) {
          return n;
        }
      }
    }
    return undefined;
  }

  private static optBool(
    raw: Record<string, Object | string | number | boolean | null>,
    keys: string[]
  ): boolean | undefined {
    for (let i = 0; i < keys.length; i++) {
      const value = raw[keys[i]];
      if (typeof value === 'boolean') {
        return value;
      }
      if (typeof value === 'string') {
        const lower = value.trim().toLowerCase();
        if (lower === 'true' || lower === '1') {
          return true;
        }
        if (lower === 'false' || lower === '0') {
          return false;
        }
      }
      if (typeof value === 'number') {
        return value !== 0;
      }
    }
    return undefined;
  }

  private static uuidArray(
    raw: Record<string, Object | string | number | boolean | null>,
    keys: string[]
  ): string[] {
    for (let i = 0; i < keys.length; i++) {
      const value = raw[keys[i]];
      if (Array.isArray(value)) {
        const arr = value as Array<Object | string | number | boolean | null>;
        const out: string[] = [];
        for (let j = 0; j < arr.length; j++) {
          const item: Object | string | number | boolean | null = arr[j];
          if (typeof item === 'string' && item.trim().length > 0) {
            out.push(item.trim());
          }
        }
        return out;
      }
    }
    return [];
  }

  private static numberArray(
    raw: Record<string, Object | string | number | boolean | null>,
    keys: string[]
  ): number[] | undefined {
    for (let i = 0; i < keys.length; i++) {
      const value = raw[keys[i]];
      if (Array.isArray(value)) {
        const arr = value as Array<Object | string | number | boolean | null>;
        const out: number[] = [];
        for (let j = 0; j < arr.length; j++) {
          const item: Object | string | number | boolean | null = arr[j];
          if (typeof item === 'number') {
            out.push(item);
          } else if (typeof item === 'string') {
            const n = Number(item);
            if (!(n !== n)) {
              out.push(n);
            }
          }
        }
        return out;
      }
    }
    return undefined;
  }

  private static stringMap(
    raw: Record<string, Object | string | number | boolean | null>,
    keys: string[]
  ): Map<string, string> | undefined {
    for (let i = 0; i < keys.length; i++) {
      const value = raw[keys[i]];
      if (value !== undefined && value !== null && typeof value === 'object' &&
        !Array.isArray(value)) {
        const record = value as Record<string, Object | string | number | boolean | null>;
        const out = new Map<string, string>();
        const ks = Object.keys(record);
        for (let j = 0; j < ks.length; j++) {
          const v = record[ks[j]];
          if (v === null || v === undefined) {
            continue;
          }
          out.set(ks[j], `${v}`);
        }
        return out.size > 0 ? out : undefined;
      }
    }
    return undefined;
  }

  private static parseReminderTimes(
    raw: Record<string, Object | string | number | boolean | null>,
    keys: string[]
  ): ReminderTime[] | undefined {
    for (let i = 0; i < keys.length; i++) {
      const value = raw[keys[i]];
      if (!Array.isArray(value) || value.length === 0) {
        continue;
      }
      const arr = value as Array<Object | string | number | boolean | null>;
      const out: ReminderTime[] = [];
      for (let j = 0; j < arr.length; j++) {
        const item: Object | string | number | boolean | null = arr[j];
        if (typeof item === 'string') {
          const t = item.trim();
          if (t.length > 0) {
            out.push(ReminderTime.make(t));
          }
          continue;
        }
        const record = MedicalDocumentDraftBuilders.asRecord(item as Object);
        if (record === undefined) {
          continue;
        }
        const time = MedicalDocumentDraftBuilders.optString(record, ['time']) ?? '';
        if (time.length === 0) {
          continue;
        }
        let dose: number | undefined = undefined;
        let doseText: string | undefined = undefined;
        const doseRaw = record['dose'];
        if (typeof doseRaw === 'number') {
          dose = doseRaw;
        } else if (typeof doseRaw === 'string') {
          doseText = doseRaw.trim();
          const n = Number(doseRaw);
          if (!(n !== n)) {
            dose = n;
          }
        }
        const text = MedicalDocumentDraftBuilders.optString(record, ['doseText', 'dose_text']);
        if (text !== undefined) {
          doseText = text;
        }
        out.push(ReminderTime.make(time, dose, doseText));
      }
      return out.length > 0 ? out : undefined;
    }
    return undefined;
  }

  private static newId(): string {
    return `item_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
  }
}

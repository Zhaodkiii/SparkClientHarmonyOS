import {
  CaseRecognitionDraft,
  FollowUpRecognitionDraft,
  HealthExamRecognitionDraft,
  ItemDraft,
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
 * 保存请求 DTO（本地草稿 → 远端契约的中间形态）。
 * 对齐 iOS MedicalDocumentDraftMappers / DefaultTypedMedicalDocumentSaver 字段名。
 * 本工单只定义映射层，不发起网络保存。
 */

export class SymptomCreateRequest {
  name: string = '';
  code?: string;
  severity?: string;
  startedAt?: string;
  durationValue?: number;
  durationUnit?: string;
  bodyPart?: string;
  notes?: string;
  sourceFileIds: string[] = [];
}

export class VisitCreateRequest {
  visitType?: string;
  visitedAt?: string;
  department?: string;
  doctorName?: string;
  visitNo?: string;
  notes?: string;
  sourceFileIds: string[] = [];
}

export class SurgeryCreateRequest {
  procedureName: string = '';
  procedureCode?: string;
  site?: string;
  performedAt?: string;
  surgeon?: string;
  anesthesiaType?: string;
  incisionLevel?: string;
  asaClass?: string;
  notes?: string;
  sourceFileIds: string[] = [];
}

export class FollowUpCreateRequest {
  plannedAt?: string;
  completedAt?: string;
  status?: string;
  method?: string;
  outcome?: string;
  nextAction?: string;
  sourceFileIds: string[] = [];
}

export class MedicalCaseCreateRequest {
  title: string = '';
  diagnosisSummary?: string;
  hospitalName?: string;
  ageAtVisit?: number;
  sourceFileIds: string[] = [];
  extra: Map<string, string> = new Map();
}

export class ExaminationReportDetailRequest {
  category: string = '';
  subCategory?: string;
  itemName?: string;
  itemCode?: string;
  resultValue?: string;
  unit?: string;
  referenceRange?: string;
  flag?: string;
  resultAt?: string;
  modality?: string;
  bodyPart?: string;
  diagnosis?: string;
  sortOrder?: number;
  sourceFileIds: string[] = [];
  extra: Map<string, string> = new Map();
}

export class ExaminationReportCreateRequest {
  category?: string;
  itemName?: string;
  organizationName?: string;
  doctorName?: string;
  findings?: string;
  performedAt?: string;
  impression?: string;
  details: ExaminationReportDetailRequest[] = [];
  sourceFileIds: string[] = [];
}

export class MedicationPlanBundleItemPayload {
  medicineName?: string;
  medicineType?: string;
  brandName?: string;
  dosageForm?: string;
  strength?: string;
  doseUnit?: string;
  dosePerTime?: string;
  doseValue?: string;
  frequencyType: string = 'daily';
  everyNDays?: string;
  weeklyWeekdays?: number[];
  frequencyText?: string;
  startDate?: string;
  endDate?: string;
  instructions?: string;
  reminderEnabled: boolean = false;
  reminderTimes: ReminderTime[] = [];
  status: string = 'active';
  sortOrder?: string;
  totalQuantity?: string;
  expireDate?: string;
  medicineBox?: MedicineBoxCreateRequest;
  extra: Map<string, string> = new Map();
  sourceFileIds: string[] = [];
}

export class MedicineBoxCreateRequest {
  medicineName?: string;
  medicineType?: string;
  brandName?: string;
  dosageForm?: string;
  strength?: string;
  doseUnit?: string;
  totalQuantity?: string;
  expireDate?: string;
  notes?: string;
  sortOrder?: string;
  extra: Map<string, string> = new Map();
  sourceFileIds: string[] = [];
}

export class PrescriptionCreateRequest {
  medicalCase?: number;
  prescriberName?: string;
  institutionName?: string;
  prescribedAt?: string;
  diagnosis?: string;
  prescriptionNo?: string;
  status: string = 'active';
  medicationPlans: MedicationPlanBundleItemPayload[] = [];
  extra: Map<string, string> = new Map();
  sourceFileIds: string[] = [];
}

/**
 * 草稿 → 保存请求映射。对齐 iOS MedicalDocumentDraftMappers。
 */
export class MedicalDocumentDraftMappers {
  static symptomToCreateRequest(
    draft: SymptomRecognitionDraft,
    sourceFileIds: string[] = []
  ): SymptomCreateRequest {
    const req = new SymptomCreateRequest();
    req.name = draft.name;
    req.code = draft.code;
    req.severity = draft.severity;
    req.startedAt = draft.startedAt;
    req.durationValue = MedicalDocumentDraftMappers.parseOptionalInt(draft.durationValue);
    req.durationUnit = draft.durationUnit;
    req.bodyPart = draft.bodyPart;
    req.notes = draft.notes;
    req.sourceFileIds = MedicalDocumentDraftMappers.mergeIds(draft.attachmentFileIds, sourceFileIds);
    return req;
  }

  static visitToCreateRequest(
    draft: VisitRecognitionDraft,
    sourceFileIds: string[] = []
  ): VisitCreateRequest {
    const req = new VisitCreateRequest();
    req.visitType = draft.visitType;
    req.visitedAt = draft.visitedAt;
    req.department = draft.department;
    req.doctorName = draft.doctorName;
    req.visitNo = draft.visitNo;
    req.notes = draft.notes;
    req.sourceFileIds = MedicalDocumentDraftMappers.mergeIds(draft.attachmentFileIds, sourceFileIds);
    return req;
  }

  static surgeryToCreateRequest(
    draft: SurgeryRecognitionDraft,
    sourceFileIds: string[] = []
  ): SurgeryCreateRequest {
    const req = new SurgeryCreateRequest();
    req.procedureName = draft.procedureName;
    req.procedureCode = draft.procedureCode;
    req.site = draft.site;
    req.performedAt = draft.performedAt;
    req.surgeon = draft.surgeon;
    req.anesthesiaType = draft.anesthesiaType;
    req.incisionLevel = draft.incisionLevel;
    req.asaClass = draft.asaClass;
    req.notes = draft.notes;
    req.sourceFileIds = MedicalDocumentDraftMappers.mergeIds(draft.attachmentFileIds, sourceFileIds);
    return req;
  }

  static followUpToCreateRequest(
    draft: FollowUpRecognitionDraft,
    sourceFileIds: string[] = []
  ): FollowUpCreateRequest {
    const req = new FollowUpCreateRequest();
    req.plannedAt = draft.plannedAt;
    req.completedAt = draft.completedAt;
    req.status = draft.status;
    req.method = draft.method;
    req.outcome = draft.outcome;
    req.nextAction = draft.nextAction;
    req.sourceFileIds = MedicalDocumentDraftMappers.mergeIds(draft.attachmentFileIds, sourceFileIds);
    return req;
  }

  static caseToCreateRequest(
    draft: CaseRecognitionDraft,
    sourceFileIds: string[] = []
  ): MedicalCaseCreateRequest {
    const req = new MedicalCaseCreateRequest();
    req.title = draft.title;
    const parts: string[] = [];
    if (draft.summary !== undefined && draft.summary.length > 0) {
      parts.push(draft.summary);
    }
    if (draft.diagnosis !== undefined && draft.diagnosis.length > 0) {
      parts.push(draft.diagnosis);
    }
    req.diagnosisSummary = parts.length > 0 ? parts.join('\n') : undefined;
    req.hospitalName = draft.hospitalName;
    req.ageAtVisit = MedicalDocumentDraftMappers.parseOptionalInt(draft.ageAtVisit);
    req.sourceFileIds = MedicalDocumentDraftMappers.mergeIds(draft.attachmentFileIds, sourceFileIds);
    if (draft.occurredAt !== undefined && draft.occurredAt.length > 0) {
      req.extra.set('occurred_at', draft.occurredAt);
    }
    return req;
  }

  static itemDraftToMedicalReportItem(
    draft: ItemDraft,
    fallbackCategory: string = '',
    sortOrder?: string
  ): MedicalReportItem {
    const item = new MedicalReportItem();
    item.category = (draft.category !== undefined && draft.category.length > 0) ?
      draft.category : fallbackCategory;
    item.subCategory = draft.subCategory;
    item.itemName = draft.itemName;
    item.resultValue = draft.resultValue;
    item.unit = draft.unit;
    item.referenceRange = draft.referenceRange;
    item.flag = draft.flag;
    item.modality = draft.modality;
    item.bodyPart = draft.bodyPart;
    item.resultAt = draft.resultAt;
    item.diagnosis = draft.diagnosis;
    item.sortOrder = sortOrder;
    return item;
  }

  static medicalReportItemToDetailRequest(item: MedicalReportItem): ExaminationReportDetailRequest {
    const req = new ExaminationReportDetailRequest();
    req.category = item.category;
    req.subCategory = item.subCategory;
    req.itemName = item.itemName;
    req.itemCode = item.itemCode;
    req.resultValue = item.resultValue;
    req.unit = item.unit;
    req.referenceRange = item.referenceRange;
    req.flag = item.flag;
    req.resultAt = item.resultAt;
    req.modality = item.modality;
    req.bodyPart = item.bodyPart;
    req.diagnosis = item.diagnosis;
    req.sortOrder = MedicalDocumentDraftMappers.parseOptionalInt(item.sortOrder);
    req.sourceFileIds = item.attachmentFileIds.slice();
    if (item.extra !== undefined) {
      item.extra.forEach((v: string, k: string) => {
        req.extra.set(k, v);
      });
    }
    return req;
  }

  static medicalReportToCreateRequest(
    draft: MedicalReportRecognitionDraft,
    sourceFileIds: string[] = []
  ): ExaminationReportCreateRequest {
    const req = new ExaminationReportCreateRequest();
    req.category = draft.category;
    req.itemName = draft.title;
    req.organizationName = draft.hospital;
    req.doctorName = draft.doctor;
    req.findings = draft.content;
    req.performedAt = draft.date;
    const impressions: string[] = [];
    for (let i = 0; i < draft.details.length; i++) {
      const detail = draft.details[i];
      if (detail.diagnosis !== undefined && detail.diagnosis.length > 0) {
        impressions.push(detail.diagnosis);
      }
      const item = MedicalDocumentDraftMappers.itemDraftToMedicalReportItem(
        detail,
        draft.category ?? '',
        `${i}`
      );
      req.details.push(MedicalDocumentDraftMappers.medicalReportItemToDetailRequest(item));
    }
    req.impression = impressions.length > 0 ? impressions.join('；') : undefined;
    req.sourceFileIds = MedicalDocumentDraftMappers.mergeIds(draft.attachmentFileIds, sourceFileIds);
    return req;
  }

  static healthExamToCreateRequests(
    draft: HealthExamRecognitionDraft,
    sourceFileIds: string[] = []
  ): ExaminationReportCreateRequest[] {
    const groups = new Map<string, MedicalReportItem[]>();
    for (let i = 0; i < draft.items.length; i++) {
      const item = draft.items[i];
      const key = item.category.length > 0 ? item.category : '未分类';
      const list = groups.get(key) ?? [];
      list.push(item);
      groups.set(key, list);
    }
    const out: ExaminationReportCreateRequest[] = [];
    groups.forEach((items: MedicalReportItem[], category: string) => {
      const req = new ExaminationReportCreateRequest();
      req.category = category;
      req.itemName = draft.examType ?? category;
      req.organizationName = draft.institutionName;
      req.performedAt = draft.examDate;
      req.findings = draft.summary;
      for (let i = 0; i < items.length; i++) {
        req.details.push(MedicalDocumentDraftMappers.medicalReportItemToDetailRequest(items[i]));
      }
      req.sourceFileIds = MedicalDocumentDraftMappers.mergeIds(draft.attachmentFileIds, sourceFileIds);
      out.push(req);
    });
    if (out.length === 0) {
      const empty = new ExaminationReportCreateRequest();
      empty.organizationName = draft.institutionName;
      empty.itemName = draft.examType ?? '体检报告';
      empty.performedAt = draft.examDate;
      empty.findings = draft.summary;
      empty.sourceFileIds = MedicalDocumentDraftMappers.mergeIds(draft.attachmentFileIds, sourceFileIds);
      out.push(empty);
    }
    return out;
  }

  static prescriptionToCreateRequest(
    draft: PrescriptionRecognitionDraft,
    sourceFileIds: string[] = []
  ): PrescriptionCreateRequest {
    const normalized = PrescriptionFieldNormalization.normalizePrescriptionDraft(draft);
    const req = new PrescriptionCreateRequest();
    req.medicalCase = normalized.medicalCase;
    req.prescriberName = normalized.prescriberName;
    req.institutionName = normalized.institutionName;
    req.prescribedAt = normalized.prescribedAt;
    req.diagnosis = normalized.diagnosis;
    req.prescriptionNo = normalized.prescriptionNo;
    req.status = PrescriptionFieldNormalization.resolvedLifecycleStatus(normalized.status);
    if (normalized.extra !== undefined) {
      normalized.extra.forEach((v: string, k: string) => {
        req.extra.set(k, v);
      });
    }
    const plans = normalized.medicationPlans ?? [];
    for (let i = 0; i < plans.length; i++) {
      req.medicationPlans.push(
        MedicalDocumentDraftMappers.medicationPlanToBundleItem(plans[i])
      );
    }
    req.sourceFileIds = MedicalDocumentDraftMappers.mergeIds(
      normalized.attachmentFileIds,
      sourceFileIds
    );
    return req;
  }

  static medicationPlanToBundleItem(
    draft: MedicationPlanRecognitionDraft
  ): MedicationPlanBundleItemPayload {
    const normalized = PrescriptionFieldNormalization.normalizeMedicationPlanDraft(draft);
    const req = new MedicationPlanBundleItemPayload();
    req.medicineName = normalized.medicineName;
    req.medicineType = normalized.medicineType;
    req.brandName = normalized.brandName;
    req.dosageForm = normalized.dosageForm;
    req.strength = normalized.strength;
    req.doseUnit = normalized.doseUnit;
    req.dosePerTime = normalized.dosePerTime;
    req.doseValue = normalized.doseValue;
    req.frequencyType = normalized.frequencyType ?? 'daily';
    req.everyNDays = normalized.everyNDays;
    req.weeklyWeekdays = normalized.weeklyWeekdays;
    req.frequencyText = normalized.frequencyText;
    req.startDate = normalized.startDate;
    req.endDate = normalized.endDate;
    req.instructions = normalized.instructions;
    req.reminderEnabled = normalized.reminderEnabled ?? false;
    req.reminderTimes = normalized.reminderTimes ?? [];
    req.status = normalized.status ?? 'active';
    req.sortOrder = normalized.sortOrder;
    req.totalQuantity = normalized.totalQuantity;
    req.expireDate = normalized.expireDate;
    if (normalized.medicineBox !== undefined) {
      req.medicineBox = MedicalDocumentDraftMappers.medicineBoxToCreateRequest(normalized.medicineBox);
    }
    if (normalized.extra !== undefined) {
      normalized.extra.forEach((v: string, k: string) => {
        req.extra.set(k, v);
      });
    }
    req.sourceFileIds = normalized.attachmentFileIds.slice();
    return req;
  }

  static medicineBoxToCreateRequest(
    draft: MedicineBoxRecognitionDraft,
    sourceFileIds: string[] = []
  ): MedicineBoxCreateRequest {
    const req = new MedicineBoxCreateRequest();
    req.medicineName = draft.medicineName;
    req.medicineType = draft.medicineType;
    req.brandName = draft.brandName;
    req.dosageForm = draft.dosageForm;
    req.strength = draft.strength;
    req.doseUnit = draft.doseUnit;
    req.totalQuantity = draft.totalQuantity;
    req.expireDate = draft.expireDate;
    req.notes = draft.notes;
    req.sortOrder = draft.sortOrder;
    if (draft.extra !== undefined) {
      draft.extra.forEach((v: string, k: string) => {
        req.extra.set(k, v);
      });
    }
    req.sourceFileIds = MedicalDocumentDraftMappers.mergeIds(draft.attachmentFileIds, sourceFileIds);
    return req;
  }

  private static mergeIds(a: string[], b: string[]): string[] {
    const out: string[] = a.slice();
    for (let i = 0; i < b.length; i++) {
      if (out.indexOf(b[i]) < 0) {
        out.push(b[i]);
      }
    }
    return out;
  }

  private static parseOptionalInt(raw: string | undefined): number | undefined {
    if (raw === undefined || raw.trim().length === 0) {
      return undefined;
    }
    const n = parseInt(raw.trim(), 10);
    return isNaN(n) ? undefined : n;
  }
}

import { MedicalDocumentKind } from './MedicalDocumentKind';

/**
 * 用药提醒时间点。对齐 iOS `ReminderTime`。
 * time 为 HH:mm；dose 为数值；doseText 为可读剂量。
 */
export class ReminderTime {
  time: string = '';
  dose?: number;
  doseText?: string;

  static make(time: string, dose?: number, doseText?: string): ReminderTime {
    const item = new ReminderTime();
    item.time = time.trim();
    item.dose = dose;
    const text = doseText !== undefined ? doseText.trim() : '';
    item.doseText = text.length > 0 ? text : undefined;
    return item;
  }
}

/** 医疗报告 / 体检指标明细。对齐 iOS `MedicalReportItem`。 */
export class MedicalReportItem {
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
  extra?: Map<string, string>;
  attachmentFileIds: string[] = [];
  sortOrder?: string;
}

/** UI 编辑态明细桥接。对齐 iOS `ItemDraft`。 */
export class ItemDraft {
  id: string = '';
  category?: string;
  subCategory?: string;
  itemName?: string;
  resultValue?: string;
  unit?: string;
  referenceRange?: string;
  flag?: string;
  modality?: string;
  bodyPart?: string;
  resultAt?: string;
  diagnosis?: string;
}

export class SymptomRecognitionDraft {
  name: string = '';
  code?: string;
  severity?: string;
  startedAt?: string;
  durationValue?: string;
  durationUnit?: string;
  bodyPart?: string;
  notes?: string;
  attachmentFileIds: string[] = [];
}

export class VisitRecognitionDraft {
  visitType?: string;
  visitedAt?: string;
  department?: string;
  doctorName?: string;
  visitNo?: string;
  notes?: string;
  attachmentFileIds: string[] = [];
}

export class SurgeryRecognitionDraft {
  procedureName: string = '';
  procedureCode?: string;
  site?: string;
  performedAt?: string;
  surgeon?: string;
  anesthesiaType?: string;
  incisionLevel?: string;
  asaClass?: string;
  notes?: string;
  attachmentFileIds: string[] = [];
}

export class FollowUpRecognitionDraft {
  plannedAt?: string;
  completedAt?: string;
  status?: string;
  method?: string;
  outcome?: string;
  nextAction?: string;
  attachmentFileIds: string[] = [];
}

export class MedicineBoxRecognitionDraft {
  medicineName?: string;
  medicineType?: string;
  brandName?: string;
  dosageForm?: string;
  strength?: string;
  doseUnit?: string;
  totalQuantity?: string;
  expireDate?: string;
  notes?: string;
  extra?: Map<string, string>;
  sortOrder?: string;
  attachmentFileIds: string[] = [];
}

export class MedicationPlanRecognitionDraft {
  medicineName?: string;
  medicineType?: string;
  totalQuantity?: string;
  expireDate?: string;
  medicineBox?: MedicineBoxRecognitionDraft;
  brandName?: string;
  dosageForm?: string;
  strength?: string;
  doseUnit?: string;
  dosePerTime?: string;
  doseValue?: string;
  frequencyType?: string;
  everyNDays?: string;
  weeklyWeekdays?: number[];
  frequencyText?: string;
  startDate?: string;
  endDate?: string;
  instructions?: string;
  reminderEnabled?: boolean;
  reminderTimes?: ReminderTime[];
  status?: string;
  sortOrder?: string;
  extra?: Map<string, string>;
  attachmentFileIds: string[] = [];
}

export class PrescriptionRecognitionDraft {
  medicalCase?: number;
  prescriberName?: string;
  institutionName?: string;
  prescribedAt?: string;
  diagnosis?: string;
  prescriptionNo?: string;
  status?: string;
  extra?: Map<string, string>;
  medicationPlans?: MedicationPlanRecognitionDraft[];
  attachmentFileIds: string[] = [];
}

export class MedicalReportRecognitionDraft {
  category?: string;
  title: string = '';
  hospital?: string;
  doctor?: string;
  content?: string;
  date?: string;
  details: ItemDraft[] = [];
  attachmentFileIds: string[] = [];
}

export class HealthExamRecognitionDraft {
  institutionName?: string;
  reportNo?: string;
  examDate?: string;
  examType?: string;
  summary?: string;
  items: MedicalReportItem[] = [];
  attachmentFileIds: string[] = [];
}

export class CaseRecognitionDraft {
  title: string = '';
  summary?: string;
  diagnosis?: string;
  hospitalName?: string;
  ageAtVisit?: string;
  occurredAt?: string;
  attachmentFileIds: string[] = [];
  symptom?: SymptomRecognitionDraft;
  visit?: VisitRecognitionDraft;
  surgery?: SurgeryRecognitionDraft;
  followUps?: FollowUpRecognitionDraft[];
  prescriptions?: PrescriptionRecognitionDraft[];
  examinationReports?: MedicalReportRecognitionDraft[];
}

/**
 * 分类型草稿树容器。对齐 iOS `MedicalDocumentTypedResult` 枚举关联值。
 * 同一时刻仅按 kind 填充对应分支。
 */
export class MedicalDocumentTypedDraftTree {
  kind: MedicalDocumentKind = MedicalDocumentKind.MEDICAL_REPORT;
  caseDraft?: CaseRecognitionDraft;
  healthExamDraft?: HealthExamRecognitionDraft;
  medicalReportDrafts: MedicalReportRecognitionDraft[] = [];
  prescriptionDrafts: PrescriptionRecognitionDraft[] = [];
  medicationPlanDrafts: MedicationPlanRecognitionDraft[] = [];
  medicineBoxDrafts: MedicineBoxRecognitionDraft[] = [];

  /** 结果页摘要标题：从当前分支推导。 */
  displayTitle(): string {
    switch (this.kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        return this.caseDraft?.title ?? '';
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        return this.healthExamDraft?.institutionName ??
          this.healthExamDraft?.summary ?? '体检报告';
      case MedicalDocumentKind.MEDICAL_REPORT:
        return this.medicalReportDrafts.length > 0 ?
          this.medicalReportDrafts[0].title : '医疗报告';
      case MedicalDocumentKind.PRESCRIPTION:
        return this.prescriptionDrafts.length > 0 ?
          (this.prescriptionDrafts[0].prescriptionNo ??
            this.prescriptionDrafts[0].diagnosis ?? '处方') : '处方';
      case MedicalDocumentKind.MEDICATION_PLAN:
        return this.medicationPlanDrafts.length > 0 ?
          (this.medicationPlanDrafts[0].medicineName ?? '用药计划') : '用药计划';
      case MedicalDocumentKind.MEDICINE_BOX:
        return this.medicineBoxDrafts.length > 0 ?
          (this.medicineBoxDrafts[0].medicineName ?? '药箱') : '药箱';
      default:
        return '';
    }
  }

  displaySummary(): string {
    switch (this.kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        return this.caseDraft?.summary ?? this.caseDraft?.diagnosis ?? '';
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        return this.healthExamDraft?.summary ?? '';
      case MedicalDocumentKind.MEDICAL_REPORT:
        return this.medicalReportDrafts.length > 0 ?
          (this.medicalReportDrafts[0].content ?? '') : '';
      case MedicalDocumentKind.PRESCRIPTION:
        return this.prescriptionDrafts.length > 0 ?
          (this.prescriptionDrafts[0].diagnosis ?? '') : '';
      case MedicalDocumentKind.MEDICATION_PLAN:
        return `共 ${this.medicationPlanDrafts.length} 条用药计划`;
      case MedicalDocumentKind.MEDICINE_BOX:
        return `共 ${this.medicineBoxDrafts.length} 个药箱条目`;
      default:
        return '';
    }
  }

  /**
   * JSON 深拷贝会丢失类方法；附件匹配等路径会产出 plain object，调用前需还原为类实例。
   */
  static ensureInstance(tree: MedicalDocumentTypedDraftTree): MedicalDocumentTypedDraftTree {
    if (typeof tree.displayTitle === 'function' && typeof tree.displaySummary === 'function') {
      return tree;
    }
    const copy = new MedicalDocumentTypedDraftTree();
    copy.kind = tree.kind;
    copy.caseDraft = tree.caseDraft;
    copy.healthExamDraft = tree.healthExamDraft;
    copy.medicalReportDrafts = tree.medicalReportDrafts.slice();
    copy.prescriptionDrafts = tree.prescriptionDrafts.slice();
    copy.medicationPlanDrafts = tree.medicationPlanDrafts.slice();
    copy.medicineBoxDrafts = tree.medicineBoxDrafts.slice();
    return copy;
  }
}

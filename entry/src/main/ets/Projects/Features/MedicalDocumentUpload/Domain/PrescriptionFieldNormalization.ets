import {
  MedicationPlanRecognitionDraft,
  PrescriptionRecognitionDraft,
  ReminderTime
} from './MedicalDocumentRecognitionDrafts';

/** 处方生命周期白名单。对齐 iOS PrescriptionLifecycleStatus。 */
export const PRESCRIPTION_LIFECYCLE_STATUSES: string[] = ['active', 'completed', 'cancelled'];

/** 用药计划生命周期白名单。对齐 iOS MedicationPlanLifecycleStatus。 */
export const MEDICATION_PLAN_LIFECYCLE_STATUSES: string[] =
  ['active', 'paused', 'completed', 'cancelled'];

/** 频次类型白名单。对齐 iOS MedicationReminderFrequencyType。 */
export const MEDICATION_FREQUENCY_TYPES: string[] = ['daily', 'every_n_days', 'weekly'];

export const EXTRA_KEY_PRESCRIPTION_TYPE_TEXT: string = 'prescriptionTypeText';
export const EXTRA_KEY_PAYMENT_STATUS_TEXT: string = 'paymentStatusText';
export const EXTRA_KEY_RAW_STATUS_TEXT: string = 'rawStatusText';

export class PrescriptionStatusNormalizeResult {
  status: string = 'active';
  extraUpdates: Map<string, string> = new Map();
}

/**
 * 处方 / 用药计划字段规范化。对齐 iOS PrescriptionFieldNormalization。
 */
export class PrescriptionFieldNormalization {
  static normalizePrescriptionDraft(
    draft: PrescriptionRecognitionDraft
  ): PrescriptionRecognitionDraft {
    const out = PrescriptionFieldNormalization.clonePrescription(draft);
    const statusResult = PrescriptionFieldNormalization.normalizePrescriptionStatus(
      out.status,
      out.extra
    );
    out.status = statusResult.status;
    out.extra = PrescriptionFieldNormalization.mergeExtra(out.extra, statusResult.extraUpdates);
    if (out.medicationPlans !== undefined) {
      const plans: MedicationPlanRecognitionDraft[] = [];
      for (let i = 0; i < out.medicationPlans.length; i++) {
        const plan = PrescriptionFieldNormalization.normalizeMedicationPlanDraft(
          out.medicationPlans[i]
        );
        if (plan.sortOrder === undefined || plan.sortOrder.trim().length === 0) {
          plan.sortOrder = `${i}`;
        }
        plans.push(plan);
      }
      out.medicationPlans = plans;
    }
    return out;
  }

  static normalizeMedicationPlanDraft(
    draft: MedicationPlanRecognitionDraft
  ): MedicationPlanRecognitionDraft {
    const out = PrescriptionFieldNormalization.cloneMedicationPlan(draft);
    out.status = PrescriptionFieldNormalization.normalizeMedicationPlanStatus(out.status);
    out.frequencyType = PrescriptionFieldNormalization.normalizeFrequencyType(out.frequencyType);
    out.reminderTimes = PrescriptionFieldNormalization.normalizeReminderTimes(out.reminderTimes);
    return out;
  }

  static normalizePrescriptionDrafts(
    drafts: PrescriptionRecognitionDraft[]
  ): PrescriptionRecognitionDraft[] {
    const out: PrescriptionRecognitionDraft[] = [];
    for (let i = 0; i < drafts.length; i++) {
      out.push(PrescriptionFieldNormalization.normalizePrescriptionDraft(drafts[i]));
    }
    return out;
  }

  static normalizeMedicationPlanDrafts(
    drafts: MedicationPlanRecognitionDraft[]
  ): MedicationPlanRecognitionDraft[] {
    const out: MedicationPlanRecognitionDraft[] = [];
    for (let i = 0; i < drafts.length; i++) {
      const plan = PrescriptionFieldNormalization.normalizeMedicationPlanDraft(drafts[i]);
      if (plan.sortOrder === undefined || plan.sortOrder.trim().length === 0) {
        plan.sortOrder = `${i}`;
      }
      out.push(plan);
    }
    return out;
  }

  static normalizePrescriptionStatus(
    raw: string | undefined,
    _extra?: Map<string, string>
  ): PrescriptionStatusNormalizeResult {
    const result = new PrescriptionStatusNormalizeResult();
    if (raw === undefined || raw.trim().length === 0) {
      result.status = 'active';
      return result;
    }
    const trimmed = raw.trim();
    const lower = trimmed.toLowerCase();
    if (PRESCRIPTION_LIFECYCLE_STATUSES.indexOf(lower) >= 0) {
      result.status = lower;
      return result;
    }
    if (PrescriptionFieldNormalization.isPaymentStatusText(trimmed, lower)) {
      result.status = 'active';
      result.extraUpdates.set(EXTRA_KEY_PAYMENT_STATUS_TEXT, trimmed);
      result.extraUpdates.set(EXTRA_KEY_RAW_STATUS_TEXT, trimmed);
      return result;
    }
    if (PrescriptionFieldNormalization.isPrescriptionTypeText(trimmed, lower)) {
      result.status = 'active';
      result.extraUpdates.set(EXTRA_KEY_PRESCRIPTION_TYPE_TEXT, trimmed);
      result.extraUpdates.set(EXTRA_KEY_RAW_STATUS_TEXT, trimmed);
      return result;
    }
    result.status = 'active';
    result.extraUpdates.set(EXTRA_KEY_RAW_STATUS_TEXT, trimmed);
    return result;
  }

  static normalizeMedicationPlanStatus(raw: string | undefined): string {
    if (raw === undefined || raw.trim().length === 0) {
      return 'active';
    }
    const trimmed = raw.trim();
    const lower = trimmed.toLowerCase();
    if (MEDICATION_PLAN_LIFECYCLE_STATUSES.indexOf(lower) >= 0) {
      return lower;
    }
    if (trimmed === '执行中' || trimmed === '生效' || trimmed === '有效' || trimmed === '进行中') {
      return 'active';
    }
    // 对齐 iOS：未知值透传，由预检拦截。
    return trimmed;
  }

  static normalizeFrequencyType(raw: string | undefined): string {
    if (raw === undefined || raw.trim().length === 0) {
      return 'daily';
    }
    const lower = raw.trim().toLowerCase();
    if (lower === 'every_n_days' || lower === 'interval' || raw.trim() === '间隔') {
      return 'every_n_days';
    }
    if (lower === 'weekly' || lower === 'week' || raw.trim() === '每周') {
      return 'weekly';
    }
    if (lower === 'daily' || lower === 'day' || raw.trim() === '每天') {
      return 'daily';
    }
    return lower;
  }

  static normalizeReminderTimes(times: ReminderTime[] | undefined): ReminderTime[] | undefined {
    if (times === undefined) {
      return undefined;
    }
    const out: ReminderTime[] = [];
    for (let i = 0; i < times.length; i++) {
      const t = times[i].time.trim();
      if (t.length === 0) {
        continue;
      }
      out.push(ReminderTime.make(t, times[i].dose, times[i].doseText));
    }
    return out.length > 0 ? out : undefined;
  }

  static resolvedLifecycleStatus(raw: string | undefined): string {
    if (raw === undefined || raw.trim().length === 0) {
      return 'active';
    }
    const lower = raw.trim().toLowerCase();
    return PRESCRIPTION_LIFECYCLE_STATUSES.indexOf(lower) >= 0 ? lower : 'active';
  }

  private static isPaymentStatusText(raw: string, lower: string): boolean {
    return lower === 'paid' || lower === 'unpaid' || lower === 'refunded' ||
      raw.indexOf('支付') >= 0 || raw.indexOf('退款') >= 0;
  }

  private static isPrescriptionTypeText(raw: string, lower: string): boolean {
    return raw === '普通' || raw === '门诊' || raw === '急诊' || raw === '医保' ||
      raw === '有效' || lower === 'outpatient' || lower === 'draft' || lower === 'dispensed';
  }

  private static mergeExtra(
    base: Map<string, string> | undefined,
    updates: Map<string, string>
  ): Map<string, string> | undefined {
    if (updates.size === 0) {
      return base;
    }
    const out = new Map<string, string>();
    if (base !== undefined) {
      base.forEach((value: string, key: string) => {
        out.set(key, value);
      });
    }
    updates.forEach((value: string, key: string) => {
      out.set(key, value);
    });
    return out;
  }

  private static clonePrescription(
    draft: PrescriptionRecognitionDraft
  ): PrescriptionRecognitionDraft {
    const out = new PrescriptionRecognitionDraft();
    out.medicalCase = draft.medicalCase;
    out.prescriberName = draft.prescriberName;
    out.institutionName = draft.institutionName;
    out.prescribedAt = draft.prescribedAt;
    out.diagnosis = draft.diagnosis;
    out.prescriptionNo = draft.prescriptionNo;
    out.status = draft.status;
    out.extra = undefined;
    if (draft.extra !== undefined) {
      out.extra = new Map<string, string>();
      draft.extra.forEach((value: string, key: string) => {
        out.extra!.set(key, value);
      });
    }
    out.medicationPlans = draft.medicationPlans !== undefined ?
      draft.medicationPlans.slice() : undefined;
    out.attachmentFileIds = draft.attachmentFileIds.slice();
    return out;
  }

  private static cloneMedicationPlan(
    draft: MedicationPlanRecognitionDraft
  ): MedicationPlanRecognitionDraft {
    const out = new MedicationPlanRecognitionDraft();
    out.medicineName = draft.medicineName;
    out.medicineType = draft.medicineType;
    out.totalQuantity = draft.totalQuantity;
    out.expireDate = draft.expireDate;
    out.medicineBox = draft.medicineBox;
    out.brandName = draft.brandName;
    out.dosageForm = draft.dosageForm;
    out.strength = draft.strength;
    out.doseUnit = draft.doseUnit;
    out.dosePerTime = draft.dosePerTime;
    out.doseValue = draft.doseValue;
    out.frequencyType = draft.frequencyType;
    out.everyNDays = draft.everyNDays;
    out.weeklyWeekdays = draft.weeklyWeekdays !== undefined ?
      draft.weeklyWeekdays.slice() : undefined;
    out.frequencyText = draft.frequencyText;
    out.startDate = draft.startDate;
    out.endDate = draft.endDate;
    out.instructions = draft.instructions;
    out.reminderEnabled = draft.reminderEnabled;
    out.reminderTimes = draft.reminderTimes !== undefined ?
      draft.reminderTimes.slice() : undefined;
    out.status = draft.status;
    out.sortOrder = draft.sortOrder;
    out.extra = undefined;
    if (draft.extra !== undefined) {
      out.extra = new Map<string, string>();
      draft.extra.forEach((value: string, key: string) => {
        out.extra!.set(key, value);
      });
    }
    out.attachmentFileIds = draft.attachmentFileIds.slice();
    return out;
  }
}

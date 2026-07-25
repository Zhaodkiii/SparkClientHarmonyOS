import { ReminderTime } from './MedicalDocumentRecognitionDrafts';
import {
  MEDICATION_FREQUENCY_TYPES,
  MEDICATION_PLAN_LIFECYCLE_STATUSES,
  PRESCRIPTION_LIFECYCLE_STATUSES,
  PrescriptionFieldNormalization
} from './PrescriptionFieldNormalization';

/**
 * 预提交校验规则原语。对齐 iOS MedicalPreSubmitValidationRules。
 */
export class MedicalPreSubmitValidationRules {
  static trimmedNonEmpty(value: string | undefined): string | undefined {
    if (value === undefined) {
      return undefined;
    }
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }

  static isBlank(value: string | undefined): boolean {
    return MedicalPreSubmitValidationRules.trimmedNonEmpty(value) === undefined;
  }

  /**
   * yyyy-MM-dd 或完整 ISO8601 视为完整日期；yyyy-MM、yyyy 不通过。
   * 空值视为通过（「若存在才校验」由调用方决定）。
   */
  static isCompleteDate(value: string | undefined): boolean {
    const raw = MedicalPreSubmitValidationRules.trimmedNonEmpty(value);
    if (raw === undefined) {
      return true;
    }
    if (/^\d{4}-\d{2}$/.test(raw) || /^\d{4}$/.test(raw)) {
      return false;
    }
    return MedicalPreSubmitValidationRules.parseComparableDateOnly(raw) !== undefined;
  }

  static requiresCompleteDateIfPresent(value: string | undefined): boolean {
    if (MedicalPreSubmitValidationRules.isBlank(value)) {
      return true;
    }
    return MedicalPreSubmitValidationRules.isCompleteDate(value);
  }

  static isNonNegativeNumber(value: string | undefined): boolean {
    const raw = MedicalPreSubmitValidationRules.trimmedNonEmpty(value);
    if (raw === undefined) {
      return true;
    }
    const n = Number(raw);
    return !(n !== n) && n >= 0;
  }

  static isValidDecimalString(value: string | undefined): boolean {
    const raw = MedicalPreSubmitValidationRules.trimmedNonEmpty(value);
    if (raw === undefined) {
      return true;
    }
    return /^-?\d+(\.\d+)?$/.test(raw);
  }

  static isValidIntegerString(value: string | undefined): boolean {
    const raw = MedicalPreSubmitValidationRules.trimmedNonEmpty(value);
    if (raw === undefined) {
      return true;
    }
    return /^-?\d+$/.test(raw);
  }

  static isValidExaminationCategory(value: string | undefined): boolean {
    const raw = MedicalPreSubmitValidationRules.trimmedNonEmpty(value);
    if (raw === undefined) {
      return true;
    }
    const normalized = raw.toLowerCase();
    const allowed: string[] = [
      'laboratory', 'lab', '实验室检查', '检验', '化验',
      'imaging', 'image', '影像', '影像学检查',
      'pathology', '病理', '病理检查'
    ];
    return allowed.indexOf(normalized) >= 0 || allowed.indexOf(raw) >= 0;
  }

  static isLaboratoryCategory(value: string | undefined): boolean {
    const raw = MedicalPreSubmitValidationRules.trimmedNonEmpty(value);
    if (raw === undefined) {
      return false;
    }
    const normalized = raw.toLowerCase();
    return normalized === 'laboratory' || normalized === 'lab' ||
      raw === '实验室检查' || raw === '检验' || raw === '化验';
  }

  static isValidFrequencyType(value: string | undefined): boolean {
    const raw = MedicalPreSubmitValidationRules.trimmedNonEmpty(value);
    if (raw === undefined) {
      return true;
    }
    const normalized = PrescriptionFieldNormalization.normalizeFrequencyType(raw);
    return MEDICATION_FREQUENCY_TYPES.indexOf(normalized) >= 0;
  }

  static isValidPrescriptionStatus(value: string | undefined): boolean {
    const raw = MedicalPreSubmitValidationRules.trimmedNonEmpty(value);
    if (raw === undefined) {
      return true;
    }
    return PRESCRIPTION_LIFECYCLE_STATUSES.indexOf(raw.toLowerCase()) >= 0;
  }

  static isValidMedicationPlanStatus(value: string | undefined): boolean {
    const raw = MedicalPreSubmitValidationRules.trimmedNonEmpty(value);
    if (raw === undefined) {
      return true;
    }
    return MEDICATION_PLAN_LIFECYCLE_STATUSES.indexOf(raw.toLowerCase()) >= 0;
  }

  static isValidEveryNDays(frequencyType: string | undefined, everyNDays: string | undefined): boolean {
    const normalized = PrescriptionFieldNormalization.normalizeFrequencyType(frequencyType);
    if (normalized !== 'every_n_days') {
      return true;
    }
    const raw = MedicalPreSubmitValidationRules.trimmedNonEmpty(everyNDays);
    if (raw === undefined) {
      return false;
    }
    const days = parseInt(raw, 10);
    return !isNaN(days) && days >= 1 && days <= 365;
  }

  static isValidWeeklyWeekdays(
    frequencyType: string | undefined,
    weekdays: number[] | undefined
  ): boolean {
    const normalized = PrescriptionFieldNormalization.normalizeFrequencyType(frequencyType);
    if (normalized !== 'weekly') {
      return true;
    }
    if (weekdays === undefined || weekdays.length === 0) {
      return false;
    }
    for (let i = 0; i < weekdays.length; i++) {
      if (weekdays[i] < 1 || weekdays[i] > 7) {
        return false;
      }
    }
    return true;
  }

  static isEndDateNotBeforeStart(startDate: string | undefined, endDate: string | undefined): boolean {
    const start = MedicalPreSubmitValidationRules.parseComparableDateOnly(startDate);
    const end = MedicalPreSubmitValidationRules.parseComparableDateOnly(endDate);
    if (start === undefined || end === undefined) {
      return true;
    }
    return end >= start;
  }

  static isValidReminderTimes(times: ReminderTime[] | undefined): boolean {
    if (times === undefined) {
      return true;
    }
    for (let i = 0; i < times.length; i++) {
      const t = times[i].time.trim();
      if (!/^\d{2}:\d{2}$/.test(t)) {
        return false;
      }
    }
    return true;
  }

  static completeDateMessage(): string {
    return '日期不完整，请填写完整的年-月-日';
  }

  /** 返回可比较的 yyyy-MM-dd；无法解析则 undefined。 */
  static parseComparableDateOnly(value: string | undefined): string | undefined {
    const raw = MedicalPreSubmitValidationRules.trimmedNonEmpty(value);
    if (raw === undefined) {
      return undefined;
    }
    const match = raw.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (match !== null) {
      const y = parseInt(match[1], 10);
      const m = parseInt(match[2], 10);
      const d = parseInt(match[3], 10);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return `${match[1]}-${match[2]}-${match[3]}`;
      }
      return undefined;
    }
    // 宽松：yyyy/MM/dd
    const slash = raw.match(/^(\d{4})\/(\d{2})\/(\d{2})/);
    if (slash !== null) {
      return `${slash[1]}-${slash[2]}-${slash[3]}`;
    }
    return undefined;
  }
}

import {
  RemoteManagedFile,
  RemoteMedicationPlan,
  RemoteMedicationRecord
} from '../../../../../../Core/Networking/API/Medical/MedicalSyncAPI';

export const MEDICATION_PLAN_STATUS_AS_NEEDED: string = 'as_needed';

export enum MedicationDoseLogStatus {
  TAKEN = 'taken',
  SKIPPED = 'skipped'
}

export function medicationDoseLogStatusTitle(status: MedicationDoseLogStatus): string {
  if (status === MedicationDoseLogStatus.TAKEN) {
    return '已用药';
  }
  return '已跳过';
}

export class MedicationExecutionDateItem {
  date: Date;
  id: string;

  constructor(date: Date) {
    this.date = date;
    this.id = MedicationExecutionDateItem.idFor(date);
  }

  static idFor(date: Date): string {
    const d = new Date(date.getTime());
    return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
  }
}

export enum MedicationExecutionLogSheetSource {
  MEDICATION_PLANS = 'medicationPlans',
  MEDICINE_BOX = 'medicineBox'
}

export class MedicationExecutionLogSubmission {
  selections: Record<string, MedicationDoseLogStatus> = {};
  edits: Record<string, MedicationExecutionDoseEdit> = {};
  doses: MedicationExecutionDose[] = [];
}

export class MedicationExecutionDoseEdit {
  quantity: number = 1;
  doseUnit: string = '';
  scheduledAt: Date = new Date();

  plannedDose(): string {
    return MedicationExecutionDoseEditSupport.formattedDose(this.quantity, this.doseUnit);
  }

  static fromDose(dose: MedicationExecutionDose): MedicationExecutionDoseEdit {
    const edit = new MedicationExecutionDoseEdit();
    let source = dose.plannedDose;
    if (dose.record !== undefined) {
      const actual = dose.record.actualDose.trim();
      if (actual.length > 0) {
        source = actual;
      } else if (dose.record.plannedDose.trim().length > 0) {
        source = dose.record.plannedDose;
      }
    }
    const parsed = MedicationExecutionDoseEditSupport.parse(source, dose.dosageFormUnitToken());
    edit.quantity = parsed.quantity;
    edit.doseUnit = parsed.unit;
    edit.scheduledAt = new Date(dose.scheduledAt.getTime());
    return edit;
  }
}

export class MedicationDoseParseResult {
  quantity: number = 1;
  unit: string = '';
}

export class MedicationExecutionDoseEditSupport {
  static parse(source: string, fallbackUnit: string): MedicationDoseParseResult {
    const trimmed = source.trim();
    const match = trimmed.match(/^(\d+(?:\.\d+)?)\s*(.*)$/);
    const result = new MedicationDoseParseResult();
    if (match !== null && match[1] !== undefined) {
      result.quantity = Math.max(Number(match[1]), 0.5);
      const unitPart = match[2] !== undefined ? match[2].trim() : '';
      result.unit = unitPart.length > 0 ? unitPart : fallbackUnit;
      return result;
    }
    const asNumber = Number(trimmed);
    if (!Number.isNaN(asNumber)) {
      result.quantity = Math.max(asNumber, 0.5);
      result.unit = fallbackUnit;
      return result;
    }
    result.quantity = 1;
    result.unit = fallbackUnit;
    return result;
  }

  static formattedDose(quantity: number, unit: string): string {
    const quantityText = quantity % 1 === 0 ? `${quantity}` : quantity.toFixed(1);
    if (unit.length === 0) {
      return quantityText;
    }
    return `${quantityText}${unit}`;
  }

  static mergeTime(time: Date, onDay: Date): Date {
    const merged = new Date(onDay.getTime());
    merged.setHours(time.getHours(), time.getMinutes(), 0, 0);
    return merged;
  }
}

export class MedicationExecutionLogSheetContext {
  id: string = `${Date.now()}-${Math.random()}`;
  title: string = '';
  date: Date = new Date();
  doses: MedicationExecutionDose[] = [];
  source: MedicationExecutionLogSheetSource = MedicationExecutionLogSheetSource.MEDICATION_PLANS;

  initialSelections(): Record<string, MedicationDoseLogStatus> {
    const out: Record<string, MedicationDoseLogStatus> = {};
    for (let i = 0; i < this.doses.length; i++) {
      const dose = this.doses[i];
      if (dose.status === MedicationDoseLogStatus.TAKEN) {
        out[dose.id] = MedicationDoseLogStatus.TAKEN;
      } else if (dose.status === MedicationDoseLogStatus.SKIPPED) {
        out[dose.id] = MedicationDoseLogStatus.SKIPPED;
      }
    }
    return out;
  }
}

export class MedicationExecutionDose {
  id: string = '';
  plan: RemoteMedicationPlan = new RemoteMedicationPlan();
  scheduledAt: Date = new Date();
  plannedDose: string = '';
  doseSequence: number = 0;
  record?: RemoteMedicationRecord;
  imageAttachment?: RemoteManagedFile;

  get status(): string {
    if (this.record !== undefined) {
      return this.record.status;
    }
    return 'scheduled';
  }

  get isCompleted(): boolean {
    return this.status === MedicationDoseLogStatus.TAKEN
      || this.status === MedicationDoseLogStatus.SKIPPED;
  }

  displayName(): string {
    const name = this.plan.drugName.trim();
    return name.length > 0 ? name : '未命名药品';
  }

  specificationText(): string {
    const parts: string[] = ['药片'];
    if (this.plan.doseUnit.trim().length > 0) {
      parts.push(this.plan.doseUnit.trim());
    }
    return parts.join('，');
  }

  instructionText(edit?: MedicationExecutionDoseEdit): string {
    const scheduledAt = edit !== undefined ? edit.scheduledAt : this.scheduledAt;
    const hour = `${scheduledAt.getHours()}`.padStart(2, '0');
    const minute = `${scheduledAt.getMinutes()}`.padStart(2, '0');
    const time = `${hour}:${minute}`;
    const dose = edit !== undefined ? edit.plannedDose() : this.plannedDose;
    return `${time} 用药： ${dose}`;
  }

  dosageFormUnitToken(): string {
    const unit = this.plan.doseUnit.trim();
    return unit.length > 0 ? unit : '片';
  }
}

export class MedicationExecutionTimeGroup {
  timeText: string = '';
  doses: MedicationExecutionDose[] = [];
}

export class MedicationRecordCreatePayload {
  member: number = 0;
  plan: number = 0;
  scheduled_at: string = '';
  taken_at?: string;
  status: string = '';
  planned_dose: string = '';
  actual_dose: string = '';
  dose_sequence: number = 0;
  timezone: string = '';
  notes: string = '';
  extra: Record<string, string> = {};
}

export class MedicationRecordUpdatePayload {
  scheduled_at?: string;
  taken_at?: string;
  status: string = '';
  planned_dose?: string;
  actual_dose: string = '';
  notes: string = '';
  extra: Record<string, string> = {};
}

export function medicationTrimmedNonEmpty(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

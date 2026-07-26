import {
  RemoteManagedFile,
  RemoteMedicationPlan,
  RemoteMedicationRecord,
  RemoteMedicineBox
} from '../../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import {
  medicationTrimmedNonEmpty,
  MedicationExecutionDose,
  MedicationExecutionTimeGroup
} from './MedicationExecutionModels';
import {
  medicationIsSameDay,
  medicationParseDate,
  medicationStartOfDay
} from './MedicationExecutionDateUtils';

export class MedicationExecutionPlanner {
  static scheduledDoses(
    plans: RemoteMedicationPlan[],
    medicineBoxes: RemoteMedicineBox[],
    records: RemoteMedicationRecord[],
    onDay: Date,
    now: Date = new Date()
  ): MedicationExecutionDose[] {
    const medicineBoxesByID: Record<number, RemoteMedicineBox> = {};
    for (let i = 0; i < medicineBoxes.length; i++) {
      medicineBoxesByID[medicineBoxes[i].id] = medicineBoxes[i];
    }
    const dayRecords = MedicationExecutionPlanner.recordsForDay(records, onDay);
    const recordsBySlot: Record<string, RemoteMedicationRecord[]> = {};
    for (let i = 0; i < dayRecords.length; i++) {
      const record = dayRecords[i];
      const key = MedicationExecutionPlanner.slotKey(record.plan, new Date(record.scheduledAt));
      if (!recordsBySlot[key]) {
        recordsBySlot[key] = [];
      }
      recordsBySlot[key].push(record);
    }
    const plansByID: Record<number, RemoteMedicationPlan> = {};
    for (let i = 0; i < plans.length; i++) {
      plansByID[plans[i].id] = plans[i];
    }

    const doses: MedicationExecutionDose[] = [];
    const generatedKeys: Record<string, boolean> = {};

    for (let i = 0; i < plans.length; i++) {
      const plan = plans[i];
      if (!MedicationExecutionPlanner.isPlanActive(plan, onDay)) {
        continue;
      }
      for (let j = 0; j < plan.reminderTimes.length; j++) {
        const reminder = plan.reminderTimes[j];
        const scheduledAt: Date | undefined = MedicationExecutionPlanner.scheduledDate(onDay, reminder.time);
        if (scheduledAt === undefined) {
          continue;
        }
        const key = MedicationExecutionPlanner.slotKey(plan.id, scheduledAt);
        const slotRecords = recordsBySlot[key] ?? [];
        slotRecords.sort((a: RemoteMedicationRecord, b: RemoteMedicationRecord): number => {
          return b.updatedAt.localeCompare(a.updatedAt);
        });
        const latestRecord = slotRecords.length > 0 ? slotRecords[0] : undefined;
        const dose = new MedicationExecutionDose();
        dose.id = key;
        dose.plan = plan;
        dose.scheduledAt = scheduledAt;
        dose.plannedDose = medicationTrimmedNonEmpty(plan.dosePerTime) ?? plan.doseUnit;
        dose.doseSequence = j + 1;
        dose.record = latestRecord;
        dose.imageAttachment = MedicationExecutionPlanner.imageAttachment(plan, medicineBoxesByID);
        doses.push(dose);
        generatedKeys[key] = true;
      }
    }

    for (let i = 0; i < dayRecords.length; i++) {
      const record = dayRecords[i];
      const scheduledAt = new Date(record.scheduledAt);
      const key = MedicationExecutionPlanner.slotKey(record.plan, scheduledAt);
      if (generatedKeys[key]) {
        continue;
      }
      const plan = plansByID[record.plan];
      if (plan === undefined) {
        continue;
      }
      const dose = new MedicationExecutionDose();
      dose.id = key;
      dose.plan = plan;
      dose.scheduledAt = scheduledAt;
      dose.plannedDose = record.plannedDose;
      dose.doseSequence = record.doseSequence;
      dose.record = record;
      dose.imageAttachment = MedicationExecutionPlanner.imageAttachment(plan, medicineBoxesByID);
      doses.push(dose);
    }

    doses.sort((a: MedicationExecutionDose, b: MedicationExecutionDose): number => {
      if (a.scheduledAt.getTime() === b.scheduledAt.getTime()) {
        return a.displayName().localeCompare(b.displayName());
      }
      return a.scheduledAt.getTime() - b.scheduledAt.getTime();
    });
    return doses;
  }

  static asNeededDose(
    plan: RemoteMedicationPlan,
    medicineBoxesByID: Record<number, RemoteMedicineBox>,
    date: Date,
    sequence: number,
    now: Date = new Date()
  ): MedicationExecutionDose {
    const scheduledAt = MedicationExecutionPlanner.mergeCurrentTime(date, now);
    const dose = new MedicationExecutionDose();
    dose.id = `as-needed-${plan.id}-${scheduledAt.getTime()}`;
    dose.plan = plan;
    dose.scheduledAt = scheduledAt;
    dose.plannedDose = medicationTrimmedNonEmpty(plan.dosePerTime) ?? plan.doseUnit;
    dose.doseSequence = sequence;
    dose.imageAttachment = MedicationExecutionPlanner.imageAttachment(plan, medicineBoxesByID);
    return dose;
  }

  static groupByTime(doses: MedicationExecutionDose[]): MedicationExecutionTimeGroup[] {
    const grouped: Record<string, MedicationExecutionDose[]> = {};
    for (let i = 0; i < doses.length; i++) {
      const key = MedicationExecutionPlanner.timeText(doses[i].scheduledAt);
      if (!grouped[key]) {
        grouped[key] = [];
      }
      grouped[key].push(doses[i]);
    }
    const keys = Object.keys(grouped).sort();
    const out: MedicationExecutionTimeGroup[] = [];
    for (let i = 0; i < keys.length; i++) {
      const group = new MedicationExecutionTimeGroup();
      group.timeText = keys[i];
      group.doses = grouped[keys[i]];
      out.push(group);
    }
    return out;
  }

  static progress(
    plans: RemoteMedicationPlan[],
    medicineBoxes: RemoteMedicineBox[],
    records: RemoteMedicationRecord[],
    onDay: Date
  ): number {
    const doses = MedicationExecutionPlanner.scheduledDoses(plans, medicineBoxes, records, onDay);
    if (doses.length === 0) {
      return 0;
    }
    let completed = 0;
    for (let i = 0; i < doses.length; i++) {
      if (doses[i].isCompleted) {
        completed += 1;
      }
    }
    return completed / doses.length;
  }

  static isPlanActive(plan: RemoteMedicationPlan, onDay: Date): boolean {
    if (plan.status !== 'active') {
      return false;
    }
    const dayStart = medicationStartOfDay(onDay);
    const planStart = medicationParseDate(plan.startDate);
    if (planStart !== undefined && medicationStartOfDay(planStart).getTime() > dayStart.getTime()) {
      return false;
    }
    const endDate = medicationParseDate(plan.endDate);
    if (endDate !== undefined && medicationStartOfDay(endDate).getTime() < dayStart.getTime()) {
      return false;
    }
    if (plan.frequencyType === 'every_n_days') {
      const interval = Math.max(plan.everyNDays ?? 1, 1);
      if (planStart === undefined) {
        return true;
      }
      const diffDays = Math.floor(
        (dayStart.getTime() - medicationStartOfDay(planStart).getTime()) / 86_400_000
      );
      return diffDays >= 0 && diffDays % interval === 0;
    }
    if (plan.frequencyType === 'weekly') {
      const targetWeekday = MedicationExecutionPlanner.chineseWeekdayNumber(onDay);
      return plan.weeklyWeekdays.indexOf(targetWeekday) >= 0;
    }
    return true;
  }

  static timeText(date: Date): string {
    const hour = `${date.getHours()}`.padStart(2, '0');
    const minute = `${date.getMinutes()}`.padStart(2, '0');
    return `${hour}:${minute}`;
  }

  private static recordsForDay(
    records: RemoteMedicationRecord[],
    day: Date
  ): RemoteMedicationRecord[] {
    const out: RemoteMedicationRecord[] = [];
    for (let i = 0; i < records.length; i++) {
      if (medicationIsSameDay(new Date(records[i].scheduledAt), day)) {
        out.push(records[i]);
      }
    }
    return out;
  }

  private static scheduledDate(onDay: Date, timeText: string): Date | undefined {
    const parts = timeText.split(':');
    if (parts.length !== 2) {
      return undefined;
    }
    const hour = Number(parts[0]);
    const minute = Number(parts[1]);
    if (Number.isNaN(hour) || Number.isNaN(minute) || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return undefined;
    }
    const date = medicationStartOfDay(onDay);
    date.setHours(hour, minute, 0, 0);
    return date;
  }

  private static slotKey(planID: number, scheduledAt: Date): string {
    return `${planID}-${scheduledAt.getFullYear()}-${scheduledAt.getMonth() + 1}-`
      + `${scheduledAt.getDate()}-${scheduledAt.getHours()}-${scheduledAt.getMinutes()}`;
  }

  private static chineseWeekdayNumber(date: Date): number {
    const raw = date.getDay();
    return raw === 0 ? 7 : raw;
  }

  private static imageAttachment(
    plan: RemoteMedicationPlan,
    medicineBoxesByID: Record<number, RemoteMedicineBox>
  ): RemoteManagedFile | undefined {
    if (plan.attachments.length > 0) {
      return plan.attachments[0];
    }
    if (plan.medicineBox !== undefined) {
      const box = medicineBoxesByID[plan.medicineBox];
      if (box !== undefined && box.attachments.length > 0) {
        return box.attachments[0];
      }
    }
    return undefined;
  }

  private static mergeCurrentTime(onDay: Date, now: Date): Date {
    const merged = medicationStartOfDay(onDay);
    merged.setHours(now.getHours(), now.getMinutes(), 0, 0);
    return merged;
  }
}

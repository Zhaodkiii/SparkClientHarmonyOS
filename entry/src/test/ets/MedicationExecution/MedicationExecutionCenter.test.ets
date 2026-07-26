import { describe, it, expect } from '@ohos/hypium';
import { RemoteMedicationPlan, RemoteMedicationRecord, RemoteReminderTime } from '../../../main/ets/Projects/Core/Networking/API/Medical/MedicalSyncAPI';
import { MedicationExecutionRecordCache, MedicationExecutionRecordWindow } from '../../../main/ets/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionRecordCache';
import { MedicationExecutionPlanner } from '../../../main/ets/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionPlanner';
import { medicationStartOfDay } from '../../../main/ets/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionDateUtils';
import { MedicationDoseLogStatus } from '../../../main/ets/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionModels';

function makePlan(id: number, reminderTime: string): RemoteMedicationPlan {
  const plan = new RemoteMedicationPlan();
  plan.id = id;
  plan.member = 1;
  plan.drugName = `药品${id}`;
  plan.status = 'active';
  plan.frequencyType = 'daily';
  plan.startDate = '2020-01-01T00:00:00.000Z';
  plan.dosePerTime = '1片';
  plan.doseUnit = '片';
  const reminder = new RemoteReminderTime();
  reminder.time = reminderTime;
  plan.reminderTimes = [reminder];
  return plan;
}

function makeRecord(planID: number, scheduledAt: Date, status: string): RemoteMedicationRecord {
  const record = new RemoteMedicationRecord();
  record.id = planID * 1000 + scheduledAt.getHours();
  record.member = 1;
  record.plan = planID;
  record.status = status;
  record.scheduledAt = scheduledAt.toISOString();
  record.plannedDose = '1片';
  record.updatedAt = scheduledAt.toISOString();
  return record;
}

export default function MedicationExecutionCenterTest(): void {
  describe('MedicationExecutionCenter', () => {
    it('record_window_has_nine_days', 0, () => {
      const day = medicationStartOfDay(new Date('2026-07-26T12:00:00.000Z'));
      const window = MedicationExecutionRecordWindow.centeredAt(day);
      expect(window.dayStarts().length).assertEqual(9);
    });

    it('planner_progress_uses_day_records', 0, () => {
      const day = medicationStartOfDay(new Date('2026-07-26T08:00:00.000Z'));
      const plan = makePlan(1, '08:00');
      const scheduledAt = new Date(day.getTime());
      scheduledAt.setHours(8, 0, 0, 0);
      const record = makeRecord(1, scheduledAt, MedicationDoseLogStatus.TAKEN);
      const progress = MedicationExecutionPlanner.progress([plan], [], [record], day);
      expect(progress).assertEqual(1);
    });

    it('record_cache_groups_by_day', 0, () => {
      const day = medicationStartOfDay(new Date('2026-07-26T08:00:00.000Z'));
      const scheduledAt = new Date(day.getTime());
      scheduledAt.setHours(8, 0, 0, 0);
      const record = makeRecord(1, scheduledAt, MedicationDoseLogStatus.TAKEN);
      const grouped = MedicationExecutionRecordCache.groupRecordsByDay([record]);
      const keys = Object.keys(grouped);
      expect(keys.length).assertEqual(1);
      expect(grouped[keys[0]].length).assertEqual(1);
    });
  });
}

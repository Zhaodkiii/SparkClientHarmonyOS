import { MedicationRecordScheduledRange } from '../../../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import { RemoteMedicationRecord } from '../../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { MedicationExecutionDateItem } from './MedicationExecutionModels';
import { medicationAddDays, medicationIsSameDay, medicationStartOfDay } from './MedicationExecutionDateUtils';

/** 用药记录加载窗口：以选中日为中心，前后各 4 天，共 9 天。 */
export class MedicationExecutionRecordWindow {
  static readonly DAY_RADIUS: number = 4;
  static readonly DAY_COUNT: number = MedicationExecutionRecordWindow.DAY_RADIUS * 2 + 1;

  start: Date;
  endExclusive: Date;

  constructor(start: Date, endExclusive: Date) {
    this.start = start;
    this.endExclusive = endExclusive;
  }

  static centeredAt(day: Date): MedicationExecutionRecordWindow {
    const dayStart = medicationStartOfDay(day);
    const start = medicationAddDays(dayStart, -MedicationExecutionRecordWindow.DAY_RADIUS);
    const endExclusive = medicationAddDays(dayStart, MedicationExecutionRecordWindow.DAY_RADIUS + 1);
    return new MedicationExecutionRecordWindow(start, endExclusive);
  }

  contains(day: Date): boolean {
    const dayStart = medicationStartOfDay(day);
    return dayStart.getTime() >= this.start.getTime()
      && dayStart.getTime() < this.endExclusive.getTime();
  }

  requestID(): string {
    return `${this.start.getTime()}-${this.endExclusive.getTime()}`;
  }

  dayStarts(): Date[] {
    const days: Date[] = [];
    let current = new Date(this.start.getTime());
    while (current.getTime() < this.endExclusive.getTime()) {
      days.push(new Date(current.getTime()));
      current = medicationAddDays(current, 1);
    }
    return days;
  }

  scheduledQueryRange(): MedicationRecordScheduledRange {
    return new MedicationRecordScheduledRange(this.start, this.endExclusive);
  }
}

export class MedicationExecutionWindowLoadRequest {
  window: MedicationExecutionRecordWindow;
  requestID: string;
  recordsByDayID: Record<string, RemoteMedicationRecord[]>;

  constructor(
    window: MedicationExecutionRecordWindow,
    requestID: string,
    recordsByDayID: Record<string, RemoteMedicationRecord[]>
  ) {
    this.window = window;
    this.requestID = requestID;
    this.recordsByDayID = recordsByDayID;
  }
}

export class MedicationExecutionWindowLoadResult {
  loadedWindow: MedicationExecutionRecordWindow;
  recordsByDayID: Record<string, RemoteMedicationRecord[]>;

  constructor(
    loadedWindow: MedicationExecutionRecordWindow,
    recordsByDayID: Record<string, RemoteMedicationRecord[]>
  ) {
    this.loadedWindow = loadedWindow;
    this.recordsByDayID = recordsByDayID;
  }
}

export class MedicationExecutionRecordCache {
  static needsWindowFetch(
    day: Date,
    loadedWindow?: MedicationExecutionRecordWindow
  ): boolean {
    if (loadedWindow === undefined) {
      return true;
    }
    return !loadedWindow.contains(day);
  }

  static recordsFor(
    day: Date,
    cache: Record<string, RemoteMedicationRecord[]>
  ): RemoteMedicationRecord[] {
    const dayID = MedicationExecutionDateItem.idFor(day);
    return cache[dayID] ?? [];
  }

  static groupRecordsByDay(
    records: RemoteMedicationRecord[]
  ): Record<string, RemoteMedicationRecord[]> {
    const grouped: Record<string, RemoteMedicationRecord[]> = {};
    for (let i = 0; i < records.length; i++) {
      const record = records[i];
      const scheduled = new Date(record.scheduledAt);
      const dayID = MedicationExecutionDateItem.idFor(scheduled);
      if (!grouped[dayID]) {
        grouped[dayID] = [];
      }
      grouped[dayID].push(record);
    }
    return grouped;
  }

  static applyWindowRecords(
    records: RemoteMedicationRecord[],
    window: MedicationExecutionRecordWindow,
    cache: Record<string, RemoteMedicationRecord[]>
  ): Record<string, RemoteMedicationRecord[]> {
    const next: Record<string, RemoteMedicationRecord[]> = {};
    const keys = Object.keys(cache);
    for (let i = 0; i < keys.length; i++) {
      next[keys[i]] = cache[keys[i]].slice();
    }
    const grouped = MedicationExecutionRecordCache.groupRecordsByDay(records);
    const days = window.dayStarts();
    for (let i = 0; i < days.length; i++) {
      const dayID = MedicationExecutionDateItem.idFor(days[i]);
      next[dayID] = grouped[dayID] ?? [];
    }
    return next;
  }

  static seedInitialRecords(
    records: RemoteMedicationRecord[],
    cache: Record<string, RemoteMedicationRecord[]>
  ): Record<string, RemoteMedicationRecord[]> {
    const next: Record<string, RemoteMedicationRecord[]> = {};
    const keys = Object.keys(cache);
    for (let i = 0; i < keys.length; i++) {
      next[keys[i]] = cache[keys[i]].slice();
    }
    for (let i = 0; i < records.length; i++) {
      MedicationExecutionRecordCache.upsertRecord(records[i], next);
    }
    return next;
  }

  static upsertRecord(
    record: RemoteMedicationRecord,
    cache: Record<string, RemoteMedicationRecord[]>
  ): Record<string, RemoteMedicationRecord[]> {
    const next: Record<string, RemoteMedicationRecord[]> = {};
    const keys = Object.keys(cache);
    for (let i = 0; i < keys.length; i++) {
      next[keys[i]] = cache[keys[i]].slice();
    }
    const scheduled = new Date(record.scheduledAt);
    const dayID = MedicationExecutionDateItem.idFor(scheduled);
    const dayRecords = (next[dayID] ?? []).slice();
    let replaced = false;
    for (let i = 0; i < dayRecords.length; i++) {
      if (dayRecords[i].id === record.id) {
        dayRecords[i] = record;
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      dayRecords.push(record);
    }
    next[dayID] = dayRecords;
    return next;
  }

  static pruneDistantEntries(
    cache: Record<string, RemoteMedicationRecord[]>,
    center: Date,
    keepRadius: number = 7
  ): Record<string, RemoteMedicationRecord[]> {
    const centerStart = medicationStartOfDay(center);
    const keepStart = medicationAddDays(centerStart, -keepRadius);
    const keepEndExclusive = medicationAddDays(centerStart, keepRadius + 1);
    const next: Record<string, RemoteMedicationRecord[]> = {};
    const keys = Object.keys(cache);
    for (let i = 0; i < keys.length; i++) {
      const dayID = keys[i];
      const records = cache[dayID];
      if (records.length === 0) {
        continue;
      }
      const dayStart = medicationStartOfDay(new Date(records[0].scheduledAt));
      if (dayStart.getTime() >= keepStart.getTime()
        && dayStart.getTime() < keepEndExclusive.getTime()) {
        next[dayID] = records.slice();
      }
    }
    return next;
  }

  static prepareWindowLoad(
    day: Date,
    loadedWindow: MedicationExecutionRecordWindow | undefined,
    loadingWindowID: string | undefined,
    recordsByDayID: Record<string, RemoteMedicationRecord[]>,
    initialRecords: RemoteMedicationRecord[],
    preferSeedInitialRecords: boolean,
    force: boolean = false
  ): MedicationExecutionWindowLoadRequest | undefined {
    if (!force && !MedicationExecutionRecordCache.needsWindowFetch(day, loadedWindow)) {
      return undefined;
    }
    const window = MedicationExecutionRecordWindow.centeredAt(day);
    const requestID = window.requestID();
    if (loadingWindowID === requestID) {
      return undefined;
    }
    let cache = recordsByDayID;
    if (preferSeedInitialRecords && initialRecords.length > 0) {
      cache = MedicationExecutionRecordCache.seedInitialRecords(initialRecords, cache);
    }
    return new MedicationExecutionWindowLoadRequest(window, requestID, cache);
  }

  static finishWindowLoad(
    fetchedRecords: RemoteMedicationRecord[],
    request: MedicationExecutionWindowLoadRequest,
    centeredAt: Date
  ): MedicationExecutionWindowLoadResult {
    let cache = MedicationExecutionRecordCache.applyWindowRecords(
      fetchedRecords,
      request.window,
      request.recordsByDayID
    );
    cache = MedicationExecutionRecordCache.pruneDistantEntries(cache, centeredAt);
    return new MedicationExecutionWindowLoadResult(request.window, cache);
  }

  static isDateInLoadedWindow(day: Date, loadedWindow?: MedicationExecutionRecordWindow): boolean {
    return loadedWindow?.contains(day) ?? false;
  }

  static isToday(day: Date): boolean {
    return medicationIsSameDay(day, new Date());
  }
}

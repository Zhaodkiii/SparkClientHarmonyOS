import { AppContainer } from '../../../../../../../App/AppContainer';
import { FileTransferService } from '../../../../../../../Core/FileStorage/FileTransferService';
import { SparkMedicalQueryAPI } from '../../../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import { SparkMedicalWorkflowAPI } from '../../../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import {
  RemoteMedicationPlan,
  RemoteMedicationRecord,
  RemoteMedicineBox
} from '../../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { NotificationClient } from '../../../../../../Core/Notification/Application/NotificationClient';
import { Logger } from '../../../../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../../../../Foundation/Logging/LogModule';
import { HomeMedicalRouteSupport } from '../../../HomeMedicalRouteSupport';
import { HomeViewModel } from '../../../HomeViewModel';
import { MedicationExecutionDateStrip } from './MedicationExecutionDateStrip';
import {
  medicationEncodeISO8601,
  medicationIsSameDay,
  medicationStartOfDay
} from './MedicationExecutionDateUtils';
import { MedicationExecutionLogSheet } from './MedicationExecutionLogSheet';
import {
  MedicationExecutionDose,
  MedicationExecutionLogSheetContext,
  MedicationExecutionLogSubmission,
  MedicationExecutionTimeGroup,
  MedicationRecordCreatePayload,
  MedicationRecordUpdatePayload,
  MedicationDoseLogStatus,
  MedicationExecutionDoseEdit
} from './MedicationExecutionModels';
import { MedicationExecutionPlanner } from './MedicationExecutionPlanner';
import {
  MedicationExecutionAllDoneCard,
  MedicationExecutionAsNeededCard,
  MedicationExecutionCompletedGroup,
  MedicationExecutionPendingCard
} from './MedicationExecutionRecordCards';
import {
  MedicationExecutionRecordCache,
  MedicationExecutionRecordWindow
} from './MedicationExecutionRecordCache';
import { MedicationExecutionSupport } from './MedicationExecutionSupport';
import {
  MED_EXEC_PAGE_BG,
  MED_EXEC_PAGE_HORIZONTAL,
  MED_EXEC_PRIMARY_TEXT,
  MED_EXEC_SECTION_SPACING,
  MED_EXEC_SECTION_TITLE_SIZE,
  MED_EXEC_DATE_TITLE_SIZE,
  MedicationExecutionNavBar
} from './MedicationExecutionTheme';

@Component
export struct MedicationExecutionCenterPage {
  homeVm?: HomeViewModel;
  onBack?: () => void;
  onOpenPersonalCabinet?: () => void;

  @State private selectedDate: number = Date.now();
  @State private recordsByDayID: Record<string, RemoteMedicationRecord[]> = {};
  @State private loadedWindow?: MedicationExecutionRecordWindow = undefined;
  @State private loadingWindowID: string = '';
  @State private isLoading: boolean = false;
  @State private isSaving: boolean = false;
  @State private refreshing: boolean = false;
  @State private showLogSheet: boolean = false;
  @State private logSheetContext: MedicationExecutionLogSheetContext = new MedicationExecutionLogSheetContext();
  @State private medicationPlans: RemoteMedicationPlan[] = [];
  @State private medicineBoxes: RemoteMedicineBox[] = [];
  @State private initialRecords: RemoteMedicationRecord[] = [];
  @State private pageTick: number = 0;

  private medicalQuery?: SparkMedicalQueryAPI;
  private workflowAPI?: SparkMedicalWorkflowAPI;
  private notification?: NotificationClient;
  private fileTransferService?: FileTransferService;
  private activeRecordLoadToken: string = '';
  private legacyDateLoadTimer: number = -1;
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const container = AppContainer.shared();
    this.medicalQuery = container?.backend.medicalQuery;
    this.workflowAPI = container?.backend.medicalWorkflow;
    this.notification = container?.notificationClient;
    this.fileTransferService = container?.fileTransferService;
    this.hydrateFromCache();
    this.loadRecordWindow(this.selectedDayStart(), true, false);
    setTimeout(() => {
      this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    }, 0);
  }

  private memberID(): number {
    const data = this.homeVm?.completeData();
    if (data && data.memberId > 0) {
      return data.memberId;
    }
    return this.homeVm?.selectedMemberID ?? 0;
  }

  private hydrateFromCache(): void {
    const data = this.homeVm?.completeData();
    this.medicationPlans = (data?.medicationPlans ?? []).slice();
    this.medicineBoxes = (data?.medicineBoxes ?? []).slice();
    this.initialRecords = (data?.todayMedicationRecords ?? []).slice();
    this.pageTick += 1;
  }

  private selectedDayStart(): Date {
    return medicationStartOfDay(new Date(this.selectedDate));
  }

  private selectedDayRecords(): RemoteMedicationRecord[] {
    return MedicationExecutionRecordCache.recordsFor(this.selectedDayStart(), this.recordsByDayID);
  }

  private scheduledDoses(): MedicationExecutionDose[] {
    return MedicationExecutionPlanner.scheduledDoses(
      this.medicationPlans,
      this.medicineBoxes,
      this.selectedDayRecords(),
      this.selectedDayStart()
    );
  }

  private pendingDoses(): MedicationExecutionDose[] {
    return this.scheduledDoses().filter((dose: MedicationExecutionDose): boolean => !dose.isCompleted);
  }

  private completedDoses(): MedicationExecutionDose[] {
    return this.scheduledDoses().filter((dose: MedicationExecutionDose): boolean => dose.isCompleted);
  }

  private asNeededDoses(): MedicationExecutionDose[] {
    const sorted = this.medicationPlans.slice().sort((a: RemoteMedicationPlan, b: RemoteMedicationPlan): number => {
      return a.drugName.localeCompare(b.drugName);
    });
    const boxesByID: Record<number, RemoteMedicineBox> = {};
    for (let i = 0; i < this.medicineBoxes.length; i++) {
      boxesByID[this.medicineBoxes[i].id] = this.medicineBoxes[i];
    }
    const out: MedicationExecutionDose[] = [];
    for (let i = 0; i < sorted.length; i++) {
      out.push(MedicationExecutionPlanner.asNeededDose(
        sorted[i],
        boxesByID,
        this.selectedDayStart(),
        i + 1
      ));
    }
    return out;
  }

  private showsAsNeededCard(): boolean {
    return this.memberID() > 0;
  }

  private loadedWindowStart(): number {
    return this.loadedWindow?.start.getTime() ?? 0;
  }

  private loadedWindowEndExclusive(): number {
    return this.loadedWindow?.endExclusive.getTime() ?? 0;
  }

  private commitLegacyDateStripDate(dateMs: number): void {
    if (this.legacyDateLoadTimer >= 0) {
      clearTimeout(this.legacyDateLoadTimer);
    }
    this.selectedDate = dateMs;
    this.legacyDateLoadTimer = setTimeout(() => {
      this.loadRecordWindow(medicationStartOfDay(new Date(dateMs)), false, false);
      this.legacyDateLoadTimer = -1;
    }, 80);
  }

  private async loadRecordWindow(
    day: Date,
    preferInitialRecords: boolean,
    force: boolean
  ): Promise<void> {
    const query = this.medicalQuery;
    const memberID = this.memberID();
    if (!query || memberID <= 0) {
      return;
    }

    const loadToken = `${Date.now()}-${Math.random()}`;
    this.activeRecordLoadToken = loadToken;

    const shouldShowBlockingLoader = !this.refreshing
      && MedicationExecutionRecordCache.needsWindowFetch(day, this.loadedWindow)
      && MedicationExecutionRecordCache.recordsFor(day, this.recordsByDayID).length === 0;
    if (shouldShowBlockingLoader) {
      this.isLoading = true;
    }

    const request = MedicationExecutionRecordCache.prepareWindowLoad(
      day,
      this.loadedWindow,
      this.loadingWindowID.length > 0 ? this.loadingWindowID : undefined,
      this.recordsByDayID,
      this.initialRecords,
      preferInitialRecords && medicationIsSameDay(day, new Date()),
      force
    );

    if (!request) {
      if (this.activeRecordLoadToken === loadToken) {
        this.isLoading = false;
      }
      return;
    }

    this.loadingWindowID = request.requestID;
    if (request.recordsByDayID !== this.recordsByDayID) {
      this.recordsByDayID = request.recordsByDayID;
    }

    try {
      const fetched = await query.listMedicationRecords(
        memberID,
        undefined,
        undefined,
        request.window.scheduledQueryRange()
      );
      if (this.activeRecordLoadToken !== loadToken) {
        return;
      }
      if (this.loadingWindowID !== request.requestID) {
        return;
      }
      const result = MedicationExecutionRecordCache.finishWindowLoad(fetched, request, day);
      this.loadedWindow = result.loadedWindow;
      this.recordsByDayID = result.recordsByDayID;
      this.pageTick += 1;
    } catch (e) {
      if (this.activeRecordLoadToken !== loadToken) {
        return;
      }
      const message = `${e}`;
      this.notification?.error(message, '加载服药记录失败', 'medical.medication_execution.load');
      const fields = new LogFields();
      fields.detail = message;
      Logger.warn('medication_execution.load_failed', LogModule.HOME, fields);
    } finally {
      if (this.loadingWindowID === request.requestID) {
        this.loadingWindowID = '';
      }
      if (this.activeRecordLoadToken === loadToken) {
        this.isLoading = false;
      }
    }
  }

  /** 下拉刷新：对齐 iOS `.refreshable`，强制重载当前窗口记录并同步计划/药箱。 */
  private async refreshCurrent(): Promise<void> {
    const query = this.medicalQuery;
    const memberID = this.memberID();
    if (!query || memberID <= 0) {
      this.refreshing = false;
      return;
    }

    this.refreshing = true;
    try {
      const plans = await query.listMedicationPlans(memberID);
      const boxes = await query.listMedicineBoxes(memberID);
      this.medicationPlans = plans;
      this.medicineBoxes = boxes;
      if (this.homeVm) {
        HomeMedicalRouteSupport.patchMedicationPlans(this.homeVm, plans);
        HomeMedicalRouteSupport.patchMedicineBoxes(this.homeVm, boxes);
      }
      await this.loadRecordWindow(this.selectedDayStart(), false, true);
      this.pageTick += 1;
      const fields = new LogFields();
      fields.detail = `member=${memberID}`;
      Logger.info('medication_execution.refresh_done', LogModule.HOME, fields);
    } catch (e) {
      const message = `${e}`;
      this.notification?.error(message, '刷新失败', 'medical.medication_execution.refresh');
      const fields = new LogFields();
      fields.detail = message;
      Logger.warn('medication_execution.refresh_failed', LogModule.HOME, fields);
    } finally {
      this.refreshing = false;
    }
  }

  private openLogSheet(context: MedicationExecutionLogSheetContext): void {
    this.logSheetContext = context;
    this.showLogSheet = true;
  }

  private async saveSelections(submission: MedicationExecutionLogSubmission): Promise<void> {
    const workflow = this.workflowAPI;
    if (!workflow || this.isSaving) {
      return;
    }
    const selected = submission.doses.filter((dose: MedicationExecutionDose): boolean => {
      return submission.selections[dose.id] !== undefined;
    });
    if (selected.length === 0) {
      this.showLogSheet = false;
      return;
    }

    this.isSaving = true;
    try {
      for (let i = 0; i < selected.length; i++) {
        const dose = selected[i];
        const status = submission.selections[dose.id];
        if (status === undefined) {
          continue;
        }
        const edit = submission.edits[dose.id];
        const merged = this.mergedDose(dose, edit);
        if (this.shouldSkipSave(dose, merged, status)) {
          continue;
        }
        const saved = await this.saveDose(merged, status, workflow);
        this.recordsByDayID = MedicationExecutionRecordCache.upsertRecord(saved, this.recordsByDayID);
      }
      this.showLogSheet = false;
      this.pageTick += 1;
      this.patchTodayRecordsIfNeeded();
    } catch (e) {
      const message = `${e}`;
      this.notification?.error(message, '记录用药失败', 'medical.medication_execution.save');
      const fields = new LogFields();
      fields.detail = message;
      Logger.warn('medication_execution.save_failed', LogModule.HOME, fields);
    } finally {
      this.isSaving = false;
    }
  }

  private mergedDose(
    dose: MedicationExecutionDose,
    edit?: MedicationExecutionDoseEdit
  ): MedicationExecutionDose {
    if (!edit) {
      return dose;
    }
    const merged = new MedicationExecutionDose();
    merged.id = dose.id;
    merged.plan = dose.plan;
    merged.scheduledAt = new Date(edit.scheduledAt.getTime());
    merged.plannedDose = edit.plannedDose();
    merged.doseSequence = dose.doseSequence;
    merged.record = dose.record;
    merged.imageAttachment = dose.imageAttachment;
    return merged;
  }

  private shouldSkipSave(
    original: MedicationExecutionDose,
    merged: MedicationExecutionDose,
    status: MedicationDoseLogStatus
  ): boolean {
    const record = original.record;
    if (!record) {
      return false;
    }
    if (record.status !== status) {
      return false;
    }
    if (record.plannedDose !== merged.plannedDose) {
      return false;
    }
    const recordDate = new Date(record.scheduledAt);
    return recordDate.getHours() === merged.scheduledAt.getHours()
      && recordDate.getMinutes() === merged.scheduledAt.getMinutes();
  }

  private async saveDose(
    dose: MedicationExecutionDose,
    status: MedicationDoseLogStatus,
    workflow: SparkMedicalWorkflowAPI
  ): Promise<RemoteMedicationRecord> {
    const takenAt = status === MedicationDoseLogStatus.TAKEN ? medicationEncodeISO8601(new Date()) : undefined;
    const actualDose = status === MedicationDoseLogStatus.TAKEN ? dose.plannedDose : '';
    if (dose.record) {
      const payload = new MedicationRecordUpdatePayload();
      payload.scheduled_at = medicationEncodeISO8601(dose.scheduledAt);
      payload.taken_at = takenAt;
      payload.status = status;
      payload.planned_dose = dose.plannedDose;
      payload.actual_dose = actualDose;
      payload.notes = dose.record.notes;
      payload.extra = dose.record.extra;
      return workflow.updateMedicationRecord(dose.record.id, payload as Object);
    }
    const payload = new MedicationRecordCreatePayload();
    payload.member = dose.plan.member;
    payload.plan = dose.plan.id;
    payload.scheduled_at = medicationEncodeISO8601(dose.scheduledAt);
    payload.taken_at = takenAt;
    payload.status = status;
    payload.planned_dose = dose.plannedDose;
    payload.actual_dose = actualDose;
    payload.dose_sequence = dose.doseSequence;
    payload.timezone = 'Asia/Shanghai';
    payload.notes = '';
    payload.extra = {};
    return workflow.createMedicationRecord(payload as Object);
  }

  private patchTodayRecordsIfNeeded(): void {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    const todayRecords = MedicationExecutionRecordCache.recordsFor(new Date(), this.recordsByDayID);
    HomeMedicalRouteSupport.patchTodayMedicationRecords(homeVm, todayRecords);
  }

  @Builder
  private logSheetBuilder() {
    MedicationExecutionLogSheet({
      context: this.logSheetContext,
      isSaving: this.isSaving,
      fileTransferService: this.fileTransferService,
      onCancel: () => {
        this.showLogSheet = false;
      },
      onDone: (submission: MedicationExecutionLogSubmission) => {
        this.saveSelections(submission);
      }
    })
  }

  @Builder
  private dateNavigationSection() {
    Column({ space: 12 }) {
      Text(MedicationExecutionSupport.longDateTitle(this.selectedDayStart()))
        .fontSize(MED_EXEC_DATE_TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(MED_EXEC_PRIMARY_TEXT)
        .width('100%')
        .textAlign(TextAlign.Center)
        .lineHeight(41)
        .padding({ left: MED_EXEC_PAGE_HORIZONTAL, right: MED_EXEC_PAGE_HORIZONTAL })

      MedicationExecutionDateStrip({
        selectedDate: this.selectedDate,
        recordsByDayID: this.recordsByDayID,
        loadedWindowStart: this.loadedWindowStart(),
        loadedWindowEndExclusive: this.loadedWindowEndExclusive(),
        medicationPlans: this.medicationPlans,
        medicineBoxes: this.medicineBoxes,
        onCommit: (date: number) => {
          this.commitLegacyDateStripDate(date);
        },
        onSelectedDateChange: (date: number) => {
          this.selectedDate = date;
        }
      })
    }
    .width('100%')
    .padding({ top: 20, bottom: 4 })
  }

  build() {
    Column() {
      MedicationExecutionNavBar({
        showMedicineBoxTrail: this.showsAsNeededCard(),
        onBack: () => {
          if (this.onBack) {
            this.onBack();
          }
        },
        onOpenMedicineBox: () => {
          if (this.onOpenPersonalCabinet) {
            this.onOpenPersonalCabinet();
          }
        }
      })

      Refresh({ refreshing: $$this.refreshing }) {
        Scroll(this.pageScroller) {
          Column({ space: 0 }) {
            this.dateNavigationSection()

            Column({ space: 16 }) {
              Text('记录')
                .fontSize(MED_EXEC_SECTION_TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(MED_EXEC_PRIMARY_TEXT)
                .width('100%')
                .margin({ bottom: 4 })

              if (this.pendingDoses().length === 0) {
                MedicationExecutionAllDoneCard()
              } else {
                Column({ space: 14 }) {
                  ForEach(
                    MedicationExecutionPlanner.groupByTime(this.pendingDoses()),
                    (group: MedicationExecutionTimeGroup) => {
                      MedicationExecutionPendingCard({
                        timeText: group.timeText,
                        doses: group.doses,
                        fileTransferService: this.fileTransferService,
                        onAdd: () => {
                          const context = new MedicationExecutionLogSheetContext();
                          context.title = MedicationExecutionSupport.logTitleAtTime(group.timeText);
                          context.date = this.selectedDayStart();
                          context.doses = group.doses;
                          this.openLogSheet(context);
                        }
                      })
                    },
                    (group: MedicationExecutionTimeGroup) => `${group.timeText}-${this.pageTick}`
                  )
                }
              }

              if (this.showsAsNeededCard()) {
                MedicationExecutionAsNeededCard({
                  onAdd: () => {
                    const context = new MedicationExecutionLogSheetContext();
                    context.title = MedicationExecutionSupport.allDrugsLogTitle();
                    context.date = this.selectedDayStart();
                    context.doses = this.asNeededDoses();
                    this.openLogSheet(context);
                  }
                })
              }
            }
            .width('100%')
            .padding({
              left: MED_EXEC_PAGE_HORIZONTAL,
              right: MED_EXEC_PAGE_HORIZONTAL,
              top: MED_EXEC_SECTION_SPACING
            })

            if (this.completedDoses().length > 0) {
              Column({ space: 14 }) {
                Text('已记录')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(MED_EXEC_PRIMARY_TEXT)
                  .width('100%')

                Column() {
                  ForEach(
                    MedicationExecutionPlanner.groupByTime(this.completedDoses()),
                    (group: MedicationExecutionTimeGroup, index: number) => {
                      Column() {
                        MedicationExecutionCompletedGroup({
                          timeText: group.timeText,
                          doses: group.doses,
                          onTap: () => {
                            const context = new MedicationExecutionLogSheetContext();
                            context.title = MedicationExecutionSupport.logTitleAtTime(group.timeText);
                            context.date = this.selectedDayStart();
                            context.doses = group.doses;
                            this.openLogSheet(context);
                          }
                        })
                        if (index < MedicationExecutionPlanner.groupByTime(this.completedDoses()).length - 1) {
                          Divider().margin({ left: 8 })
                        }
                      }
                    },
                    (group: MedicationExecutionTimeGroup) => `completed-${group.timeText}-${this.pageTick}`
                  )
                }
                .padding(16)
                .backgroundColor('#FFFFFF')
                .borderRadius(24)
              }
              .width('100%')
              .padding({
                left: MED_EXEC_PAGE_HORIZONTAL,
                right: MED_EXEC_PAGE_HORIZONTAL,
                top: MED_EXEC_SECTION_SPACING
              })
            }
          }
          .padding({ bottom: 32 })
        }
        .width('100%')
        .height('100%')
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .layoutWeight(1)
      .width('100%')
      .onRefreshing(() => {
        this.refreshCurrent();
      })

      if ((this.isLoading && !this.refreshing) || this.isSaving) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color('#007AFF')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MED_EXEC_PAGE_BG)
    .bindSheet($$this.showLogSheet, this.logSheetBuilder(), {
      height: SheetSize.LARGE,
      dragBar: true,
      onDisappear: () => {
        this.showLogSheet = false;
      }
    })
  }
}

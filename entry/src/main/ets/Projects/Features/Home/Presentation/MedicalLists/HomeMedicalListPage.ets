import { AppContainer } from '../../../../../App/AppContainer';
import { MedicalArchiveListMode, medicalArchiveQueryForMode } from '../../../../Core/Networking/API/Medical/MedicalArchiveModels';
import { SparkMedicalQueryAPI } from '../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import {
  RemoteExaminationReportWithAttachments,
  RemoteHealthExamReportWithAttachments,
  RemoteMedicalCaseSummary,
  RemoteMedicationPlan,
  RemoteMedicineBox
} from '../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { NotificationClient } from '../../../../Core/Notification/Application/NotificationClient';
import { Logger } from '../../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../../Foundation/Logging/LogModule';
import { HomeMedicalRouteSupport } from '../HomeMedicalRouteSupport';
import { HomeMedicalRoutes } from '../HomeMedicalRoutes';
import { HomeViewModel } from '../HomeViewModel';

/**
 * 首页医疗列表：首屏消费 completeData；下拉刷当前资源并字段回写。
 * 归档模式切断活跃缓存回写（对齐 iOS）。
 */
@Component
export struct HomeMedicalListPage {
  @Prop route: string = HomeMedicalRoutes.EXAMINATION_REPORTS;
  homeVm?: HomeViewModel;
  onBack?: () => void;
  onOpenFamilyCabinet?: () => void;
  onOpenPersonalCabinet?: () => void;

  @State private tick: number = 0;
  @State private refreshing: boolean = false;
  @State private errorText: string = '';
  @State private archiveMode: MedicalArchiveListMode = MedicalArchiveListMode.ACTIVE;
  @State private caseTitles: string[] = [];
  @State private healthTitles: string[] = [];
  @State private examTitles: string[] = [];
  @State private planTitles: string[] = [];
  @State private boxTitles: string[] = [];

  private medicalQuery?: SparkMedicalQueryAPI;
  private notification?: NotificationClient;

  aboutToAppear(): void {
    const container = AppContainer.shared();
    this.medicalQuery = container?.backend.medicalQuery;
    this.notification = container?.notificationClient;
    this.hydrateFromCache();
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
    if (this.archiveMode === MedicalArchiveListMode.ARCHIVED) {
      this.clearRows();
      this.tick += 1;
      return;
    }
    if (!data) {
      this.clearRows();
      this.tick += 1;
      return;
    }
    this.applyCases(data.medicalCases);
    this.applyHealth(data.healthExamReports);
    this.applyExam(data.examinationReports);
    this.applyPlans(data.medicationPlans);
    this.applyBoxes(data.medicineBoxes);
    this.tick += 1;
  }

  private clearRows(): void {
    this.caseTitles = [];
    this.healthTitles = [];
    this.examTitles = [];
    this.planTitles = [];
    this.boxTitles = [];
  }

  private applyCases(items: RemoteMedicalCaseSummary[]): void {
    const titles: string[] = [];
    for (let i = 0; i < items.length; i++) {
      const t = items[i].title ?? items[i].diagnosisSummary ?? `病历 #${items[i].id}`;
      titles.push(t);
    }
    this.caseTitles = titles;
  }

  private applyHealth(items: RemoteHealthExamReportWithAttachments[]): void {
    const titles: string[] = [];
    for (let i = 0; i < items.length; i++) {
      const t = items[i].institutionName ?? items[i].reportNo ?? `体检 #${items[i].id}`;
      titles.push(t);
    }
    this.healthTitles = titles;
  }

  private applyExam(items: RemoteExaminationReportWithAttachments[]): void {
    const titles: string[] = [];
    for (let i = 0; i < items.length; i++) {
      const t = items[i].itemName ?? items[i].category ?? `检查 #${items[i].id}`;
      titles.push(t);
    }
    this.examTitles = titles;
  }

  private applyPlans(items: RemoteMedicationPlan[]): void {
    const titles: string[] = [];
    for (let i = 0; i < items.length; i++) {
      titles.push(items[i].drugName.length > 0 ? items[i].drugName : `计划 #${items[i].id}`);
    }
    this.planTitles = titles;
  }

  private applyBoxes(items: RemoteMedicineBox[]): void {
    const titles: string[] = [];
    for (let i = 0; i < items.length; i++) {
      titles.push(items[i].medicineName.length > 0 ? items[i].medicineName : `药品 #${items[i].id}`);
    }
    this.boxTitles = titles;
  }

  private currentTitles(): string[] {
    if (this.route === HomeMedicalRoutes.MEDICAL_CASES) {
      return this.caseTitles;
    }
    if (this.route === HomeMedicalRoutes.HEALTH_EXAM_REPORTS) {
      return this.healthTitles;
    }
    if (this.route === HomeMedicalRoutes.EXAMINATION_REPORTS) {
      return this.examTitles;
    }
    return this.planTitles;
  }

  private async refreshCurrent(): Promise<void> {
    const query = this.medicalQuery;
    const homeVm = this.homeVm;
    if (!query || !homeVm) {
      return;
    }
    const memberID = this.memberID();
    if (memberID <= 0) {
      this.errorText = '未选中成员';
      return;
    }
    this.refreshing = true;
    this.errorText = '';
    const archived = medicalArchiveQueryForMode(this.archiveMode);
    const canPatchActive = this.archiveMode === MedicalArchiveListMode.ACTIVE;
    try {
      if (this.route === HomeMedicalRoutes.MEDICAL_CASES) {
        const list = await query.listMedicalCaseSummaries(memberID, archived);
        this.applyCases(list);
        if (canPatchActive) {
          HomeMedicalRouteSupport.patchMedicalCases(homeVm, list);
        }
      } else if (this.route === HomeMedicalRoutes.HEALTH_EXAM_REPORTS) {
        const list = await query.listHealthExamReportsWithAttachments(memberID, archived);
        this.applyHealth(list);
        if (canPatchActive) {
          HomeMedicalRouteSupport.patchHealthExamReports(homeVm, list);
        }
      } else if (this.route === HomeMedicalRoutes.EXAMINATION_REPORTS) {
        const list = await query.listExaminationReportsWithAttachments(memberID, archived);
        this.applyExam(list);
        if (canPatchActive) {
          HomeMedicalRouteSupport.patchExaminationReports(homeVm, list);
        }
      } else {
        const plans = await query.listMedicationPlans(memberID, archived);
        this.applyPlans(plans);
        if (canPatchActive) {
          HomeMedicalRouteSupport.patchMedicationPlans(homeVm, plans);
        }
        const boxes = await query.listMedicineBoxes(memberID, archived);
        this.applyBoxes(boxes);
        if (canPatchActive) {
          HomeMedicalRouteSupport.patchMedicineBoxes(homeVm, boxes);
        }
      }
      this.tick += 1;
    } catch (e) {
      const message = `${e}`;
      this.errorText = message;
      this.notification?.error(message, undefined, 'home.medical.list.refresh');
      const fields = new LogFields();
      fields.detail = message;
      Logger.warn('home.medical_list.refresh_failed', LogModule.HOME, fields);
      // 失败不回写缓存
    } finally {
      this.refreshing = false;
    }
  }

  private toggleArchive(): void {
    if (this.archiveMode === MedicalArchiveListMode.ACTIVE) {
      this.archiveMode = MedicalArchiveListMode.ARCHIVED;
    } else {
      this.archiveMode = MedicalArchiveListMode.ACTIVE;
    }
    this.hydrateFromCache();
    this.refreshCurrent();
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回')
          .fontSize(16)
          .fontColor('#0A84FF')
          .onClick(() => {
            if (this.onBack) {
              this.onBack();
            }
          })
        Blank()
        Text(HomeMedicalRoutes.titleForRoute(this.route))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(this.archiveMode === MedicalArchiveListMode.ARCHIVED ? '活跃' : '归档')
          .fontSize(14)
          .fontColor('#0A84FF')
          .onClick(() => {
            this.toggleArchive();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Row({ space: 16 }) {
        Text('刷新')
          .fontSize(14)
          .fontColor('#0A84FF')
          .onClick(() => {
            this.refreshCurrent();
          })
        if (this.route === HomeMedicalRoutes.MEDICATION_PLANS) {
          Text('家庭药箱')
            .fontSize(14)
            .fontColor('#0A84FF')
            .onClick(() => {
              if (this.onOpenFamilyCabinet) {
                this.onOpenFamilyCabinet();
              }
            })
          Text('个人药箱')
            .fontSize(14)
            .fontColor('#0A84FF')
            .onClick(() => {
              if (this.onOpenPersonalCabinet) {
                this.onOpenPersonalCabinet();
              }
            })
        }
        if (this.refreshing) {
          LoadingProgress().width(20).height(20)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(13)
          .fontColor('#FF3B30')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
      }

      if (this.currentTitles().length === 0 && !this.refreshing) {
        Text(this.archiveMode === MedicalArchiveListMode.ARCHIVED ? '暂无归档记录' : '暂无数据（可下拉刷新）')
          .fontSize(14)
          .fontColor('#888888')
          .width('100%')
          .padding(24)
          .textAlign(TextAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.currentTitles(), (title: string, index: number) => {
            ListItem() {
              Text(title)
                .fontSize(15)
                .fontColor('#1C1C1E')
                .width('100%')
                .padding(14)
                .backgroundColor('#F7F7F8')
                .borderRadius(10)
            }
          }, (title: string, index: number) => `${this.route}-${index}-${title}-${this.tick}`)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
      }

      if (this.route === HomeMedicalRoutes.MEDICATION_PLANS && this.boxTitles.length > 0
        && this.archiveMode === MedicalArchiveListMode.ACTIVE) {
        Text(`个人药箱 ${this.boxTitles.length} 项`)
          .fontSize(13)
          .fontColor('#666666')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}

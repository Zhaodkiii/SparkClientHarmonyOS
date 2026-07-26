import { AppContainer } from '../../../../../../App/AppContainer';
import {
  MedicalArchiveListMode,
  medicalArchiveQueryForMode
} from '../../../../../Core/Networking/API/Medical/MedicalArchiveModels';
import { SparkMedicalQueryAPI } from '../../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import { RemoteHealthExamReportWithAttachments } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { NotificationClient } from '../../../../../Core/Notification/Application/NotificationClient';
import { Logger } from '../../../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../../../Foundation/Logging/LogModule';
import { HomeMedicalRouteSupport } from '../../HomeMedicalRouteSupport';
import { HomeViewModel } from '../../HomeViewModel';
import { ExamReportCard } from './ExamReportCard';
import { HealthExamDetailLazyLoadController } from '../Shared/HealthExamDetailLazyLoadController';
import { nonEmptyText } from '../Shared/HealthExamFlagSupport';
import {
  MEDICAL_LIST_ACCENT,
  MEDICAL_LIST_DIVIDER,
  MEDICAL_LIST_HEADER_BG,
  MEDICAL_LIST_PAGE_BG,
  MEDICAL_LIST_SEARCH_FIELD_BG,
  MedicalListPageHeaderSection
} from '../Shared/MedicalListPageChrome';

type HealthExamFilterKey = 'all' | 'withSummary' | 'withAttachments';

/** 体检列表头部扩展：搜索 + 筛选。作为页面 build 子组件挂载，避免 @BuilderParam this 错位。 */
@Component
struct HealthExamReportsListHeaderExtension {
  @Link searchText: string;
  @Link selectedFilter: HealthExamFilterKey;
  @Prop refreshing: boolean = false;
  onRefresh: () => void = () => {
  };
  onFilterSelected: () => void = () => {
  };

  build() {
    Column({ space: 0 }) {
      TextInput({
        text: $$this.searchText,
        placeholder: '搜索机构 / 报告号 / 综述'
      })
        .height(36)
        .fontSize(14)
        .backgroundColor(MEDICAL_LIST_SEARCH_FIELD_BG)
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .margin({ left: 16, right: 16, bottom: 8 })

      Row({ space: 8 }) {
        this.filterChip('全部', 'all')
        this.filterChip('有综述', 'withSummary')
        this.filterChip('有附件', 'withAttachments')
        Blank()
        if (this.refreshing) {
          LoadingProgress().width(18).height(18)
        } else {
          Text('刷新')
            .fontSize(14)
            .fontColor(MEDICAL_LIST_ACCENT)
            .onClick(() => {
              this.onRefresh();
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })
    }
    .width('100%')
  }

  @Builder
  filterChip(title: string, key: HealthExamFilterKey) {
    Text(title)
      .fontSize(13)
      .fontColor(this.selectedFilter === key ? Color.White : '#1C1C1E')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.selectedFilter === key ? '#0A84FF' : '#FFFFFF')
      .borderRadius(14)
      .onClick(() => {
        this.selectedFilter = key;
        this.onFilterSelected();
      })
  }
}

/** 体检列表底部上传条。作为页面 build 子组件挂载，避免 @BuilderParam this 错位。 */
@Component
struct HealthExamReportsListBottomExtension {
  onUpload: () => void = () => {
  };

  build() {
    Text('拍照上传体检报告')
      .fontSize(15)
      .fontColor(Color.White)
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding({ top: 14, bottom: 14 })
      .backgroundColor(MEDICAL_LIST_ACCENT)
      .borderRadius(12)
      .onClick(() => {
        this.onUpload();
      })
      .margin({ left: 16, right: 16, top: 12, bottom: 12 })
  }
}

/**
 * 体检报告列表。对齐 iOS HealthExamReportsListPage：
 * 首屏 completeData → 懒加载明细 → 下拉刷列表字段回写 → 归档列表切断缓存。
 * 底部上传条先占位（OCR Feature 未接入）。
 */
@Component
export struct HealthExamReportsListPage {
  homeVm?: HomeViewModel;
  onBack?: () => void;
  onOpenDetail?: () => void;
  @Prop @Watch('onListRevisionChanged') listRevision: number = 0;

  @State private tick: number = 0;
  @State private refreshing: boolean = false;
  @State private errorText: string = '';
  @State private archiveMode: MedicalArchiveListMode = MedicalArchiveListMode.ACTIVE;
  @State private selectedFilter: HealthExamFilterKey = 'all';
  @State private searchText: string = '';
  @State private reports: RemoteHealthExamReportWithAttachments[] = [];
  @State private loadingDetailIds: string = '';

  private medicalQuery?: SparkMedicalQueryAPI;
  private notification?: NotificationClient;
  private lazyController?: HealthExamDetailLazyLoadController;

  aboutToAppear(): void {
    const container = AppContainer.shared();
    this.medicalQuery = container?.backend.medicalQuery;
    this.notification = container?.notificationClient;
    this.hydrateFromCache();
  }

  onListRevisionChanged(): void {
    if (this.archiveMode === MedicalArchiveListMode.ACTIVE) {
      this.hydrateFromCache();
    }
  }

  private memberID(): number {
    const data = this.homeVm?.completeData();
    if (data && data.memberId > 0) {
      return data.memberId;
    }
    return this.homeVm?.selectedMemberID ?? 0;
  }

  private hydrateFromCache(): void {
    if (this.archiveMode === MedicalArchiveListMode.ARCHIVED) {
      this.reports = [];
      this.ensureController([]);
      this.tick += 1;
      return;
    }
    const cached = this.homeVm?.completeData()?.healthExamReports ?? [];
    this.reports = cached.slice();
    this.ensureController(this.reports);
    this.tick += 1;
    this.prefetchVisibleDetails();
  }

  private ensureController(seed: RemoteHealthExamReportWithAttachments[]): void {
    const query = this.medicalQuery;
    if (!query) {
      return;
    }
    const canPatch = this.archiveMode === MedicalArchiveListMode.ACTIVE;
    this.lazyController = new HealthExamDetailLazyLoadController(
      seed,
      query,
      (updated: RemoteHealthExamReportWithAttachments[]) => {
        this.reports = updated;
        this.syncLoadingIds();
        this.tick += 1;
        if (canPatch && this.homeVm) {
          HomeMedicalRouteSupport.patchHealthExamReports(this.homeVm, updated);
        }
      }
    );
    this.syncLoadingIds();
  }

  private syncLoadingIds(): void {
    const ctrl = this.lazyController;
    if (!ctrl) {
      this.loadingDetailIds = '';
      return;
    }
    const parts: string[] = [];
    for (let i = 0; i < this.reports.length; i++) {
      const id = this.reports[i].id;
      if (ctrl.isLoading(id)) {
        parts.push(`${id}`);
      }
    }
    let joined = '';
    for (let i = 0; i < parts.length; i++) {
      if (i > 0) {
        joined += ',';
      }
      joined += parts[i];
    }
    this.loadingDetailIds = joined;
  }

  private isDetailLoading(reportID: number): boolean {
    return `,${this.loadingDetailIds},`.indexOf(`,${reportID},`) >= 0;
  }

  private prefetchVisibleDetails(): void {
    const ctrl = this.lazyController;
    if (!ctrl) {
      return;
    }
    const list = this.filteredReports();
    for (let i = 0; i < list.length; i++) {
      ctrl.loadDetailsIfNeeded(list[i].id).then(() => {
        this.syncLoadingIds();
        this.tick += 1;
      });
    }
  }

  private matchesFilter(report: RemoteHealthExamReportWithAttachments): boolean {
    if (this.selectedFilter === 'withSummary') {
      return nonEmptyText(report.summary).length > 0;
    }
    if (this.selectedFilter === 'withAttachments') {
      return report.attachments.length > 0;
    }
    return true;
  }

  private matchesSearch(report: RemoteHealthExamReportWithAttachments): boolean {
    const keyword = this.searchText.trim();
    if (keyword.length === 0) {
      return true;
    }
    const fields: string[] = [
      nonEmptyText(report.institutionName),
      nonEmptyText(report.reportNo),
      nonEmptyText(report.summary)
    ];
    const lower = keyword.toLowerCase();
    for (let i = 0; i < fields.length; i++) {
      if (fields[i].toLowerCase().indexOf(lower) >= 0) {
        return true;
      }
    }
    return false;
  }

  private filteredReports(): RemoteHealthExamReportWithAttachments[] {
    const out: RemoteHealthExamReportWithAttachments[] = [];
    for (let i = 0; i < this.reports.length; i++) {
      const report = this.reports[i];
      if (this.matchesFilter(report) && this.matchesSearch(report)) {
        out.push(report);
      }
    }
    return out;
  }

  private async refreshReports(): Promise<void> {
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
    const canPatch = this.archiveMode === MedicalArchiveListMode.ACTIVE;
    try {
      const list = await query.listHealthExamReportsWithAttachments(memberID, archived);
      this.reports = list;
      this.ensureController(list);
      if (canPatch) {
        HomeMedicalRouteSupport.patchHealthExamReports(homeVm, list);
      }
      this.tick += 1;
      this.prefetchVisibleDetails();
      const fields = new LogFields();
      fields.detail = `memberID=${memberID} count=${list.length} archive=${this.archiveMode}`;
      Logger.info('health_exam.list.refresh_done', LogModule.HOME, fields);
    } catch (e) {
      const message = `${e}`;
      this.errorText = message;
      this.notification?.error(message, undefined, 'home.health_exam_reports.refresh');
      const fields = new LogFields();
      fields.detail = message;
      Logger.warn('health_exam.list.refresh_failed', LogModule.HOME, fields);
    } finally {
      this.refreshing = false;
    }
  }

  private toggleArchiveMode(): void {
    if (this.archiveMode === MedicalArchiveListMode.ACTIVE) {
      this.archiveMode = MedicalArchiveListMode.ARCHIVED;
    } else {
      this.archiveMode = MedicalArchiveListMode.ACTIVE;
    }
    this.hydrateFromCache();
    this.refreshReports();
  }

  private openDetail(report: RemoteHealthExamReportWithAttachments): void {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    homeVm.healthExamDetailTarget = report.clone();
    homeVm.healthExamDetailArchiveMode = this.archiveMode;
    if (this.onOpenDetail) {
      this.onOpenDetail();
    }
  }

  build() {
    Column() {
      Column({ space: 0 }) {
        MedicalListPageHeaderSection({
          title: this.archiveMode === MedicalArchiveListMode.ARCHIVED ? '归档体检' : '体检',
          onBack: () => {
            if (this.onBack) {
              this.onBack();
            }
          },
          trailingText: this.archiveMode === MedicalArchiveListMode.ARCHIVED ? '活跃' : '归档',
          onTrailing: () => {
            this.toggleArchiveMode();
          }
        })
        HealthExamReportsListHeaderExtension({
          searchText: $searchText,
          selectedFilter: $selectedFilter,
          refreshing: this.refreshing,
          onRefresh: () => {
            this.refreshReports();
          },
          onFilterSelected: () => {
            this.tick += 1;
            this.prefetchVisibleDetails();
          }
        })
        Divider()
          .width('100%')
          .height(0.5)
          .color(MEDICAL_LIST_DIVIDER)
      }
      .width('100%')
      .backgroundColor(MEDICAL_LIST_HEADER_BG)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(13)
          .fontColor('#FF3B30')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
      }

      if (this.filteredReports().length === 0 && !this.refreshing) {
        Text(this.archiveMode === MedicalArchiveListMode.ARCHIVED ? '暂无归档记录' : '暂无体检报告')
          .fontSize(14)
          .fontColor('#8E8E93')
          .width('100%')
          .padding(32)
          .textAlign(TextAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.filteredReports(), (report: RemoteHealthExamReportWithAttachments) => {
            ListItem() {
              ExamReportCard({
                report: report,
                isLoadingDetails: this.isDetailLoading(report.id),
                onOpenDetail: () => {
                  this.openDetail(report);
                }
              })
            }
            .onAppear(() => {
              const ctrl = this.lazyController;
              if (ctrl) {
                ctrl.loadDetailsIfNeeded(report.id).then(() => {
                  this.syncLoadingIds();
                  this.tick += 1;
                });
              }
            })
          }, (report: RemoteHealthExamReportWithAttachments) =>
            `hexam-${report.id}-${report.detailsLoaded}-${report.medExamDetails.length}-${this.tick}`)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      }

      if (this.archiveMode === MedicalArchiveListMode.ACTIVE) {
        Column({ space: 0 }) {
          Divider()
            .width('100%')
            .height(0.5)
            .color(MEDICAL_LIST_DIVIDER)
          HealthExamReportsListBottomExtension({
            onUpload: () => {
              this.notification?.info('体检上传识别即将接入', undefined, 'home.health_exam.upload');
            }
          })
        }
        .width('100%')
        .backgroundColor(MEDICAL_LIST_HEADER_BG)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MEDICAL_LIST_PAGE_BG)
  }
}

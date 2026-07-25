import { AppContainer } from '../../../../../../App/AppContainer';
import {
  MedicalArchiveListMode,
  medicalArchiveQueryForMode
} from '../../../../../Core/Networking/API/Medical/MedicalArchiveModels';
import { SparkMedicalQueryAPI } from '../../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import { RemoteExaminationReportWithAttachments } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { NotificationClient } from '../../../../../Core/Notification/Application/NotificationClient';
import { Logger } from '../../../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../../../Foundation/Logging/LogModule';
import { FileTransferService } from '../../../../../../Core/FileStorage/FileTransferService';
import { HomeMedicalRouteSupport } from '../../HomeMedicalRouteSupport';
import { HomeViewModel } from '../../HomeViewModel';
import { ExaminationDetailLazyLoadController } from '../Shared/ExaminationDetailLazyLoadController';
import { nonEmptyText } from '../Shared/HealthExamFlagSupport';
import {
  ExaminationFilterKey,
  ExaminationTimelineSection,
  buildExaminationTimelineSections,
  examinationAllFilterIcon,
  examinationCategoryIcon,
  examinationCategoryMatches,
  examinationCategoryTint,
  examinationCategoryTitle
} from './ExaminationReportCategory';
import { LabReportCard } from './LabReportCard';

/**
 * 检查报告列表。对齐 iOS ExaminationReportsListPage：
 * 首屏 completeData.examinationReports → 横滚分类 Chip / 搜索 →
 * 按分类连续分段的时间线（每段一个分类 Header）→
 * 懒加载明细 → 刷新字段回写 → 归档切断缓存。
 * OCR / 手工录入底部入口先占位。
 */
@Component
export struct ExaminationReportsListPage {
  homeVm?: HomeViewModel;
  onBack?: () => void;
  onOpenDetail?: () => void;
  onOpenArchive?: () => void;
  @Prop archiveMode: MedicalArchiveListMode = MedicalArchiveListMode.ACTIVE;
  @Prop @Watch('onListRevisionChanged') listRevision: number = 0;

  @State private tick: number = 0;
  @State private refreshing: boolean = false;
  @State private errorText: string = '';
  @State private selectedFilter: ExaminationFilterKey = 'all';
  @State private searchText: string = '';
  @State private reports: RemoteExaminationReportWithAttachments[] = [];
  @State private loadingDetailIds: string = '';

  private medicalQuery?: SparkMedicalQueryAPI;
  private notification?: NotificationClient;
  private lazyController?: ExaminationDetailLazyLoadController;
  private fileTransferService?: FileTransferService;

  aboutToAppear(): void {
    const container = AppContainer.shared();
    this.medicalQuery = container?.backend.medicalQuery;
    this.notification = container?.notificationClient;
    this.fileTransferService = container?.fileTransferService;
    if (this.archiveMode === MedicalArchiveListMode.ARCHIVED) {
      this.refreshReports();
    } else {
      this.hydrateFromCache();
    }
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
    const cached = this.homeVm?.completeData()?.examinationReports ?? [];
    this.reports = cached.slice();
    this.ensureController(this.reports);
    this.tick += 1;
    this.prefetchVisibleDetails();
  }

  private ensureController(seed: RemoteExaminationReportWithAttachments[]): void {
    const query = this.medicalQuery;
    if (!query) {
      return;
    }
    const canPatch = this.archiveMode === MedicalArchiveListMode.ACTIVE;
    this.lazyController = new ExaminationDetailLazyLoadController(
      seed,
      query,
      (updated: RemoteExaminationReportWithAttachments[]) => {
        this.reports = updated;
        this.syncLoadingIds();
        this.tick += 1;
        if (canPatch && this.homeVm) {
          HomeMedicalRouteSupport.patchExaminationReports(this.homeVm, updated);
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
      if (ctrl.isLoading(this.reports[i].id)) {
        parts.push(`${this.reports[i].id}`);
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

  private matchesSearch(report: RemoteExaminationReportWithAttachments): boolean {
    const keyword = this.searchText.trim();
    if (keyword.length === 0) {
      return true;
    }
    const fields: string[] = [
      nonEmptyText(report.itemName),
      nonEmptyText(report.category),
      nonEmptyText(report.subCategory),
      nonEmptyText(report.organizationName),
      nonEmptyText(report.departmentName),
      nonEmptyText(report.doctorName),
      nonEmptyText(report.findings),
      nonEmptyText(report.impression)
    ];
    const lower = keyword.toLowerCase();
    for (let i = 0; i < fields.length; i++) {
      if (fields[i].toLowerCase().indexOf(lower) >= 0) {
        return true;
      }
    }
    return false;
  }

  private filteredReports(): RemoteExaminationReportWithAttachments[] {
    const matched: RemoteExaminationReportWithAttachments[] = [];
    for (let i = 0; i < this.reports.length; i++) {
      const report = this.reports[i];
      if (examinationCategoryMatches(report, this.selectedFilter) && this.matchesSearch(report)) {
        matched.push(report);
      }
    }
    return matched;
  }

  /** 按分类连续分段的时间线。对齐 iOS ExaminationReportTimelineSection.makeSections。 */
  private timelineSections(): ExaminationTimelineSection[] {
    return buildExaminationTimelineSections(this.filteredReports());
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
      const list = await query.listExaminationReportsWithAttachments(memberID, archived);
      this.reports = list;
      this.ensureController(list);
      if (canPatch) {
        HomeMedicalRouteSupport.patchExaminationReports(homeVm, list);
      }
      this.tick += 1;
      this.prefetchVisibleDetails();
      const fields = new LogFields();
      fields.detail = `memberID=${memberID} count=${list.length} archive=${this.archiveMode}`;
      Logger.info('examination.list.refresh_done', LogModule.HOME, fields);
    } catch (e) {
      const message = `${e}`;
      this.errorText = message;
      this.notification?.error(message, undefined, 'home.examination_reports.refresh');
      const fields = new LogFields();
      fields.detail = message;
      Logger.warn('examination.list.refresh_failed', LogModule.HOME, fields);
    } finally {
      this.refreshing = false;
    }
  }

  private openArchive(): void {
    if (this.onOpenArchive) {
      this.onOpenArchive();
    }
  }

  private openDetail(report: RemoteExaminationReportWithAttachments): void {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    homeVm.examinationDetailTarget = report.clone();
    homeVm.examinationDetailArchiveMode = this.archiveMode;
    if (this.onOpenDetail) {
      this.onOpenDetail();
    }
  }

  private selectFilter(key: ExaminationFilterKey): void {
    if (this.selectedFilter === key && key !== 'all') {
      this.selectedFilter = 'all';
    } else {
      this.selectedFilter = key;
    }
    this.tick += 1;
    this.prefetchVisibleDetails();
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
        Text(this.archiveMode === MedicalArchiveListMode.ARCHIVED ? '归档检查' : '检查报告')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Blank()
        if (this.archiveMode === MedicalArchiveListMode.ACTIVE) {
          Text('归档')
            .fontSize(14)
            .fontColor('#0A84FF')
            .onClick(() => {
              this.openArchive();
            })
        } else {
          Blank().width(28)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      TextInput({ text: this.searchText, placeholder: '搜索项目 / 机构 / 科室 / 所见 / 印象' })
        .height(36)
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .margin({ left: 16, right: 16, bottom: 8 })
        .onChange((value: string) => {
          this.searchText = value;
          this.tick += 1;
        })

      Row({ space: 8 }) {
        Scroll() {
          Row({ space: 10 }) {
            this.filterChip('全部', examinationAllFilterIcon(), '#8E8E93', 'all')
            this.filterChip('实验室', examinationCategoryIcon('laboratory'), examinationCategoryTint('laboratory'), 'laboratory')
            this.filterChip('影像', examinationCategoryIcon('imaging'), examinationCategoryTint('imaging'), 'imaging')
            this.filterChip('病理', examinationCategoryIcon('pathology'), examinationCategoryTint('pathology'), 'pathology')
          }
          .padding({ left: 2, right: 2 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)

        if (this.refreshing) {
          LoadingProgress().width(18).height(18)
        } else {
          Text('刷新')
            .fontSize(14)
            .fontColor('#0A84FF')
            .onClick(() => {
              this.refreshReports();
            })
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

      if (this.filteredReports().length === 0 && !this.refreshing) {
        this.emptyState()
      } else {
        List({ space: 20 }) {
          ForEach(this.timelineSections(), (section: ExaminationTimelineSection) => {
            ListItem() {
              this.timelineSectionView(section)
            }
          }, (section: ExaminationTimelineSection) =>
            `section-${section.category}-${section.reports[0]?.id}-${section.reports.length}-${this.tick}`)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      }

      if (this.archiveMode === MedicalArchiveListMode.ACTIVE && this.memberID() > 0) {
        Row({ space: 12 }) {
          Text('手动添加')
            .fontSize(15)
            .fontColor('#0A84FF')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .border({ width: 1, color: '#0A84FF' })
            .onClick(() => {
              this.notification?.info('检查手工录入即将接入', undefined, 'home.examination.manual');
            })
          Text('上传检查报告')
            .fontSize(15)
            .fontColor(Color.White)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .backgroundColor('#0A84FF')
            .borderRadius(12)
            .onClick(() => {
              this.notification?.info('检查上传识别即将接入', undefined, 'home.examination.upload');
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
  }

  @Builder
  emptyState() {
    Column({ space: 12 }) {
      SymbolGlyph(examinationAllFilterIcon())
        .fontSize(40)
        .fontColor(['#C7C7CC'])
      Text(this.archiveMode === MedicalArchiveListMode.ARCHIVED ? '暂无归档记录' : '暂无检查报告')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#8E8E93')
      Text(this.archiveMode === MedicalArchiveListMode.ARCHIVED ? '归档后的检查报告会显示在这里' : '上传检查报告后，将在这里显示')
        .fontSize(13)
        .fontColor('#AEAEB2')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  timelineSectionView(section: ExaminationTimelineSection) {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        SymbolGlyph(examinationCategoryIcon(section.category))
          .fontSize(18)
          .fontColor([examinationCategoryTint(section.category)])
        Text(examinationCategoryTitle(section.category))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
        Blank()
        Text(`${section.reports.length}`)
          .fontSize(13)
          .fontColor('#8E8E93')
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor('#F2F2F7')
          .borderRadius(8)
      }
      .width('100%')

      Column({ space: 12 }) {
        ForEach(section.reports, (report: RemoteExaminationReportWithAttachments) => {
          LabReportCard({
            report: report,
            isLoadingDetails: this.isDetailLoading(report.id),
            fileTransferService: this.fileTransferService,
            onOpenDetail: () => {
              this.openDetail(report);
            }
          })
            .onAppear(() => {
              const ctrl = this.lazyController;
              if (ctrl) {
                ctrl.loadDetailsIfNeeded(report.id).then(() => {
                  this.syncLoadingIds();
                  this.tick += 1;
                });
              }
            })
        }, (report: RemoteExaminationReportWithAttachments) =>
          `exam-${report.id}-${report.detailsLoaded}-${report.medExamDetails.length}-${this.tick}`)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  filterChip(title: string, icon: Resource, color: string, key: ExaminationFilterKey) {
    Row({ space: 6 }) {
      SymbolGlyph(icon)
        .fontSize(12)
        .fontColor([this.selectedFilter === key ? Color.White : color])
      Text(title)
        .fontSize(13)
        .fontColor(this.selectedFilter === key ? Color.White : color)
    }
    .padding({ left: 12, right: 12, top: 7, bottom: 7 })
    .backgroundColor(this.selectedFilter === key ? color : '#FFFFFF')
    .borderRadius(16)
    .border({ width: 1, color: this.selectedFilter === key ? color : `${color}4D` })
    .onClick(() => {
      this.selectFilter(key);
    })
  }
}

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
import { MedicalAttachmentUploadListSheet } from '../Shared/MedicalAttachmentUploadListSheet';
import {
  MEDICAL_LIST_ACCENT,
  MEDICAL_LIST_DIVIDER,
  MEDICAL_LIST_HEADER_BG,
  MEDICAL_LIST_PAGE_BG,
  MEDICAL_LIST_SEARCH_FIELD_BG,
  MedicalListPageHeaderSection
} from '../Shared/MedicalListPageChrome';
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
import { ExaminationReportDraftMapping } from './ExaminationReportDraftMapping';
import { ExaminationReportServerMutationService } from './ExaminationReportServerMutationService';
import { LabReportCard } from './LabReportCard';
import { MedicalDocumentKind } from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { MedicalReportRecognitionDraft } from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { MedicalUploadLocalFile } from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentUploadModels';
import {
  medicalDocumentUploadStartBridge
} from '../../../../MedicalDocumentUpload/Presentation/MedicalDocumentUploadStartBridge';
import { ExamReportFormView } from '../../../../MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormView';
import { ExamReportFormContext } from '../../../../MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormContext';
import { ExamReportFormModeKind } from '../../../../MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormMode';

/** 列表页弹层类型。同一节点仅挂一个 bindSheet，上传与手动添加统一由此承载。 */
enum ExaminationReportsListOverlay {
  NONE = 'none',
  UPLOAD = 'upload',
  MANUAL_ADD = 'manual_add'
}

/** 检查报告列表头部扩展：搜索 + 分类筛选。作为页面 build 子组件挂载，避免 @BuilderParam this 错位。 */
@Component
struct ExaminationReportsListHeaderExtension {
  @Link searchText: string;
  @Link selectedFilter: ExaminationFilterKey;
  onFilterSelect: (key: ExaminationFilterKey) => void = (_key: ExaminationFilterKey) => {
  };

  build() {
    Column({ space: 0 }) {
      TextInput({
        text: $$this.searchText,
        placeholder: '搜索项目 / 机构 / 科室 / 所见 / 印象'
      })
        .height(36)
        .fontSize(14)
        .backgroundColor(MEDICAL_LIST_SEARCH_FIELD_BG)
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .margin({ left: 16, right: 16, bottom: 8 })

      Scroll() {
        Row({ space: 12 }) {
          this.filterChip('全部', examinationAllFilterIcon(), '#0A84FF', 'all')
          this.filterChip('实验室', examinationCategoryIcon('laboratory'), examinationCategoryTint('laboratory'), 'laboratory')
          this.filterChip('影像', examinationCategoryIcon('imaging'), examinationCategoryTint('imaging'), 'imaging')
          this.filterChip('病理', examinationCategoryIcon('pathology'), examinationCategoryTint('pathology'), 'pathology')
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(40)
      .padding({ left: 16, right: 16, bottom: 8 })
    }
    .width('100%')
  }

  @Builder
  filterChip(title: string, icon: Resource, color: string, key: ExaminationFilterKey) {
    Row({ space: 6 }) {
      SymbolGlyph(icon)
        .fontSize(12)
        .fontColor([this.selectedFilter === key ? Color.White : '#1C1C1E'])
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selectedFilter === key ? Color.White : '#1C1C1E')
    }
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .backgroundColor(this.selectedFilter === key ? color : '#F2F2F7')
    .borderRadius(20)
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onFilterSelect(key);
    })
  }
}

/** 检查报告列表底部：手动添加 + 上传。作为页面 build 子组件挂载，避免 @BuilderParam this 错位。 */
@Component
struct ExaminationReportsListBottomExtension {
  onManualAdd: () => void = () => {
  };
  onUpload: () => void = () => {
  };

  build() {
    Row({ space: 12 }) {
      Text('手动添加')
        .fontSize(15)
        .fontColor(MEDICAL_LIST_ACCENT)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .padding({ top: 14, bottom: 14 })
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .border({ width: 1, color: MEDICAL_LIST_ACCENT })
        .onClick(() => {
          this.onManualAdd();
        })
      Text('上传检查报告')
        .fontSize(15)
        .fontColor(Color.White)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .padding({ top: 14, bottom: 14 })
        .backgroundColor(MEDICAL_LIST_ACCENT)
        .borderRadius(12)
        .onClick(() => {
          this.onUpload();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }
}

/** 上传检查报告 Sheet 内容。独立组件挂载，避免 bindSheet @Builder 内 this 错位。 */
@Component
struct ExaminationReportsUploadSheetContent {
  onCancel: () => void = () => {
  };
  onConfirm: (files: MedicalUploadLocalFile[]) => void = (_files: MedicalUploadLocalFile[]) => {
  };

  build() {
    MedicalAttachmentUploadListSheet({
      documentKind: MedicalDocumentKind.MEDICAL_REPORT,
      onCancel: () => {
        this.onCancel();
      },
      onConfirm: (files: MedicalUploadLocalFile[]) => {
        this.onConfirm(files);
      }
    })
  }
}

/** 手动添加检查报告 Sheet 内容。独立组件挂载，避免 bindSheet @Builder 内 this 错位。 */
@Component
struct ExaminationReportsManualAddSheetContent {
  formSession: number = 0;
  formContext: ExamReportFormContext = new ExamReportFormContext();
  onCreated: (newID: number, draft: MedicalReportRecognitionDraft) => void =
    (_newID: number, _draft: MedicalReportRecognitionDraft) => {
    };
  onCancel: () => void = () => {
  };

  build() {
    ExamReportFormView({
      formSession: this.formSession,
      formContext: this.formContext,
      onCreated: (newID: number, draft: MedicalReportRecognitionDraft) => {
        this.onCreated(newID, draft);
      },
      onCancel: () => {
        this.onCancel();
      }
    })
  }
}

/**
 * 检查报告列表。对齐 iOS ExaminationReportsListPage：
 * 首屏 completeData.examinationReports → 横滚分类 Chip / 搜索 →
 * 按分类连续分段的时间线（每段一个分类 Header）→
 * 懒加载明细 → 下拉刷新摘要列表 → active 回写首页缓存 → 归档首次进入主动拉取。
 * 底部「手动添加」→ Sheet 打开 `ExamReportFormView`（create）；「上传检查报告」→ 上传 Sheet。
 */
@Component
export struct ExaminationReportsListPage {
  homeVm?: HomeViewModel;
  onBack?: () => void;
  onOpenDetail?: () => void;
  onOpenArchive?: () => void;
  @Prop archiveMode: MedicalArchiveListMode = MedicalArchiveListMode.ACTIVE;
  @Prop @Watch('onListRevisionChanged') listRevision: number = 0;

  @State private refreshing: boolean = false;
  @State private errorText: string = '';
  @State private selectedFilter: ExaminationFilterKey = 'all';
  @State private searchText: string = '';
  @State private reports: RemoteExaminationReportWithAttachments[] = [];
  @State private loadingDetailIds: string = '';
  /** 明细懒加载完成后递增，强制 List/ForEach 与 LabReportCard 刷新。对齐 HealthExamReportsListPage.tick。 */
  @State private listTick: number = 0;
  @State private showOverlaySheet: boolean = false;
  @State private activeOverlay: ExaminationReportsListOverlay = ExaminationReportsListOverlay.NONE;
  @State private addFormSession: number = 0;
  @State private addFormContext: ExamReportFormContext = new ExamReportFormContext();

  private medicalQuery?: SparkMedicalQueryAPI;
  private mutationService?: ExaminationReportServerMutationService;
  private notification?: NotificationClient;
  private lazyController?: ExaminationDetailLazyLoadController;
  private fileTransferService?: FileTransferService;

  aboutToAppear(): void {
    const container = AppContainer.shared();
    this.medicalQuery = container?.backend.medicalQuery;
    const workflow = container?.backend.medicalWorkflow;
    if (workflow) {
      this.mutationService = new ExaminationReportServerMutationService(workflow, this.medicalQuery);
    }
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
      return;
    }
    const cached = this.homeVm?.completeData()?.examinationReports ?? [];
    const merged = ExaminationDetailLazyLoadController.mergePreservingLoadedDetails(
      cached,
      this.reports
    );
    this.reports = merged;
    this.ensureController(merged);
  }

  private ensureController(seed: RemoteExaminationReportWithAttachments[]): void {
    const query = this.medicalQuery;
    if (!query) {
      return;
    }
    const canPatch = this.archiveMode === MedicalArchiveListMode.ACTIVE;
    const onUpdated = (updated: RemoteExaminationReportWithAttachments[]): void => {
      this.reports = updated.map((row: RemoteExaminationReportWithAttachments) => row.clone());
      this.listTick += 1;
      this.syncLoadingIds();
      if (canPatch && this.homeVm) {
        HomeMedicalRouteSupport.patchExaminationReports(this.homeVm, this.reports);
      }
    };
    if (this.lazyController) {
      this.lazyController.replaceReports(seed);
      this.reports = this.lazyController.reports.map((row: RemoteExaminationReportWithAttachments) => row.clone());
      this.listTick += 1;
      this.syncLoadingIds();
      return;
    }
    this.lazyController = new ExaminationDetailLazyLoadController(seed, query, onUpdated);
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

  /** 对齐 iOS `.task { onLoadDetails }`：单条卡片出现时触发，已加载或加载中则跳过。 */
  private startDetailLoad(reportID: number): void {
    const ctrl = this.lazyController;
    if (!ctrl) {
      return;
    }
    let index = -1;
    for (let i = 0; i < this.reports.length; i++) {
      if (this.reports[i].id === reportID) {
        index = i;
        break;
      }
    }
    if (index >= 0 &&
      ExaminationDetailLazyLoadController.hasLoadedDetails(this.reports[index])) {
      return;
    }
    ctrl.loadDetailsIfNeeded(reportID).finally(() => {
      this.syncLoadingIds();
      this.listTick += 1;
    });
    this.syncLoadingIds();
    this.listTick += 1;
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
      // 对齐 iOS replaceReports：刷新只更新摘要字段；明细由卡片 onAppear 再懒加载。
      this.reports = list;
      this.ensureController(list);
      if (canPatch) {
        HomeMedicalRouteSupport.patchExaminationReports(homeVm, list);
      }
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

  /** 优先取列表懒加载控制器中的最新副本，保证已补拉的明细能带入详情页。 */
  private resolveReportForDetail(report: RemoteExaminationReportWithAttachments): RemoteExaminationReportWithAttachments {
    for (let i = 0; i < this.reports.length; i++) {
      if (this.reports[i].id === report.id) {
        return this.reports[i].clone();
      }
    }
    return report.clone();
  }

  private openDetail(report: RemoteExaminationReportWithAttachments): void {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    homeVm.examinationDetailTarget = this.resolveReportForDetail(report);
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
  }

  private startExaminationReportRecognition(files: MedicalUploadLocalFile[]): void {
    if (files.length === 0) {
      return;
    }
    this.dismissOverlaySheet();
    const didStart = medicalDocumentUploadStartBridge.start(files, MedicalDocumentKind.MEDICAL_REPORT);
    if (!didStart) {
      this.notification?.error('上传模块暂不可用，请稍后重试', undefined, 'home.examination.upload');
    }
  }

  private openUploadSheet(): void {
    this.activeOverlay = ExaminationReportsListOverlay.UPLOAD;
    this.showOverlaySheet = true;
  }

  private openManualAddSheet(): void {
    this.addFormContext.modeKind = ExamReportFormModeKind.CREATE;
    this.addFormContext.memberID = this.memberID();
    this.addFormContext.medicalCaseID = undefined;
    this.addFormContext.existingReport = undefined;
    this.addFormContext.existingDraft = undefined;
    this.addFormContext.mutationService = this.mutationService;
    this.addFormSession += 1;
    this.activeOverlay = ExaminationReportsListOverlay.MANUAL_ADD;
    this.showOverlaySheet = true;
  }

  /** 仅触发 Sheet 关闭动画；内容类型保留到 onDisappear，避免关闭过程中白屏。 */
  private dismissOverlaySheet(): void {
    this.showOverlaySheet = false;
  }

  private onOverlaySheetDisappear(): void {
    this.showOverlaySheet = false;
    this.activeOverlay = ExaminationReportsListOverlay.NONE;
  }

  private overlaySheetDragBar(): boolean {
    return this.activeOverlay === ExaminationReportsListOverlay.MANUAL_ADD;
  }

  /** 对齐 iOS `viewModel.prependReport(summaryAfterCreate)`。 */
  private prependReport(summary: RemoteExaminationReportWithAttachments): void {
    const next: RemoteExaminationReportWithAttachments[] = [summary.clone()];
    for (let i = 0; i < this.reports.length; i++) {
      next.push(this.reports[i]);
    }
    this.reports = next;
    this.ensureController(next);
    this.listTick += 1;
    if (this.homeVm) {
      HomeMedicalRouteSupport.patchExaminationReports(this.homeVm, next);
    }
  }

  @Builder
  private overlaySheetContent() {
    if (this.activeOverlay === ExaminationReportsListOverlay.UPLOAD) {
      ExaminationReportsUploadSheetContent({
        onCancel: () => {
          this.dismissOverlaySheet();
        },
        onConfirm: (files: MedicalUploadLocalFile[]) => {
          this.startExaminationReportRecognition(files);
        }
      })
    } else if (this.activeOverlay === ExaminationReportsListOverlay.MANUAL_ADD) {
      ExaminationReportsManualAddSheetContent({
        formSession: this.addFormSession,
        formContext: this.addFormContext,
        onCreated: (newID: number, draft: MedicalReportRecognitionDraft) => {
          const summary = ExaminationReportDraftMapping.remoteExaminationReportFromDraft(
            draft,
            this.memberID(),
            newID
          );
          this.prependReport(summary);
          this.dismissOverlaySheet();
          this.notification?.success('检查报告已保存', undefined, 'home.examination.manual_create');
        },
        onCancel: () => {
          this.dismissOverlaySheet();
        }
      })
    }
  }

  build() {
    Column() {
      Column({ space: 0 }) {
        MedicalListPageHeaderSection({
          title: this.archiveMode === MedicalArchiveListMode.ARCHIVED ? '归档检查' : '检查报告',
          onBack: () => {
            if (this.onBack) {
              this.onBack();
            }
          },
          trailingText: this.archiveMode === MedicalArchiveListMode.ACTIVE ? '归档' : '',
          onTrailing: () => {
            this.openArchive();
          }
        })
        ExaminationReportsListHeaderExtension({
          searchText: $searchText,
          selectedFilter: $selectedFilter,
          onFilterSelect: (key: ExaminationFilterKey) => {
            this.selectFilter(key);
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

      Refresh({ refreshing: $$this.refreshing }) {
        if (this.filteredReports().length === 0) {
          Scroll() {
            this.emptyState()
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        } else {
          List({ space: 20 }) {
            ForEach(this.timelineSections(), (section: ExaminationTimelineSection) => {
              ListItem() {
                this.timelineSectionView(section)
              }
            }, (section: ExaminationTimelineSection) =>
              `section-${section.category}-${section.reports[0]?.id ?? 0}-${section.reports.length}-${this.listTick}`)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .onRefreshing(() => {
        this.refreshReports();
      })

      if (this.archiveMode === MedicalArchiveListMode.ACTIVE && this.memberID() > 0) {
        Column({ space: 0 }) {
          Divider()
            .width('100%')
            .height(0.5)
            .color(MEDICAL_LIST_DIVIDER)
          ExaminationReportsListBottomExtension({
            onManualAdd: () => {
              this.openManualAddSheet();
            },
            onUpload: () => {
              this.openUploadSheet();
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
    .bindSheet($$this.showOverlaySheet, this.overlaySheetContent, {
      height: SheetSize.LARGE,
      dragBar: this.overlaySheetDragBar(),
      showClose: false,
      backgroundColor: '#F2F2F7',
      onDisappear: () => {
        this.onOverlaySheetDisappear();
      }
    })
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

  /** 时间线分组头：仅展示分类与数量，对齐 iOS ExaminationReportTimelineSectionHeader（不可点击）。 */
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
              this.startDetailLoad(report.id);
            })
        }, (report: RemoteExaminationReportWithAttachments) =>
          `exam-${report.id}-${report.detailsLoaded ? 1 : 0}-${report.medExamDetails.length}-${this.listTick}`)
      }
      .width('100%')
    }
    .width('100%')
  }
}

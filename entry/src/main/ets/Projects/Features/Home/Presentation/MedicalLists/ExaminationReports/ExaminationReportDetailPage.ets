import { pasteboard } from '@kit.BasicServicesKit';
import { AppContainer } from '../../../../../../App/AppContainer';
import { BackendEnvironment } from '../../../../../../App/BackendEnvironment';
import { MedicalArchiveListMode } from '../../../../../Core/Networking/API/Medical/MedicalArchiveModels';
import { SparkMedicalQueryAPI } from '../../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import {
  RemoteExaminationReportWithAttachments,
  RemoteMedExamDetail
} from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { SparkMedicalShareAPI } from '../../../../../Core/Networking/API/Medical/MedicalShareAPI';
import { NotificationClient } from '../../../../../Core/Notification/Application/NotificationClient';
import { FileTransferService } from '../../../../../../Core/FileStorage/FileTransferService';
import { Logger } from '../../../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../../../Foundation/Logging/LogModule';
import { MedicalReportRecognitionDraft } from
  '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { ExamReportFormView } from
  '../../../../MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormView';
import { ExamReportFormContext } from
  '../../../../MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormContext';
import { ExamReportFormModeKind } from
  '../../../../MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormMode';
import { HomeViewModel } from '../../HomeViewModel';
import { ExaminationArchiveMutationService } from '../Shared/ExaminationArchiveMutationService';
import { nonEmptyText } from '../Shared/HealthExamFlagSupport';
import { ExaminationReportCategoryDetailPage } from './ExaminationReportCategoryDetailPage';
import {
  ExaminationReportCategory,
  resolveExaminationCategory
} from './ExaminationReportCategory';
import { ExaminationReportDraftMapping } from './ExaminationReportDraftMapping';
import { ExaminationSubitemDetailTarget } from './ExaminationReportDetailSupport';
import { ExaminationReportServerMutationService } from './ExaminationReportServerMutationService';
import { ExaminationReportSummaryDetailPage } from './ExaminationReportSummaryDetailPage';
import {
  MEDICAL_LIST_ACCENT,
  MEDICAL_LIST_HEADER_BG,
  MEDICAL_LIST_PAGE_BG
} from '../Shared/MedicalListPageChrome';

/** 检查报告详情导航栏右侧 ⋯ 菜单。独立组件挂载，避免 @BuilderParam this 错位。 */
@Component
struct ExaminationReportDetailHeaderTrailing {
  @Prop disabled: boolean = false;
  @Prop menuDisabled: boolean = false;
  @Prop showShare: boolean = false;
  @Prop showArchive: boolean = false;
  @Prop archiveTitle: string = '归档';
  onShare: () => void = () => {
  };
  onEdit: () => void = () => {
  };
  onArchive: () => void = () => {
  };
  onDelete: () => void = () => {
  };

  private buildMenuItems(): ExaminationReportDetailMenuItem[] {
    const items: ExaminationReportDetailMenuItem[] = [];
    if (this.showShare) {
      items.push(new ExaminationReportDetailMenuItem('分享', (): void => {
        if (!this.menuDisabled) {
          this.onShare();
        }
      }));
    }
    items.push(new ExaminationReportDetailMenuItem('编辑', (): void => {
      this.onEdit();
    }));
    if (this.showArchive) {
      items.push(new ExaminationReportDetailMenuItem(this.archiveTitle, (): void => {
        if (!this.menuDisabled) {
          this.onArchive();
        }
      }));
    }
    items.push(new ExaminationReportDetailMenuItem('删除', (): void => {
      if (!this.menuDisabled) {
        this.onDelete();
      }
    }));
    return items;
  }

  build() {
    Button('⋯')
      .fontSize(24)
      .fontColor(this.disabled ? '#AEAEB2' : MEDICAL_LIST_ACCENT)
      .backgroundColor(Color.Transparent)
      .width(44)
      .height(44)
      .enabled(!this.disabled)
      .bindMenu(this.buildMenuItems())
  }
}

export enum ExaminationReportDetailMode {
  SERVER = 'server',
  LOCAL_DRAFT = 'localDraft'
}

/** 宿主页弹层类型。同一节点仅挂一个 bindSheet，编辑/确认/明细统一由此承载。 */
enum ExaminationReportDetailOverlay {
  NONE = 'none',
  EDIT = 'edit',
  DELETE = 'delete',
  ARCHIVE = 'archive',
  SUBITEM = 'subitem'
}

const ACCEPTED_DETAIL_BUSINESS_TYPES: string[] = ['examination_report', 'examination'];
const DETAIL_BUSINESS_TYPE: string = 'examination_report';

class ExaminationReportDetailMenuItem {
  value: string = '';
  action: () => void = () => {};

  constructor(value: string, action: () => void) {
    this.value = value;
    this.action = action;
  }
}

/**
 * 检查报告详情宿主页。对齐 iOS `ExaminationReportDetailPage`：
 * 承接只读内容、编辑入口、分享/归档/删除，以及 localEdit / serverEdit 表单。
 */
@Component
export struct ExaminationReportDetailPage {
  homeVm?: HomeViewModel;
  @Prop detailMode: ExaminationReportDetailMode = ExaminationReportDetailMode.SERVER;
  @Prop initialReport: RemoteExaminationReportWithAttachments = new RemoteExaminationReportWithAttachments();
  @Prop reportCategory: ExaminationReportCategory = 'laboratory';
  @Prop useReportCategory: boolean = false;
  @Prop localAttachmentNames: string[] = [];
  sourceReportDraft?: MedicalReportRecognitionDraft;
  onBack?: () => void;
  onOpenSubitemDetail?: () => void;
  onDeleted?: (reportID: number) => void;
  onArchiveStateChanged?: (reportID: number, isArchived: boolean) => void;
  onSaved?: (report: RemoteExaminationReportWithAttachments) => void;
  onLocalDraftSaved?: (draft: MedicalReportRecognitionDraft) => void;
  onLocalDraftDeleted?: () => void;

  @State private report: RemoteExaminationReportWithAttachments = new RemoteExaminationReportWithAttachments();
  @State private category: ExaminationReportCategory = 'laboratory';
  @State private sourceDraft?: MedicalReportRecognitionDraft = undefined;
  @State private editFormSession: number = 0;
  @State private editFormContext: ExamReportFormContext = new ExamReportFormContext();
  @State private activeOverlay: ExaminationReportDetailOverlay = ExaminationReportDetailOverlay.NONE;
  @State private busy: boolean = false;
  @State private isLoadingDetails: boolean = false;
  @State private isPreparingShare: boolean = false;
  @State private errorText: string = '';
  @State private isArchived: boolean = false;
  @State private contentTick: number = 0;
  @State private subitemTarget: ExaminationSubitemDetailTarget = new ExaminationSubitemDetailTarget();

  private archiveMode: MedicalArchiveListMode = MedicalArchiveListMode.ACTIVE;
  private notification?: NotificationClient;
  private archiveService?: ExaminationArchiveMutationService;
  private mutationService?: ExaminationReportServerMutationService;
  private medicalQueryAPI?: SparkMedicalQueryAPI;
  private shareAPI?: SparkMedicalShareAPI;
  private fileTransferService?: FileTransferService;

  aboutToAppear(): void {
    const container = AppContainer.shared();
    const query = container?.backend.medicalQuery;
    this.notification = container?.notificationClient;
    if (query) {
      this.archiveService = new ExaminationArchiveMutationService(query.workflowAPI);
      this.mutationService = new ExaminationReportServerMutationService(
        query.workflowAPI,
        query
      );
      this.medicalQueryAPI = query;
    }
    if (container?.backend.medicalShare) {
      this.shareAPI = container.backend.medicalShare;
    }
    this.fileTransferService = container?.fileTransferService;
    const target = this.homeVm?.examinationDetailTarget;
    if (this.initialReport.id > 0 || (this.initialReport.itemName ?? '').length > 0) {
      this.report = this.initialReport.clone();
      this.isArchived = this.initialReport.isArchived;
    } else if (target) {
      this.report = target.clone();
      this.isArchived = target.isArchived;
    }
    if (this.sourceReportDraft) {
      this.sourceDraft = ExaminationReportDraftMapping.cloneDraft(this.sourceReportDraft);
    }
    this.category = this.useReportCategory ?
      this.reportCategory : resolveExaminationCategory(this.report);
    this.archiveMode = this.homeVm?.examinationDetailArchiveMode ?? MedicalArchiveListMode.ACTIVE;
    this.contentTick += 1;
    if (this.detailMode === ExaminationReportDetailMode.SERVER) {
      void this.loadDetailsIfNeeded();
    }
  }

  private titleText(): string {
    const name = nonEmptyText(this.report.itemName);
    if (name.length > 0) {
      return name;
    }
    return '检查报告';
  }

  /** 分享/归档/删除在忙时禁用；编辑不受详情懒加载影响。对齐 iOS 编辑入口始终可达。 */
  private destructiveActionsDisabled(): boolean {
    return this.busy || this.isPreparingShare;
  }

  /** 仅禁用 ⋯ 菜单中的分享/归档/删除，不禁用独立「编辑」按钮。 */
  private toolbarMenuDisabled(): boolean {
    return this.destructiveActionsDisabled() || this.isLoadingDetails;
  }

  private openEditForm(): void {
    if (this.busy) {
      return;
    }
    if (this.detailMode === ExaminationReportDetailMode.LOCAL_DRAFT) {
      this.editFormContext.modeKind = ExamReportFormModeKind.LOCAL_EDIT;
      this.editFormContext.existingDraft = this.currentSourceDraft();
      this.editFormContext.existingReport = undefined;
      this.editFormContext.mutationService = undefined;
      this.editFormContext.memberID = 0;
      this.editFormContext.medicalCaseID = undefined;
    } else {
      this.editFormContext.modeKind = ExamReportFormModeKind.SERVER_EDIT;
      this.editFormContext.existingReport = this.report;
      this.editFormContext.existingDraft = undefined;
      this.editFormContext.mutationService = this.mutationService;
      this.editFormContext.memberID = this.report.member;
      this.editFormContext.medicalCaseID = this.report.medicalRecord;
    }
    this.editFormSession += 1;
    this.activeOverlay = ExaminationReportDetailOverlay.EDIT;
    const fields = new LogFields();
    fields.operation = 'examination.detail.edit_open';
    fields.detail = `mode=${this.detailMode};session=${this.editFormSession};` +
      `draftItems=${this.currentSourceDraft().details.length}`;
    Logger.info('examination.detail.edit_open', LogModule.HOME, fields);
  }

  private closeEditForm(): void {
    if (this.activeOverlay === ExaminationReportDetailOverlay.EDIT) {
      this.activeOverlay = ExaminationReportDetailOverlay.NONE;
    }
  }

  private openOverlay(kind: ExaminationReportDetailOverlay): void {
    if (this.destructiveActionsDisabled()) {
      return;
    }
    this.activeOverlay = kind;
  }

  private closeOverlay(): void {
    this.activeOverlay = ExaminationReportDetailOverlay.NONE;
  }

  private overlaySheetVisible(): boolean {
    return this.activeOverlay !== ExaminationReportDetailOverlay.NONE;
  }

  private overlaySheetLarge(): boolean {
    return this.activeOverlay === ExaminationReportDetailOverlay.EDIT ||
      this.activeOverlay === ExaminationReportDetailOverlay.SUBITEM;
  }

  /**
   * 导航栏右侧 ⋯ 菜单项。对齐 iOS `ExaminationReportDetailPage` toolbar Menu：
   * 分享 → 编辑 → 归档/取消归档（仅服务端）→ 删除。
   */
  @Builder
  private detailHeader() {
    Column({ space: 0 }) {
      Row() {
        Text('‹ 返回')
          .fontSize(16)
          .fontColor(MEDICAL_LIST_ACCENT)
          .width(64)
          .onClick(() => {
            if (this.onBack) {
              this.onBack();
            }
          })
        Text(this.titleText())
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Row() {
          ExaminationReportDetailHeaderTrailing({
            disabled: this.destructiveActionsDisabled(),
            menuDisabled: this.toolbarMenuDisabled(),
            showShare: this.detailMode === ExaminationReportDetailMode.SERVER,
            showArchive: this.detailMode === ExaminationReportDetailMode.SERVER,
            archiveTitle: this.isArchived ? '取消归档' : '归档',
            onShare: () => {
              void this.prepareShare();
            },
            onEdit: () => {
              this.openEditForm();
            },
            onArchive: () => {
              this.openOverlay(ExaminationReportDetailOverlay.ARCHIVE);
            },
            onDelete: () => {
              this.openOverlay(ExaminationReportDetailOverlay.DELETE);
            }
          })
        }
        .width(64)
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    }
    .width('100%')
    .backgroundColor(MEDICAL_LIST_HEADER_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  private currentSourceDraft(): MedicalReportRecognitionDraft {
    if (this.sourceDraft) {
      return this.sourceDraft;
    }
    return ExaminationReportDraftMapping.examinationDraftFromReport(this.report);
  }

  private openLocalSubitem(target: ExaminationSubitemDetailTarget): void {
    this.subitemTarget = target;
    this.openOverlay(ExaminationReportDetailOverlay.SUBITEM);
  }

  private applyLocalDraftReport(updated: MedicalReportRecognitionDraft): void {
    let resolved = ExaminationReportDraftMapping.cloneDraft(updated);
    if (resolved.attachmentFileIds.length === 0 && this.sourceDraft) {
      resolved.attachmentFileIds = this.sourceDraft.attachmentFileIds.slice();
    }
    this.sourceDraft = resolved;
    this.report = ExaminationReportDraftMapping.remoteExaminationReportFromDraft(
      resolved,
      this.report.member,
      this.report.id,
      this.report.medicalRecord
    );
    this.category = resolveExaminationCategory(this.report);
    this.contentTick += 1;
    if (this.onLocalDraftSaved) {
      this.onLocalDraftSaved(resolved);
    }
    this.closeEditForm();
  }

  private applyServerDraftSaved(draft: MedicalReportRecognitionDraft): void {
    const merged = ExaminationReportDraftMapping.applyingRecognitionDraft(this.report, draft);
    merged.attachments = this.report.attachments.slice();
    merged.isArchived = this.report.isArchived;
    merged.archivedAt = this.report.archivedAt;
    this.report = merged;
    this.category = resolveExaminationCategory(this.report);
    this.contentTick += 1;
    if (this.homeVm) {
      this.homeVm.examinationDetailTarget = merged.clone();
    }
    if (this.onSaved) {
      this.onSaved(merged);
    }
    this.notification?.success('检查报告已更新', undefined, 'examination.detail.edit');
  }

  private filterAndSortDetails(rows: RemoteMedExamDetail[]): RemoteMedExamDetail[] {
    const filtered: RemoteMedExamDetail[] = [];
    for (let i = 0; i < rows.length; i++) {
      const normalized = rows[i].businessType.toLowerCase();
      let accepted = false;
      for (let j = 0; j < ACCEPTED_DETAIL_BUSINESS_TYPES.length; j++) {
        if (ACCEPTED_DETAIL_BUSINESS_TYPES[j] === normalized) {
          accepted = true;
          break;
        }
      }
      if (accepted || rows.length === 1) {
        filtered.push(rows[i]);
      }
    }
    filtered.sort((lhs: RemoteMedExamDetail, rhs: RemoteMedExamDetail): number => {
      if (lhs.sortOrder === rhs.sortOrder) {
        return lhs.id - rhs.id;
      }
      return lhs.sortOrder - rhs.sortOrder;
    });
    return filtered;
  }

  private async loadDetailsIfNeeded(): Promise<void> {
    if (this.detailMode !== ExaminationReportDetailMode.SERVER) {
      return;
    }
    if (this.report.detailsLoaded) {
      return;
    }
    const api = this.medicalQueryAPI;
    if (!api || this.isLoadingDetails) {
      return;
    }
    this.isLoadingDetails = true;
    this.errorText = '';
    try {
      const rows = await api.listMedExamDetails(
        this.report.member,
        DETAIL_BUSINESS_TYPE,
        this.report.id
      );
      const filtered = this.filterAndSortDetails(rows);
      const merged = this.report.clone();
      merged.detailsLoaded = true;
      merged.medExamDetails = filtered;
      this.report = merged;
      this.contentTick += 1;
      if (this.homeVm) {
        this.homeVm.examinationDetailTarget = merged.clone();
      }
      if (this.onSaved) {
        this.onSaved(merged);
      }
    } catch (e) {
      const message = `${e}`;
      this.errorText = message;
      const fields = new LogFields();
      fields.detail = message;
      Logger.warn('examination.detail.load_failed', LogModule.HOME, fields);
    } finally {
      this.isLoadingDetails = false;
    }
  }

  private async prepareShare(): Promise<void> {
    if (this.detailMode !== ExaminationReportDetailMode.SERVER || this.isPreparingShare) {
      return;
    }
    const api = this.shareAPI;
    if (!api) {
      this.notification?.error('分享服务未就绪', '分享失败', 'examination.detail.share');
      return;
    }
    this.isPreparingShare = true;
    this.errorText = '';
    try {
      const response = await api.createShare('examination_report', this.report.id);
      const shareCode = nonEmptyText(response.shareCode);
      let shareURL = nonEmptyText(response.shareUrl);
      if (shareURL.length === 0 && shareCode.length > 0) {
        shareURL = `${BackendEnvironment.current().shareWebBaseURL()}/share/${shareCode}`;
      }
      if (shareURL.length === 0) {
        throw new Error('未获取到分享链接');
      }
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, shareURL);
      await pasteboard.getSystemPasteboard().setData(pasteData);
      this.notification?.success('分享链接已复制', undefined, 'examination.detail.share');
    } catch (e) {
      const message = `${e}`;
      this.errorText = message;
      this.notification?.error(message, '分享失败', 'examination.detail.share');
    } finally {
      this.isPreparingShare = false;
    }
  }

  private async deleteReport(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (this.detailMode === ExaminationReportDetailMode.LOCAL_DRAFT) {
      if (this.onLocalDraftDeleted) {
        this.onLocalDraftDeleted();
      }
      if (this.onBack) {
        this.onBack();
      }
      return;
    }
    const service = this.archiveService;
    if (!service) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      await service.deleteReport(this.report.id);
      this.notification?.success('检查报告已删除', undefined, 'examination.detail');
      if (this.onDeleted) {
        this.onDeleted(this.report.id);
      }
      if (this.onBack) {
        this.onBack();
      }
    } catch (e) {
      const message = `${e}`;
      this.errorText = message;
      this.notification?.error(message, '删除失败', 'examination.detail');
      const fields = new LogFields();
      fields.detail = message;
      Logger.warn('examination.detail.delete_failed', LogModule.HOME, fields);
    } finally {
      this.busy = false;
      this.closeOverlay();
    }
  }

  private async toggleArchive(): Promise<void> {
    const service = this.archiveService;
    if (!service || this.busy || this.detailMode === ExaminationReportDetailMode.LOCAL_DRAFT) {
      return;
    }
    const nextArchived = !this.isArchived;
    this.busy = true;
    this.errorText = '';
    try {
      const updated = await service.setArchived(this.report.id, nextArchived);
      this.report = updated.clone();
      this.isArchived = updated.isArchived;
      this.contentTick += 1;
      this.notification?.success(
        nextArchived ? '已归档' : '已取消归档',
        undefined,
        'examination.detail.archive'
      );
      if (this.onArchiveStateChanged) {
        this.onArchiveStateChanged(updated.id, updated.isArchived);
      }
      if (this.onSaved) {
        this.onSaved(updated);
      }
      const belongs = this.archiveMode === MedicalArchiveListMode.ARCHIVED
        ? updated.isArchived
        : !updated.isArchived;
      if (!belongs && this.onBack) {
        this.onBack();
      }
    } catch (e) {
      const message = `${e}`;
      this.errorText = message;
      this.notification?.error(message, '操作失败', 'examination.detail.archive');
      const fields = new LogFields();
      fields.detail = message;
      Logger.warn('examination.detail.archive_failed', LogModule.HOME, fields);
    } finally {
      this.busy = false;
      this.closeOverlay();
    }
  }

  @Builder
  private editSheetContent() {
    ExamReportFormView({
      formSession: this.editFormSession,
      formContext: this.editFormContext,
      onLocalSubmit: (draft: MedicalReportRecognitionDraft) => {
        this.applyLocalDraftReport(draft);
      },
      onServerSaved: (draft: MedicalReportRecognitionDraft) => {
        this.applyServerDraftSaved(draft);
      },
      onCancel: () => {
        this.closeEditForm();
      }
    })
  }

  @Builder
  private overlaySheetContent() {
    if (this.activeOverlay === ExaminationReportDetailOverlay.EDIT) {
      this.editSheetContent()
    } else if (this.activeOverlay === ExaminationReportDetailOverlay.DELETE) {
      this.deleteSheetBuilder()
    } else if (this.activeOverlay === ExaminationReportDetailOverlay.ARCHIVE) {
      this.archiveSheetBuilder()
    } else if (this.activeOverlay === ExaminationReportDetailOverlay.SUBITEM) {
      this.subitemSheetContent()
    }
  }

  @Builder
  private detailChrome() {
    Column() {
      this.detailHeader()

      if (this.busy || this.isLoadingDetails || this.isPreparingShare) {
        LoadingProgress().width(24).height(24).margin({ bottom: 8 })
      }

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(13)
          .fontColor('#FF3B30')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
      }

      Scroll() {
        ExaminationReportSummaryDetailPage({
          homeVm: this.detailMode === ExaminationReportDetailMode.SERVER ? this.homeVm : undefined,
          report: this.report,
          category: this.category,
          contentTick: this.contentTick,
          localAttachmentNames: this.localAttachmentNames,
          fileTransferService: this.fileTransferService,
          onOpenSubitemDetail: this.detailMode === ExaminationReportDetailMode.SERVER ?
            this.onOpenSubitemDetail : undefined,
          onRequestSubitemDetail: this.detailMode === ExaminationReportDetailMode.LOCAL_DRAFT ?
            (target: ExaminationSubitemDetailTarget) => {
              this.openLocalSubitem(target);
            } : undefined,
          onAttachmentsUpdated: this.detailMode === ExaminationReportDetailMode.SERVER ?
            (merged: RemoteExaminationReportWithAttachments) => {
              this.report = merged;
              if (this.onSaved) {
                this.onSaved(merged);
              }
            } : undefined
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(MEDICAL_LIST_PAGE_BG)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private subitemSheetContent() {
    ExaminationReportCategoryDetailPage({
      subitemTarget: this.subitemTarget,
      useLocalTarget: true,
      onBack: () => {
        this.closeOverlay();
      }
    })
  }

  @Builder
  private deleteSheetBuilder() {
    Column({ space: 12 }) {
      Text('删除检查报告？')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
      Text('删除后该报告将从列表中移除。')
        .fontSize(14)
        .fontColor('#8E8E93')
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor(MEDICAL_LIST_PAGE_BG)
          .fontColor('#1C1C1E')
          .onClick(() => {
            this.closeOverlay();
          })
        Button('删除')
          .layoutWeight(1)
          .backgroundColor('#FF3B30')
          .fontColor(Color.White)
          .onClick(() => {
            this.deleteReport();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
  }

  @Builder
  private archiveSheetBuilder() {
    Column({ space: 12 }) {
      Text(this.isArchived ? '取消归档？' : '归档该报告？')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
      Text(this.isArchived ? '取消后将回到活跃列表。' : '归档后可在归档列表中查看。')
        .fontSize(14)
        .fontColor('#8E8E93')
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor(MEDICAL_LIST_PAGE_BG)
          .fontColor('#1C1C1E')
          .onClick(() => {
            this.closeOverlay();
          })
        Button(this.isArchived ? '取消归档' : '归档')
          .layoutWeight(1)
          .backgroundColor('#0A84FF')
          .fontColor(Color.White)
          .onClick(() => {
            this.toggleArchive();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
  }

  build() {
    Column() {
      this.detailChrome()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MEDICAL_LIST_PAGE_BG)
    .bindSheet(this.overlaySheetVisible(), this.overlaySheetContent, {
      height: this.overlaySheetLarge() ? SheetSize.LARGE : SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: this.activeOverlay !== ExaminationReportDetailOverlay.EDIT,
      backgroundColor: '#F2F2F7',
      onDisappear: () => {
        this.closeOverlay();
      }
    })
  }
}

import { pasteboard } from '@kit.BasicServicesKit';
import { AppContainer } from '../../../../../../App/AppContainer';
import { BackendEnvironment } from '../../../../../../App/BackendEnvironment';
import { Member } from '../../../../../Core/Domain/Entities/Member';
import { MedicalArchiveListMode } from '../../../../../Core/Networking/API/Medical/MedicalArchiveModels';
import { RemoteMedicineBox, RemoteManagedFile } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { SparkMedicalShareAPI } from '../../../../../Core/Networking/API/Medical/MedicalShareAPI';
import { SparkMedicalWorkflowAPI } from '../../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { NotificationClient } from '../../../../../Core/Notification/Application/NotificationClient';
import { FileTransferService } from '../../../../../../Core/FileStorage/FileTransferService';
import { ManagedFileRecord } from '../../../../../../Core/FileStorage/FileStorageModels';
import { MedicineBoxRecognitionDraft } from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentAttachmentUploader } from '../MedicalDocumentAttachmentUploader';
import { MedicineBoxArchiveMutationService } from '../Shared/MedicineBoxArchiveMutationService';
import { MedicalAttachmentGridPreview } from '../Shared/MedicalAttachmentComponents';
import { remoteManagedFileFromRecord } from '../Shared/MedicalAttachmentPreviewSupport';
import { nonEmptyText } from '../Shared/HealthExamFlagSupport';
import {
  MEDICAL_LIST_ACCENT,
  MEDICAL_LIST_HEADER_BG,
  MEDICAL_LIST_PAGE_BG
} from '../Shared/MedicalListPageChrome';
import { MedicineBoxDetailMode } from './MedicineBoxDetailMode';
import { MedicineBoxDraftMapping } from './MedicineBoxDraftMapping';
import {
  medicineBoxDetailValue,
  medicineBoxOwnershipDisplay,
  medicineBoxStockText,
  medicineStrengthDetailValue,
  medicineTypeText
} from './MedicineBoxDisplaySupport';
import { MedicineBoxFormModel } from './MedicineBoxFormModel';
import { MedicineBoxFormPage } from './MedicineBoxFormPage';
import { MedicineBoxMode } from './MedicineBoxMode';
import { MedicineBoxStatusBadge } from './MedicineBoxStatusBadge';
import { nilIfBlank } from './MedicalFileUtils';
import { HomeViewModel } from '../../HomeViewModel';

enum MedicineBoxDetailOverlay {
  NONE = 'none',
  EDIT = 'edit',
  DELETE = 'delete',
  ARCHIVE = 'archive'
}

class MedicineBoxDetailMenuItem {
  value: string = '';
  action: () => void = () => {};

  constructor(value: string, action: () => void) {
    this.value = value;
    this.action = action;
  }
}

/** 详情页右上角 ⋯ 菜单。独立组件挂载，避免 @BuilderParam this 错位。 */
@Component
struct MedicineBoxDetailHeaderTrailing {
  @Prop disabled: boolean = false;
  @Prop menuDisabled: boolean = false;
  @Prop showShare: boolean = false;
  @Prop showArchive: boolean = false;
  @Prop archiveTitle: string = '归档';
  onShare: () => void = () => {};
  onEdit: () => void = () => {};
  onArchive: () => void = () => {};
  onDelete: () => void = () => {};

  private buildMenuItems(): MedicineBoxDetailMenuItem[] {
    const items: MedicineBoxDetailMenuItem[] = [];
    if (this.showShare) {
      items.push(new MedicineBoxDetailMenuItem('分享', (): void => {
        if (!this.menuDisabled) {
          this.onShare();
        }
      }));
    }
    items.push(new MedicineBoxDetailMenuItem('编辑', (): void => {
      this.onEdit();
    }));
    if (this.showArchive) {
      items.push(new MedicineBoxDetailMenuItem(this.archiveTitle, (): void => {
        if (!this.menuDisabled) {
          this.onArchive();
        }
      }));
    }
    items.push(new MedicineBoxDetailMenuItem('删除', (): void => {
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

/** 详情行。独立组件挂载，避免 @BuilderParam 跨组件 this 错位。 */
@Component
struct MedicineBoxDetailRow {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop hideWhenEmpty: boolean = false;

  build() {
    if (this.hideWhenEmpty && this.value.length === 0) {
      Row().height(0)
    } else {
      Row() {
        Text(this.title)
          .fontSize(14)
          .fontColor('#666666')
          .layoutWeight(1)
        Text(this.value.length > 0 ? this.value : '—')
          .fontSize(14)
          .fontColor('#1C1C1E')
          .maxLines(3)
          .textAlign(TextAlign.End)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })
    }
  }
}

/** 编辑 Sheet 内容。独立组件挂载，避免 bindSheet @Builder 内 this 错位。 */
@Component
struct MedicineBoxDetailEditSheetContent {
  formTarget?: RemoteMedicineBox;
  @Prop entryMemberID: number = 0;
  @Prop cabinetMode: MedicineBoxMode = MedicineBoxMode.FAMILY;
  @Prop allowsHouseholdPublic: boolean = false;
  @Prop members: Member[] = [];
  @Prop detailMode: MedicineBoxDetailMode = MedicineBoxDetailMode.SERVER;
  workflow?: SparkMedicalWorkflowAPI;
  attachmentUploader?: MedicalDocumentAttachmentUploader;
  onClose: () => void = () => {
  };
  onSaveLocal: (model: MedicineBoxFormModel) => void = (_model: MedicineBoxFormModel) => {
  };
  onSaveServer: (model: MedicineBoxFormModel, id?: number) => Promise<void> =
    async (_model: MedicineBoxFormModel, _id?: number): Promise<void> => {
    };

  build() {
    MedicineBoxFormPage({
      existing: this.formTarget,
      entryMemberID: this.entryMemberID,
      mode: this.cabinetMode,
      allowsHouseholdPublic: this.allowsHouseholdPublic,
      members: this.members,
      workflow: this.workflow,
      attachmentUploader: this.attachmentUploader,
      onClose: () => {
        this.onClose();
      },
      onSave: async (model: MedicineBoxFormModel, id?: number): Promise<void> => {
        if (this.detailMode === MedicineBoxDetailMode.LOCAL_DRAFT) {
          this.onSaveLocal(model);
          return;
        }
        await this.onSaveServer(model, id);
      }
    })
  }
}

/**
 * 药箱详情页，对齐 iOS `MedicineBoxDetailPage`：
 * 分组展示、分享/编辑/归档/删除、服务端与本地草稿双模式、附件管理。
 */
@Component
export struct MedicineBoxDetailPage {
  homeVm?: HomeViewModel;
  @Prop detailMode: MedicineBoxDetailMode = MedicineBoxDetailMode.SERVER;
  @Prop initialBox: RemoteMedicineBox = new RemoteMedicineBox();
  @Prop entryMemberID: number = 0;
  @Prop memberOptions: Member[] = [];
  @Prop allowsHouseholdPublic: boolean = false;
  @Prop cabinetMode: MedicineBoxMode = MedicineBoxMode.FAMILY;
  @Prop archiveListMode: MedicalArchiveListMode = MedicalArchiveListMode.ACTIVE;
  sourceBoxDraft?: MedicineBoxRecognitionDraft;
  workflow?: SparkMedicalWorkflowAPI;
  fileTransferService?: FileTransferService;
  attachmentUploader?: MedicalDocumentAttachmentUploader;
  onBack?: () => void;
  onSaved?: (box: RemoteMedicineBox) => void;
  onDeleted?: (boxID: number) => void;
  onArchiveStateChanged?: (boxID: number, isArchived: boolean) => void;
  onLocalDraftSaved?: (draft: MedicineBoxRecognitionDraft) => void;
  onLocalDraftDeleted?: () => void;

  @State private currentBox: RemoteMedicineBox = new RemoteMedicineBox();
  @State private sourceDraft?: MedicineBoxRecognitionDraft = undefined;
  @State private activeOverlay: MedicineBoxDetailOverlay = MedicineBoxDetailOverlay.NONE;
  @State private showOverlaySheet: boolean = false;
  @State private formTarget?: RemoteMedicineBox = undefined;
  @State private busy: boolean = false;
  @State private isPreparingShare: boolean = false;
  @State private errorText: string = '';
  @State private isEditingAttachments: boolean = false;
  @State private attachmentsDirty: boolean = false;
  @State private contentTick: number = 0;
  @StorageProp('topRectHeight') private topRectHeightPx: number = 0;

  private archiveMutation?: MedicineBoxArchiveMutationService;
  private shareAPI?: SparkMedicalShareAPI;
  private notification?: NotificationClient;

  aboutToAppear(): void {
    const container = AppContainer.shared();
    this.notification = container?.notificationClient;
    if (!this.workflow) {
      this.workflow = container?.backend.medicalWorkflow;
    }
    if (!this.fileTransferService) {
      this.fileTransferService = container?.fileTransferService;
    }
    if (!this.attachmentUploader && container) {
      this.attachmentUploader = new MedicalDocumentAttachmentUploader(
        container.fileTransferService,
        (): number | undefined => container.accountRuntime.activeAccountId,
        (): number => container.sessionStore.generation
      );
    }
    if (this.workflow) {
      this.archiveMutation = new MedicineBoxArchiveMutationService(this.workflow);
    }
    if (container?.backend.medicalShare) {
      this.shareAPI = container.backend.medicalShare;
    }
    const target = this.homeVm?.medicineBoxDetailTarget;
    if (this.initialBox.id > 0 || this.initialBox.medicineName.length > 0) {
      this.currentBox = MedicineBoxDraftMapping.cloneBox(this.initialBox);
    } else if (target) {
      this.currentBox = MedicineBoxDraftMapping.cloneBox(target);
    }
    if (this.sourceBoxDraft) {
      this.sourceDraft = MedicineBoxDraftMapping.cloneDraft(this.sourceBoxDraft);
    }
    this.contentTick += 1;
  }

  private resolvedMemberOptions(): Member[] {
    if (this.memberOptions.length > 0) {
      return this.memberOptions;
    }
    return this.homeVm?.membersForUi() ?? [];
  }

  private resolvedEntryMemberID(): number {
    if (this.entryMemberID > 0) {
      return this.entryMemberID;
    }
    const data = this.homeVm?.completeData();
    if (data && data.memberId > 0) {
      return data.memberId;
    }
    if (this.currentBox.member !== undefined && this.currentBox.member !== null && this.currentBox.member > 0) {
      return this.currentBox.member;
    }
    const members = this.resolvedMemberOptions();
    if (members.length > 0) {
      return members[0].id;
    }
    return this.homeVm?.selectedMemberID ?? 0;
  }

  private showsHouseholdOwnership(): boolean {
    return this.allowsHouseholdPublic;
  }

  private titleText(): string {
    const name = nilIfBlank(this.currentBox.medicineName);
    if (name !== undefined) {
      return name;
    }
    if (this.detailMode === MedicineBoxDetailMode.LOCAL_DRAFT) {
      return '识别草稿';
    }
    return '药品详情';
  }

  private destructiveActionsDisabled(): boolean {
    return this.busy || this.isPreparingShare;
  }

  private toolbarMenuDisabled(): boolean {
    return this.destructiveActionsDisabled();
  }

  private showsAttachmentsSection(): boolean {
    if (this.detailMode === MedicineBoxDetailMode.SERVER) {
      return true;
    }
    return this.currentBox.attachments.length > 0;
  }

  /**
   * 首页 NavDestination：`expandSafeArea(TOP)` 已足够，勿叠加 topRectHeight。
   * AI 上传 ContentCover 内 Navigation push：`expandSafeArea` 不足，LOCAL_DRAFT 需 topRectHeight。
   */
  private headerTopPadding(): number {
    if (this.detailMode !== MedicineBoxDetailMode.LOCAL_DRAFT) {
      return 12;
    }
    if (this.topRectHeightPx > 0) {
      return this.getUIContext().px2vp(this.topRectHeightPx) + 12;
    }
    return 36;
  }

  private openOverlay(kind: MedicineBoxDetailOverlay): void {
    if (this.destructiveActionsDisabled()) {
      return;
    }
    this.activeOverlay = kind;
    this.showOverlaySheet = true;
  }

  /** 仅触发 Sheet 关闭动画；内容类型保留到 onDisappear，避免关闭过程中白屏。 */
  private dismissOverlaySheet(): void {
    this.showOverlaySheet = false;
  }

  private onOverlaySheetDisappear(): void {
    this.showOverlaySheet = false;
    this.activeOverlay = MedicineBoxDetailOverlay.NONE;
    this.formTarget = undefined;
  }

  private overlaySheetLarge(): boolean {
    return this.activeOverlay === MedicineBoxDetailOverlay.EDIT;
  }

  private overlaySheetDragBar(): boolean {
    return this.activeOverlay !== MedicineBoxDetailOverlay.EDIT;
  }

  private openEditForm(): void {
    if (this.busy) {
      return;
    }
    this.formTarget = MedicineBoxDraftMapping.cloneBox(this.currentBox);
    this.openOverlay(MedicineBoxDetailOverlay.EDIT);
  }

  private currentSourceDraft(): MedicineBoxRecognitionDraft {
    if (this.sourceDraft) {
      return this.sourceDraft;
    }
    return MedicineBoxDraftMapping.medicineBoxDraftFromBox(this.currentBox);
  }

  private applyLocalDraftBox(updated: MedicineBoxRecognitionDraft): void {
    let resolved = MedicineBoxDraftMapping.cloneDraft(updated);
    if (resolved.attachmentFileIds.length === 0 && this.sourceDraft) {
      resolved.attachmentFileIds = this.sourceDraft.attachmentFileIds.slice();
    }
    if ((resolved.sortOrder === undefined || resolved.sortOrder.trim().length === 0) && this.sourceDraft) {
      resolved.sortOrder = this.sourceDraft.sortOrder;
    }
    this.sourceDraft = resolved;
    const resolvedMemberID = this.resolvedEntryMemberID();
    const memberID = resolvedMemberID > 0 ? resolvedMemberID : (this.currentBox.member ?? 0);
    const previousAttachments = this.currentBox.attachments.slice();
    this.currentBox = MedicineBoxDraftMapping.remoteMedicineBoxFromDraft(
      resolved,
      memberID,
      this.currentBox.id
    );
    if (this.currentBox.attachments.length === 0 && previousAttachments.length > 0) {
      this.currentBox.attachments = previousAttachments;
    }
    this.contentTick += 1;
    if (this.onLocalDraftSaved) {
      this.onLocalDraftSaved(resolved);
    }
    this.dismissOverlaySheet();
  }

  private async saveLocalEdit(model: MedicineBoxFormModel): Promise<void> {
    const validation = model.validate();
    if (validation.length > 0) {
      this.errorText = validation;
      return;
    }
    this.applyLocalDraftBox(model.toRecognitionDraft());
  }

  private async saveServerEdit(model: MedicineBoxFormModel, existingID?: number): Promise<void> {
    const workflow = this.workflow;
    const memberID = this.resolvedEntryMemberID();
    if (!workflow || memberID <= 0 || existingID === undefined) {
      return;
    }
    const validation = model.validate();
    if (validation.length > 0) {
      this.errorText = validation;
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const payload = model.toPayload(memberID, this.cabinetMode === MedicineBoxMode.PERSONAL);
      const saved = await workflow.updateMedicineBox(existingID, payload);
      this.currentBox = MedicineBoxDraftMapping.cloneBox(saved);
      this.contentTick += 1;
      if (this.onSaved) {
        this.onSaved(saved);
      }
      this.notification?.success('药品已更新', undefined, 'home.medical.medicine_box.detail');
      this.dismissOverlaySheet();
    } catch (e) {
      this.errorText = `${e}`.substring(0, 160);
      this.notification?.error(this.errorText, '保存失败', 'home.medical.medicine_box.detail');
    } finally {
      this.busy = false;
    }
  }

  private async prepareShare(): Promise<void> {
    if (this.detailMode !== MedicineBoxDetailMode.SERVER || this.isPreparingShare) {
      return;
    }
    const api = this.shareAPI;
    if (!api) {
      this.notification?.error('分享服务未就绪', '分享失败', 'home.medical.medicine_box.detail.share');
      return;
    }
    this.isPreparingShare = true;
    this.errorText = '';
    try {
      const response = await api.createShare('medicine_box', this.currentBox.id);
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
      this.notification?.success('分享链接已复制', undefined, 'home.medical.medicine_box.detail.share');
    } catch (e) {
      const message = `${e}`;
      this.errorText = message;
      this.notification?.error(message, '分享失败', 'home.medical.medicine_box.detail.share');
    } finally {
      this.isPreparingShare = false;
    }
  }

  private async deleteCurrentBox(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (this.detailMode === MedicineBoxDetailMode.LOCAL_DRAFT) {
      if (this.onLocalDraftDeleted) {
        this.onLocalDraftDeleted();
      }
      if (this.onBack) {
        this.onBack();
      }
      return;
    }
    const mutation = this.archiveMutation;
    if (!mutation) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      await mutation.deleteBox(this.currentBox.id);
      this.notification?.success('药品已删除', undefined, 'home.medical.medicine_box.detail');
      if (this.onDeleted) {
        this.onDeleted(this.currentBox.id);
      }
      if (this.onBack) {
        this.onBack();
      }
    } catch (e) {
      const message = `${e}`;
      this.errorText = message;
      this.notification?.error(message, '删除失败', 'home.medical.medicine_box.detail');
    } finally {
      this.busy = false;
      this.dismissOverlaySheet();
    }
  }

  private async toggleArchive(): Promise<void> {
    const mutation = this.archiveMutation;
    if (!mutation || this.busy || this.detailMode === MedicineBoxDetailMode.LOCAL_DRAFT) {
      return;
    }
    const nextArchived = !this.currentBox.isArchived;
    this.busy = true;
    this.errorText = '';
    try {
      const updated = await mutation.setArchived(this.currentBox.id, nextArchived);
      this.currentBox = MedicineBoxDraftMapping.cloneBox(updated);
      this.contentTick += 1;
      this.notification?.success(
        nextArchived ? '已归档' : '已取消归档',
        undefined,
        'home.medical.medicine_box.detail.archive'
      );
      if (this.onArchiveStateChanged) {
        this.onArchiveStateChanged(updated.id, updated.isArchived);
      }
      if (this.onSaved) {
        this.onSaved(updated);
      }
      const belongs = this.archiveListMode === MedicalArchiveListMode.ARCHIVED
        ? updated.isArchived
        : !updated.isArchived;
      if (!belongs && this.onBack) {
        this.onBack();
      }
    } catch (e) {
      const message = `${e}`;
      this.errorText = message;
      this.notification?.error(message, '操作失败', 'home.medical.medicine_box.detail.archive');
    } finally {
      this.busy = false;
      this.dismissOverlaySheet();
    }
  }

  private finishAttachmentEditing(): void {
    this.isEditingAttachments = false;
    if (!this.attachmentsDirty) {
      return;
    }
    this.attachmentsDirty = false;
    if (this.onSaved) {
      this.onSaved(MedicineBoxDraftMapping.cloneBox(this.currentBox));
    }
  }

  private async handleAttachmentDeleted(fileID: number): Promise<void> {
    const transfer = this.fileTransferService;
    if (transfer) {
      try {
        await transfer.delete(fileID);
      } catch (_e) {
        this.errorText = '删除附件失败';
        return;
      }
    }
    this.currentBox.attachments = this.currentBox.attachments.filter(
      (file: RemoteManagedFile): boolean => file.id !== fileID
    );
    this.attachmentsDirty = true;
    this.contentTick += 1;
  }

  private async handleFileUploaded(record: ManagedFileRecord): Promise<void> {
    const transfer = this.fileTransferService;
    if (!transfer) {
      return;
    }
    try {
      await transfer.updateBusinessBinding(
        record.id,
        'medicine_box',
        `${this.currentBox.id}`
      );
      const newFile = remoteManagedFileFromRecord(
        record,
        'medicine_box',
        `${this.currentBox.id}`
      );
      this.currentBox.attachments = this.currentBox.attachments.concat([newFile]);
      this.attachmentsDirty = true;
      this.contentTick += 1;
    } catch (_e) {
      this.errorText = '上传附件失败';
    }
  }

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
          .key(`medicine-detail-title-${this.contentTick}`)
          .textAlign(TextAlign.Center)
        Row() {
          MedicineBoxDetailHeaderTrailing({
            disabled: this.destructiveActionsDisabled(),
            menuDisabled: this.toolbarMenuDisabled(),
            showShare: this.detailMode === MedicineBoxDetailMode.SERVER,
            showArchive: this.detailMode === MedicineBoxDetailMode.SERVER,
            archiveTitle: this.currentBox.isArchived ? '取消归档' : '归档',
            onShare: () => {
              void this.prepareShare();
            },
            onEdit: () => {
              this.openEditForm();
            },
            onArchive: () => {
              this.openOverlay(MedicineBoxDetailOverlay.ARCHIVE);
            },
            onDelete: () => {
              this.openOverlay(MedicineBoxDetailOverlay.DELETE);
            }
          })
        }
        .width(64)
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.headerTopPadding(), bottom: 8 })
    }
    .width('100%')
    .backgroundColor(MEDICAL_LIST_HEADER_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  private ownershipSection() {
    if (this.showsHouseholdOwnership()) {
      Column() {
        Text('归属')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .width('100%')
        MedicineBoxDetailRow({
          title: '绑定成员',
          value: medicineBoxOwnershipDisplay(this.currentBox, this.resolvedMemberOptions())
        })
      }
      .padding(14)
      .backgroundColor(Color.White)
      .borderRadius(14)
      .width('100%')
    }
  }

  @Builder
  private draftSourceSection() {
    if (this.detailMode === MedicineBoxDetailMode.LOCAL_DRAFT) {
      Column() {
        Text('来源')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .width('100%')
        MedicineBoxDetailRow({
          title: '草稿来源',
          value: '上传识别'
        })
      }
      .padding(14)
      .backgroundColor(Color.White)
      .borderRadius(14)
      .width('100%')
    }
  }

  @Builder
  private infoSection() {
    Column() {
      Text('药品信息')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      MedicineBoxDetailRow({
        title: '药品名称',
        value: this.currentBox.medicineName
      })
      MedicineBoxDetailRow({
        title: '药品类型',
        value: medicineTypeText(this.currentBox.medicineType),
        hideWhenEmpty: true
      })
      MedicineBoxDetailRow({
        title: '品牌',
        value: medicineBoxDetailValue(this.currentBox.brandName),
        hideWhenEmpty: true
      })
      MedicineBoxDetailRow({
        title: '剂型',
        value: medicineBoxDetailValue(this.currentBox.dosageForm),
        hideWhenEmpty: true
      })
      MedicineBoxDetailRow({
        title: '规格',
        value: medicineStrengthDetailValue(this.currentBox.strength),
        hideWhenEmpty: true
      })
      MedicineBoxDetailRow({
        title: '剂量单位',
        value: medicineBoxDetailValue(this.currentBox.doseUnit),
        hideWhenEmpty: true
      })
    }
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(14)
    .width('100%')
  }

  @Builder
  private stockSection() {
    Column() {
      Text('库存')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      this.stockSectionBody()
    }
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(14)
    .width('100%')
  }

  private stockStatusText(): string {
    const badge = MedicineBoxStatusBadge.resolve(this.currentBox);
    return badge ? badge.text : '';
  }

  private stockStatusColor(): string {
    const badge = MedicineBoxStatusBadge.resolve(this.currentBox);
    return badge ? badge.color : '#8E8E93';
  }

  @Builder
  private stockSectionBody() {
    Row() {
      Text('总数量')
        .fontSize(14)
        .fontColor('#666666')
        .layoutWeight(1)
      Text(medicineBoxStockText(this.currentBox))
        .fontSize(14)
        .fontColor('#1C1C1E')
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })

    if ((this.currentBox.expireDate ?? '').length > 0) {
      Row() {
        Text('有效期')
          .fontSize(14)
          .fontColor('#666666')
          .layoutWeight(1)
        Text(this.currentBox.expireDate ?? '')
          .fontSize(14)
          .fontColor('#1C1C1E')
      }
      .width('100%')
      .padding({ top: 0, bottom: 10 })
    }

    if (this.stockStatusText().length > 0) {
      Row() {
        Blank().layoutWeight(1)
        Text(this.stockStatusText())
          .fontSize(12)
          .fontColor(this.stockStatusColor())
      }
      .width('100%')
    }
  }

  @Builder
  private notesSection() {
    if ((this.currentBox.notes ?? '').trim().length > 0) {
      Column() {
        Text('备注')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .width('100%')
        Text(this.currentBox.notes)
          .fontSize(14)
          .fontColor('#333333')
          .width('100%')
          .margin({ top: 4 })
      }
      .padding(14)
      .backgroundColor(Color.White)
      .borderRadius(14)
      .width('100%')
    }
  }

  @Builder
  private attachmentsSection() {
    if (this.showsAttachmentsSection()) {
      Column() {
        Row() {
          Text('附件')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
          if (this.detailMode === MedicineBoxDetailMode.SERVER) {
            Text(this.isEditingAttachments ? '完成' : '管理')
              .fontSize(14)
              .fontColor(MEDICAL_LIST_ACCENT)
              .onClick(() => {
                if (this.isEditingAttachments) {
                  this.finishAttachmentEditing();
                } else {
                  this.isEditingAttachments = true;
                }
              })
          }
        }
        .width('100%')

        if (this.currentBox.attachments.length === 0) {
          if (this.detailMode === MedicineBoxDetailMode.SERVER && this.isEditingAttachments) {
            MedicalAttachmentGridPreview({
              attachments: this.currentBox.attachments,
              isEditing: true,
              fileTransferService: this.fileTransferService,
              onDeleted: (fileID: number) => {
                void this.handleAttachmentDeleted(fileID);
              },
              onFileUploaded: (record: ManagedFileRecord) => {
                void this.handleFileUploaded(record);
              }
            })
              .margin({ top: 10 })
          }
        } else {
          MedicalAttachmentGridPreview({
            attachments: this.currentBox.attachments,
            isEditing: this.detailMode === MedicineBoxDetailMode.SERVER && this.isEditingAttachments,
            fileTransferService: this.fileTransferService,
            onDeleted: this.detailMode === MedicineBoxDetailMode.SERVER ?
              (fileID: number) => {
                void this.handleAttachmentDeleted(fileID);
              } : undefined,
            onFileUploaded: this.detailMode === MedicineBoxDetailMode.SERVER ?
              (record: ManagedFileRecord) => {
                void this.handleFileUploaded(record);
              } : undefined
          })
            .margin({ top: 10 })
        }
      }
      .padding(14)
      .backgroundColor(Color.White)
      .borderRadius(14)
      .width('100%')
    }
  }

  @Builder
  private editSheetContent() {
    MedicineBoxDetailEditSheetContent({
      formTarget: this.formTarget,
      entryMemberID: this.resolvedEntryMemberID(),
      cabinetMode: this.cabinetMode,
      allowsHouseholdPublic: this.allowsHouseholdPublic,
      members: this.resolvedMemberOptions(),
      detailMode: this.detailMode,
      workflow: this.workflow,
      attachmentUploader: this.attachmentUploader,
      onClose: () => {
        this.dismissOverlaySheet();
      },
      onSaveLocal: (model: MedicineBoxFormModel) => {
        void this.saveLocalEdit(model);
      },
      onSaveServer: (model: MedicineBoxFormModel, id?: number) => {
        return this.saveServerEdit(model, id);
      }
    })
  }

  @Builder
  private deleteSheetBuilder() {
    Column({ space: 12 }) {
      Text('删除药品？')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
      Text(this.detailMode === MedicineBoxDetailMode.LOCAL_DRAFT
        ? '删除后将移除当前识别草稿。'
        : '删除后无法从当前药箱恢复。')
        .fontSize(14)
        .fontColor('#8E8E93')
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor(MEDICAL_LIST_PAGE_BG)
          .fontColor('#1C1C1E')
          .onClick(() => {
            this.dismissOverlaySheet();
          })
        Button('删除')
          .layoutWeight(1)
          .backgroundColor('#FF3B30')
          .fontColor(Color.White)
          .onClick(() => {
            void this.deleteCurrentBox();
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
      Text(this.currentBox.isArchived ? '取消归档？' : '归档该药品？')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
      Text(this.currentBox.isArchived ? '取消后将回到活跃列表。' : '归档后可在归档列表中查看。')
        .fontSize(14)
        .fontColor('#8E8E93')
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor(MEDICAL_LIST_PAGE_BG)
          .fontColor('#1C1C1E')
          .onClick(() => {
            this.dismissOverlaySheet();
          })
        Button(this.currentBox.isArchived ? '取消归档' : '归档')
          .layoutWeight(1)
          .backgroundColor('#0A84FF')
          .fontColor(Color.White)
          .onClick(() => {
            void this.toggleArchive();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
  }

  @Builder
  private overlaySheetContent() {
    if (this.activeOverlay === MedicineBoxDetailOverlay.EDIT) {
      this.editSheetContent()
    } else if (this.activeOverlay === MedicineBoxDetailOverlay.DELETE) {
      this.deleteSheetBuilder()
    } else if (this.activeOverlay === MedicineBoxDetailOverlay.ARCHIVE) {
      this.archiveSheetBuilder()
    }
  }

  build() {
    Column() {
      this.detailHeader()

      if (this.busy || this.isPreparingShare) {
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
        Column({ space: 12 }) {
          this.ownershipSection()
          this.draftSourceSection()
          this.infoSection()
          if (this.detailMode === MedicineBoxDetailMode.SERVER) {
            this.stockSection()
          }
          this.notesSection()
          this.attachmentsSection()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 24 })
        .key(`medicine-detail-${this.contentTick}`)
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(MEDICAL_LIST_PAGE_BG)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor(MEDICAL_LIST_PAGE_BG)
    .bindSheet($$this.showOverlaySheet, this.overlaySheetContent, {
      height: this.overlaySheetLarge() ? SheetSize.LARGE : SheetSize.FIT_CONTENT,
      dragBar: this.overlaySheetDragBar(),
      showClose: this.overlaySheetDragBar(),
      backgroundColor: '#F2F2F7',
      onDisappear: () => {
        this.onOverlaySheetDisappear();
      }
    })
  }
}

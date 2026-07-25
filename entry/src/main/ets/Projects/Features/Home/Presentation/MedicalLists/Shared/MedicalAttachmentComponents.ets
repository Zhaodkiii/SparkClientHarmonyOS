import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppContainer } from '../../../../../../App/AppContainer';
import { RemoteManagedFile } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { FileDownloadOptions, FileUploadRequest, ManagedFileRecord } from '../../../../../../Core/FileStorage/FileStorageModels';
import { FileTransferService } from '../../../../../../Core/FileStorage/FileTransferService';
import { FilePreviewInput } from '../../../../../Core/UI/FilePreview/FilePreviewInput';
import { UnifiedFilePreview } from '../../../../../Core/UI/FilePreview/UnifiedFilePreview';
import {
  MedicalDocumentFilePreviewSquareCard
} from '../MedicineBox/MedicalDocumentFilePreviewSquareCard';
import { HarmonyMedicalDocumentFilePicker } from '../../../../MedicalDocumentUpload/Infrastructure/HarmonyMedicalDocumentFilePicker';
import { MedicalUploadLocalFile } from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentUploadModels';
import { MedicalAttachmentPreviewAdapter } from './MedicalAttachmentPreviewAdapter';
import {
  numberedAttachmentDisplayName,
  remoteFileTintColor,
  toManagedFileRecordFromRemote
} from './MedicalAttachmentPreviewSupport';

class GridAttachmentUploadCard {
  cardId: string = '';
  sourceUri: string = '';
  displayName: string = '';
  mimeType: string = 'application/octet-stream';
  progress: number = 0;
  errorMessage: string = '';

  isImage(): boolean {
    const mime = this.mimeType.toLowerCase();
    if (mime.indexOf('image') >= 0) {
      return true;
    }
    const dot = this.displayName.lastIndexOf('.');
    const ext = dot >= 0 ? this.displayName.slice(dot + 1).toLowerCase() : '';
    return ['png', 'jpg', 'jpeg', 'heic', 'webp'].indexOf(ext) >= 0;
  }
}

/** 对齐 iOS `MedicalAttachmentIconView`：附件数量角标入口。 */
@Component
export struct MedicalAttachmentIconView {
  @Prop count: number = 0;
  @Prop isExpanded: boolean = false;
  onTap?: () => void;

  build() {
    Button({ type: ButtonType.Normal }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.paperclip'))
            .fontSize(20)
            .fontColor([this.count > 0 ? '#0A84FF' : '#8E8E93'])
          Text('附件')
            .fontSize(10)
            .fontColor('#8E8E93')
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)

        if (this.count > 0) {
          Text(`${this.count}`)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ left: 4, right: 4 })
            .minFontSize(10)
            .backgroundColor('#0A84FF')
            .borderRadius(9)
            .offset({ x: 8, y: -4 })
        }
      }
    }
    .backgroundColor(Color.Transparent)
    .enabled(this.count > 0)
    .opacity(this.count > 0 ? 1 : 0.55)
    .onClick(() => this.onTap?.())
  }
}

/** 对齐 iOS `MedicalAttachmentListView`：列表点击后下载并统一预览。 */
@Component
export struct MedicalAttachmentListView {
  @Prop attachments: RemoteManagedFile[] = [];
  fileTransferService?: FileTransferService;

  @State private showPreviewSheet: boolean = false;
  @State private previewInputs: FilePreviewInput[] = [];
  @State private downloadingId: number = -1;

  private attachmentIndex(file: RemoteManagedFile): number {
    for (let i = 0; i < this.attachments.length; i++) {
      if (this.attachments[i].id === file.id) {
        return i;
      }
    }
    return 0;
  }

  private async openAttachment(file: RemoteManagedFile, index: number): Promise<void> {
    const transfer = this.fileTransferService;
    const managed = toManagedFileRecordFromRemote(file);
    if (!transfer || !managed) {
      return;
    }
    if (this.downloadingId === file.id) {
      return;
    }
    this.downloadingId = file.id;
    try {
      const cached = await transfer.cachedURL(managed, managed.fileMd5);
      let localPath = cached?.localPath ?? '';
      if (localPath.length === 0) {
        const options = new FileDownloadOptions();
        options.expectedMd5 = managed.fileMd5;
        const handle = await transfer.download(managed, options);
        localPath = handle.localPath;
      }
      if (localPath.length === 0) {
        return;
      }
      this.previewInputs = [
        MedicalAttachmentPreviewAdapter.fromRemoteAttachment(file, localPath, index)
      ];
      this.showPreviewSheet = true;
    } catch (_e) {
      // 下载失败静默，对齐 iOS logger.warning
    } finally {
      if (this.downloadingId === file.id) {
        this.downloadingId = -1;
      }
    }
  }

  @Builder
  private previewSheet() {
    UnifiedFilePreview({
      inputs: this.previewInputs,
      startIndex: 0,
      onClose: () => {
        this.showPreviewSheet = false;
      }
    })
  }

  build() {
    Column({ space: 8 }) {
      ForEach(this.attachments, (file: RemoteManagedFile) => {
        Row({ space: 12 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.doc_text'))
              .fontSize(18)
              .fontColor([remoteFileTintColor(file)])
          }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#F2F2F7')
          .borderRadius(10)

          Column({ space: 4 }) {
            Text(numberedAttachmentDisplayName(this.attachmentIndex(file)))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1C1C1E')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if ((file.mimeType ?? '').length > 0) {
              Text(file.mimeType ?? '')
                .fontSize(12)
                .fontColor('#8E8E93')
                .maxLines(1)
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (this.downloadingId === file.id) {
            LoadingProgress().width(18).height(18)
          } else {
            Text('›')
              .fontSize(18)
              .fontColor('#C7C7CC')
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#F8F8FA')
        .borderRadius(12)
        .onClick(() => {
          void this.openAttachment(file, this.attachmentIndex(file));
        })
      }, (file: RemoteManagedFile): string => `att-list-${file.id}`)
    }
    .width('100%')
    .bindSheet(this.showPreviewSheet, this.previewSheet, {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: true,
      onDisappear: () => {
        this.showPreviewSheet = false;
      }
    })
  }
}

/** 对齐 iOS `MedicalAttachmentGridPreview`：网格展示 + 自动下载 + 点击预览。 */
@Component
export struct MedicalAttachmentGridPreview {
  @Prop @Watch('onAttachmentsPropChanged') attachments: RemoteManagedFile[] = [];
  @Prop isEditing: boolean = false;
  fileTransferService?: FileTransferService;
  onDeleted?: (fileID: number) => void;
  onFileUploaded?: (record: ManagedFileRecord) => void;

  @State private cachedPaths: string[] = [];
  @State private cachedIds: number[] = [];
  @State private downloadingIds: number[] = [];
  @State private uploadCards: GridAttachmentUploadCard[] = [];
  @State private showPreviewSheet: boolean = false;
  @State private previewInputs: FilePreviewInput[] = [];
  @State private previewStartIndex: number = 0;

  aboutToAppear(): void {
    void this.downloadAllAutomatically();
  }

  private onAttachmentsPropChanged(): void {
    void this.downloadAllAutomatically();
  }

  private attachmentIndex(file: RemoteManagedFile): number {
    for (let i = 0; i < this.attachments.length; i++) {
      if (this.attachments[i].id === file.id) {
        return i;
      }
    }
    return 0;
  }

  private pathFor(fileId: number): string {
    for (let i = 0; i < this.cachedIds.length; i++) {
      if (this.cachedIds[i] === fileId) {
        return this.cachedPaths[i];
      }
    }
    return '';
  }

  private setCachedPath(fileId: number, localPath: string): void {
    for (let i = 0; i < this.cachedIds.length; i++) {
      if (this.cachedIds[i] === fileId) {
        this.cachedPaths[i] = localPath;
        return;
      }
    }
    this.cachedIds.push(fileId);
    this.cachedPaths.push(localPath);
  }

  private isDownloading(fileId: number): boolean {
    return this.downloadingIds.indexOf(fileId) >= 0;
  }

  private markDownloading(fileId: number, downloading: boolean): void {
    const index = this.downloadingIds.indexOf(fileId);
    if (downloading && index < 0) {
      this.downloadingIds.push(fileId);
    } else if (!downloading && index >= 0) {
      this.downloadingIds.splice(index, 1);
    }
  }

  private previewInputForGrid(file: RemoteManagedFile, index: number): FilePreviewInput {
    const localPath = this.pathFor(file.id);
    return MedicalAttachmentPreviewAdapter.fromRemoteAttachment(file, localPath, index);
  }

  private async downloadAllAutomatically(): Promise<void> {
    const transfer = this.fileTransferService;
    if (!transfer) {
      return;
    }
    for (let i = 0; i < this.attachments.length; i++) {
      const file = this.attachments[i];
      if (this.pathFor(file.id).length > 0) {
        continue;
      }
      await this.ensureDownloaded(file);
    }
  }

  private async ensureDownloaded(file: RemoteManagedFile): Promise<string> {
    const existing = this.pathFor(file.id);
    if (existing.length > 0) {
      return existing;
    }
    const transfer = this.fileTransferService;
    const managed = toManagedFileRecordFromRemote(file);
    if (!transfer || !managed) {
      return '';
    }
    this.markDownloading(file.id, true);
    try {
      const cached = await transfer.cachedURL(managed, managed.fileMd5);
      if (cached && cached.localPath.length > 0) {
        this.setCachedPath(file.id, cached.localPath);
        return cached.localPath;
      }
      const options = new FileDownloadOptions();
      options.expectedMd5 = managed.fileMd5;
      const handle = await transfer.download(managed, options);
      this.setCachedPath(file.id, handle.localPath);
      return handle.localPath;
    } catch (_e) {
      return '';
    } finally {
      this.markDownloading(file.id, false);
    }
  }

  private async openAttachment(file: RemoteManagedFile, index: number): Promise<void> {
    if (this.isEditing) {
      return;
    }
    const localPath = await this.ensureDownloaded(file);
    if (localPath.length === 0) {
      return;
    }
    const inputs: FilePreviewInput[] = [];
    let startIndex = 0;
    let previewIndex = 0;
    for (let i = 0; i < this.attachments.length; i++) {
      const attachment = this.attachments[i];
      const path = this.pathFor(attachment.id);
      if (path.length === 0) {
        continue;
      }
      if (attachment.id === file.id) {
        startIndex = previewIndex;
      }
      inputs.push(MedicalAttachmentPreviewAdapter.fromRemoteAttachment(attachment, path, i));
      previewIndex += 1;
    }
    if (inputs.length === 0) {
      inputs.push(MedicalAttachmentPreviewAdapter.fromRemoteAttachment(file, localPath, index));
      startIndex = 0;
    }
    this.previewInputs = inputs;
    this.previewStartIndex = startIndex;
    this.showPreviewSheet = true;
  }

  private confirmDelete(fileId: number): void {
    promptAction.showDialog({
      title: '确认删除此附件？',
      message: '删除后无法恢复。',
      buttons: [{ text: '取消', color: '#0A84FF' }, { text: '删除', color: '#FF3B30' }]
    }).then((result) => {
      if (result.index === 1 && this.onDeleted) {
        this.onDeleted(fileId);
      }
    });
  }

  private removeUploadCard(cardId: string): void {
    this.uploadCards = this.uploadCards.filter((card: GridAttachmentUploadCard): boolean => card.cardId !== cardId);
  }

  private markUploadError(cardId: string, message: string): void {
    const next = this.uploadCards.slice();
    for (let i = 0; i < next.length; i++) {
      if (next[i].cardId === cardId) {
        next[i].errorMessage = message;
      }
    }
    this.uploadCards = next;
  }

  private updateUploadProgress(cardId: string, progress: number): void {
    const next = this.uploadCards.slice();
    for (let i = 0; i < next.length; i++) {
      if (next[i].cardId === cardId) {
        next[i].progress = progress;
      }
    }
    this.uploadCards = next;
  }

  private async pickAndUpload(): Promise<void> {
    if (!this.onFileUploaded || !this.fileTransferService) {
      return;
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const files: MedicalUploadLocalFile[] =
        await HarmonyMedicalDocumentFilePicker.pickImagesAndPDFs(context, 1);
      if (files.length === 0) {
        return;
      }
      const file: MedicalUploadLocalFile = files[0];
      await this.startUpload(file.uri, file.displayName, file.mimeType);
    } catch (_e) {
      // 用户取消选择
    }
  }

  private async startUpload(sourceUri: string, displayName: string, mimeType: string): Promise<void> {
    const transfer = this.fileTransferService;
    const onUploaded = this.onFileUploaded;
    if (!transfer || !onUploaded) {
      return;
    }
    const container = AppContainer.shared();
    const accountId = container?.accountRuntime.activeAccountId ?? 0;
    if (accountId <= 0) {
      return;
    }
    const cardId = `grid_upload_${Date.now()}`;
    const card = new GridAttachmentUploadCard();
    card.cardId = cardId;
    card.sourceUri = sourceUri;
    card.displayName = displayName;
    card.mimeType = mimeType;
    this.uploadCards = this.uploadCards.concat([card]);
    try {
      const request = new FileUploadRequest();
      request.transferId = cardId;
      request.accountId = accountId;
      request.generation = container?.sessionStore.generation ?? 0;
      request.sourceUri = sourceUri;
      request.originalName = displayName;
      request.mimeType = mimeType;
      request.businessType = 'medical_attachment';
      request.businessId = '';
      request.isPublic = false;
      const record = await transfer.upload(request, (snapshot) => {
        this.updateUploadProgress(cardId, snapshot.progress);
      });
      this.removeUploadCard(cardId);
      this.setCachedPath(record.id, sourceUri);
      onUploaded(record);
    } catch (_e) {
      this.markUploadError(cardId, '上传失败');
    }
  }

  @Builder
  private previewSheet() {
    UnifiedFilePreview({
      inputs: this.previewInputs,
      startIndex: this.previewStartIndex,
      onClose: () => {
        this.showPreviewSheet = false;
      }
    })
  }

  @Builder
  private uploadingCard(card: GridAttachmentUploadCard) {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#E5E5EA')
        .borderRadius(12)
      Column({ space: 8 }) {
        if (card.errorMessage.length > 0) {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill'))
            .fontSize(24)
            .fontColor([Color.White])
          Text('上传失败')
            .fontSize(11)
            .fontColor(Color.White)
          Button('关闭')
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor('#FFFFFF40')
            .onClick(() => {
              this.removeUploadCard(card.cardId);
            })
        } else {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(Color.White)
          Text(`${Math.round(card.progress * 100)}%`)
            .fontSize(11)
            .fontColor(Color.White)
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#0000006B')
      .borderRadius(12)
    }
    .aspectRatio(1)
  }

  @Builder
  private addAttachmentCell() {
    Column({ space: 8 }) {
      Text('+')
        .fontSize(28)
        .fontColor('#0A84FF')
      Text('添加')
        .fontSize(11)
        .fontColor('#8E8E93')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F2F2F7')
    .borderRadius(12)
    .border({ width: 1, color: '#0A84FF59', style: BorderStyle.Dashed })
    .aspectRatio(1)
    .onClick(() => {
      void this.pickAndUpload();
    })
  }

  @Builder
  private gridCard(file: RemoteManagedFile, index: number) {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.isDownloading(file.id)) {
        Column({ space: 8 }) {
          LoadingProgress().width(24).height(24)
          Text('下载中…')
            .fontSize(11)
            .fontColor('#8E8E93')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F2F2F7')
        .borderRadius(12)
      } else {
        MedicalDocumentFilePreviewSquareCard({
          item: this.previewInputForGrid(file, index),
          showDelete: false,
          onPreview: () => {
            void this.openAttachment(file, index);
          }
        })
      }

      if (this.isEditing && this.onDeleted) {
        Button({ type: ButtonType.Circle }) {
          Text('×')
            .fontSize(14)
            .fontColor(Color.White)
        }
        .width(24)
        .height(24)
        .backgroundColor('#FF3B30')
        .offset({ x: 6, y: -6 })
        .onClick(() => {
          this.confirmDelete(file.id);
        })
      }
    }
    .aspectRatio(1)
  }

  build() {
    Grid() {
      ForEach(this.attachments, (file: RemoteManagedFile) => {
        GridItem() {
          this.gridCard(file, this.attachmentIndex(file))
        }
      }, (file: RemoteManagedFile): string => `att-grid-${file.id}`)

      ForEach(this.uploadCards, (card: GridAttachmentUploadCard) => {
        GridItem() {
          this.uploadingCard(card)
        }
      }, (card: GridAttachmentUploadCard): string => card.cardId)

      if (this.isEditing && this.onFileUploaded) {
        GridItem() {
          this.addAttachmentCell()
        }
      }
    }
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(12)
    .rowsGap(12)
    .width('100%')
    .bindSheet(this.showPreviewSheet, this.previewSheet, {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: true,
      onDisappear: () => {
        this.showPreviewSheet = false;
      }
    })
  }
}

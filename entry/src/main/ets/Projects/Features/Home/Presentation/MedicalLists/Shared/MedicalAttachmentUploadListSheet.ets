import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import {
  MedicalAttachmentUploadAutoPresentation,
  MedicalAttachmentUploadKindConfig,
  MedicalDocumentKind,
  medicalAttachmentUploadConfig
} from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentKind';
import {
  MedicalUploadLocalFile
} from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentUploadModels';
import {
  HarmonyMedicalDocumentFilePicker
} from '../../../../MedicalDocumentUpload/Infrastructure/HarmonyMedicalDocumentFilePicker';
import {
  MedicalDocumentFilePreviewSquareCard
} from '../MedicineBox/MedicalDocumentFilePreviewSquareCard';
import { FilePreviewInput } from '../../../../../Core/UI/FilePreview/FilePreviewInput';
import { UnifiedFilePreview } from '../../../../../Core/UI/FilePreview/UnifiedFilePreview';
import {
  MEDICAL_LIST_DIVIDER,
  MEDICAL_LIST_HEADER_BG,
  MEDICAL_LIST_PAGE_BG,
  MedicalUploadHeaderLeadingStyle,
  MedicalUploadPageHeaderChrome
} from './MedicalListPageChrome';

type MedicalAttachmentUploadEntry = 'camera' | 'photo' | 'file';

@Component
export struct MedicalAttachmentUploadListSheet {
  @Prop documentKind: MedicalDocumentKind = MedicalDocumentKind.MEDICAL_REPORT;
  onCancel: () => void = () => {};
  onConfirm: (files: MedicalUploadLocalFile[]) => void = () => {};

  @State private localFiles: MedicalUploadLocalFile[] = [];
  @State private isPicking: boolean = false;
  @State private showPreview: boolean = false;
  @State private previewInputs: FilePreviewInput[] = [];
  @State private previewIndex: number = 0;
  @State private didAutoPresent: boolean = false;

  private config(): MedicalAttachmentUploadKindConfig {
    return medicalAttachmentUploadConfig(this.documentKind);
  }

  aboutToAppear(): void {
    if (this.didAutoPresent) {
      return;
    }
    this.didAutoPresent = true;
    setTimeout((): void => {
      this.presentDefaultEntry();
    }, 500);
  }

  private remainingSlots(): number {
    const config = this.config();
    return Math.max(0, config.maxFileCount - this.localFiles.length);
  }

  private canStart(): boolean {
    return this.localFiles.length > 0 && !this.isPicking;
  }

  private async presentDefaultEntry(): Promise<void> {
    const auto = this.config().autoPresentation;
    if (auto === MedicalAttachmentUploadAutoPresentation.PHOTO_LIBRARY) {
      await this.pickPhotos();
      return;
    }
    if (auto === MedicalAttachmentUploadAutoPresentation.FILE_PICKER) {
      await this.pickFiles();
      return;
    }
    this.presentCamera();
  }

  private ensureCanAdd(): boolean {
    if (this.remainingSlots() > 0) {
      return true;
    }
    this.showLimitToast();
    return false;
  }

  private showLimitToast(): void {
    promptAction.showToast({ message: `最多选择 ${this.config().maxFileCount} 个文件` });
  }

  private showPickerError(message: string): void {
    promptAction.showToast({ message: message.length > 0 ? message : '选择文件失败，请重试' });
  }

  private appendFiles(files: MedicalUploadLocalFile[]): void {
    if (files.length === 0) {
      return;
    }
    const slots = this.remainingSlots();
    if (slots <= 0) {
      this.showLimitToast();
      return;
    }
    const next = this.localFiles.slice();
    for (let i = 0; i < files.length && i < slots; i++) {
      next.push(files[i]);
    }
    this.localFiles = next;
    if (files.length > slots) {
      this.showLimitToast();
    }
  }

  private presentCamera(): void {
    if (!this.ensureCanAdd()) {
      return;
    }
    promptAction.showToast({ message: '拍照上传暂未接入，请先使用相册或文件上传' });
  }

  private async pickPhotos(): Promise<void> {
    if (this.isPicking || !this.ensureCanAdd()) {
      return;
    }
    this.isPicking = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const files = await HarmonyMedicalDocumentFilePicker.pickImages(context, this.remainingSlots());
      this.appendFiles(files);
    } catch (error) {
      this.showPickerError(String(error));
    } finally {
      this.isPicking = false;
    }
  }

  private async pickFiles(): Promise<void> {
    if (this.isPicking || !this.ensureCanAdd()) {
      return;
    }
    this.isPicking = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const files = await HarmonyMedicalDocumentFilePicker.pickImagesAndPDFs(context, this.remainingSlots());
      this.appendFiles(files);
    } catch (error) {
      this.showPickerError(String(error));
    } finally {
      this.isPicking = false;
    }
  }

  private clearFiles(): void {
    this.localFiles = [];
  }

  private removeFile(localId: string): void {
    this.localFiles = this.localFiles.filter((file: MedicalUploadLocalFile): boolean =>
      file.localId !== localId
    );
  }

  private startRecognition(): void {
    if (!this.canStart()) {
      return;
    }
    this.onConfirm(this.localFiles.slice());
  }

  private previewFile(index: number): void {
    const inputs: FilePreviewInput[] = [];
    for (let i = 0; i < this.localFiles.length; i++) {
      inputs.push(this.localFiles[i].previewInput());
    }
    this.previewInputs = inputs;
    this.previewIndex = index;
    this.showPreview = true;
  }

  @Builder
  private titleBar() {
    MedicalUploadPageHeaderChrome({
      title: this.config().sheetTitle,
      titleFontSize: 17,
      leadingStyle: MedicalUploadHeaderLeadingStyle.CANCEL,
      onLeading: () => {
        this.onCancel();
      }
    })
  }

  @Builder
  private header() {
    Column({ space: 5 }) {
      Text(this.config().headerTitle)
        .width('100%')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
      Text(this.config().headerSubtitle)
        .width('100%')
        .fontSize(13)
        .fontColor('#6E6E73')
        .lineHeight(19)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private entryTile(entry: MedicalAttachmentUploadEntry, symbol: Resource, title: string, subtitle: string, tint: string) {
    Column({ space: 6 }) {
      SymbolGlyph(symbol)
        .fontSize(24)
        .fontColor([tint])
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(tint)
        .maxLines(1)
      Text(subtitle)
        .fontSize(11)
        .fontColor(tint)
        .opacity(0.78)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(94)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .opacity(this.isPicking ? 0.55 : 1)
    .onClick(() => {
      if (entry === 'camera') {
        this.presentCamera();
      } else if (entry === 'photo') {
        this.pickPhotos();
      } else {
        this.pickFiles();
      }
    })
  }

  @Builder
  private entryTiles() {
    Row({ space: 12 }) {
      this.entryTile('camera', $r('sys.symbol.plus_circle_fill'), '拍照上传', '即时拍摄', '#0A84FF')
      this.entryTile('photo', $r('sys.symbol.square_stack_3d'), '照片上传', '选择相册', '#AF52DE')
      this.entryTile('file', $r('sys.symbol.doc_text'), '文件上传', 'PDF/图片', '#34A853')
    }
    .width('100%')
  }

  @Builder
  private emptyState() {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.paperclip'))
        .fontSize(38)
        .fontColor(['#AF52DE'])
        .opacity(0.65)
      Text(this.config().emptyTitle)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#6D3BAA')
      Text(this.config().emptySubtitle)
        .fontSize(12)
        .fontColor('#7C5AA6')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 24, bottom: 24, left: 16, right: 16 })
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  private selectedGrid() {
    Column({ space: 10 }) {
      Row() {
        Text('已选择')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
        Blank()
        Text(`${this.localFiles.length}/${this.config().maxFileCount}`)
          .fontSize(12)
          .fontColor('#8E8E93')
      }
      .width('100%')

      Grid() {
        ForEach(this.localFiles, (file: MedicalUploadLocalFile, index: number) => {
          GridItem() {
            MedicalDocumentFilePreviewSquareCard({
              item: file.previewInput(),
              showDelete: true,
              onPreview: () => this.previewFile(index),
              onDelete: () => this.removeFile(file.localId)
            })
          }
        }, (file: MedicalUploadLocalFile): string => file.localId)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(12)
      .rowsGap(12)
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private bottomBarContent() {
    Row({ space: 12 }) {
      Button('清空')
        .layoutWeight(1)
        .height(48)
        .fontSize(15)
        .fontColor('#3A3A3C')
        .backgroundColor('#E9E9ED')
        .enabled(this.localFiles.length > 0 && !this.isPicking)
        .onClick(() => this.clearFiles())
      Button('开始识别')
        .layoutWeight(2)
        .height(48)
        .fontSize(15)
        .fontColor(Color.White)
        .backgroundColor(this.canStart() ? this.config().tintColor : '#A8CDB3')
        .enabled(this.canStart())
        .onClick(() => this.startRecognition())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  private bottomBar() {
    Column({ space: 0 }) {
      Divider()
        .width('100%')
        .height(0.5)
        .color(MEDICAL_LIST_DIVIDER)
      this.bottomBarContent()
    }
    .width('100%')
    .backgroundColor(MEDICAL_LIST_HEADER_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  private previewBuilder() {
    UnifiedFilePreview({
      inputs: this.previewInputs,
      startIndex: this.previewIndex,
      onClose: () => {
        this.showPreview = false;
      }
    })
  }

  build() {
    Column() {
      this.titleBar()
      Scroll() {
        Column({ space: 14 }) {
          this.header()
          this.entryTiles()
          if (this.localFiles.length === 0) {
            this.emptyState()
          } else {
            this.selectedGrid()
          }
          Blank().height(4)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 12 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      this.bottomBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MEDICAL_LIST_PAGE_BG)
    .bindContentCover($$this.showPreview, this.previewBuilder(), {
      modalTransition: ModalTransition.DEFAULT,
      backgroundColor: '#111111'
    })
  }
}

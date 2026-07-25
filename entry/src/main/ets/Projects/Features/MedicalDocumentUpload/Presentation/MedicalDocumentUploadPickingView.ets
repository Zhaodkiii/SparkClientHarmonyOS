import { common } from '@kit.AbilityKit';
import { Member } from '../../../Core/Domain/Entities/Member';
import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalDocumentUploadAttachmentPreview } from '../Domain/MedicalDocumentUploadAttachmentPreview';
import {
  MedicalDocumentFilePreviewSquareCard
} from '../../Home/Presentation/MedicalLists/MedicineBox/MedicalDocumentFilePreviewSquareCard';
import { FilePreviewInput } from '../../../Core/UI/FilePreview/FilePreviewInput';
import { UnifiedFilePreview } from '../../../Core/UI/FilePreview/UnifiedFilePreview';
import {
  MedicalDocumentKind,
  medicalDocumentKindAllCases,
  medicalDocumentKindPickerLabel,
  medicalDocumentKindSymbol
} from '../Domain/MedicalDocumentKind';
import { MedicalUploadLocalFile } from '../Domain/MedicalDocumentUploadModels';
import { MedicalUploadL10n } from '../Domain/SupportingModels';
import { HarmonyMedicalDocumentFilePicker } from '../Infrastructure/HarmonyMedicalDocumentFilePicker';
import { MedicalDocumentUploadViewModel } from './MedicalDocumentUploadViewModel';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../Foundation/Logging/LogModule';

/**
 * 选文件首屏。对齐参考包 `MedicalDocumentUploadPickingView` 结构：
 * 成员卡 / 类型选择 / 摘要 / 三列预览 / 继续添加 / 提示 / 底部操作栏。
 * ContentCover：禁用 Column+Scroll.layoutWeight(1)；用 Stack 占满高度。
 * 菜单：不用 bindMenu，改为页面内展开，避免子树构建失败。
 */
@Component
export struct MedicalDocumentUploadPickingView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  @State private showMemberChoices: boolean = false;
  @State private showKindChoices: boolean = false;
  @State private isPickingFile: boolean = false;
  @State private showPreviewSheet: boolean = false;
  @State private previewIndex: number = 0;
  @State private previewInputs: FilePreviewInput[] = [];

  aboutToAppear(): void {
    this.trace('medical.upload.picking_view.appeared');
  }

  private imageCount(): number {
    return this.viewModel.selectedFiles.filter((file: MedicalAttachmentInput): boolean =>
      file.mimeType.indexOf('image/') === 0
    ).length;
  }

  private documentCount(): number {
    return this.viewModel.selectedFiles.length - this.imageCount();
  }

  private hasFiles(): boolean {
    return this.viewModel.selectedFiles.length > 0;
  }

  private isImage(file: MedicalAttachmentInput): boolean {
    return file.mimeType.indexOf('image/') === 0;
  }

  private async selectMember(memberID: number): Promise<void> {
    await this.viewModel.selectMember(memberID);
    this.showMemberChoices = false;
    this.trace('medical.upload.picking.member_selected');
  }

  private selectKind(kind: MedicalDocumentKind): void {
    this.viewModel.selectedKind = kind;
    this.showKindChoices = false;
    this.trace('medical.upload.picking.kind_selected');
  }

  private async pickImages(): Promise<void> {
    if (this.isPickingFile) {
      return;
    }
    this.isPickingFile = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const localFiles = await HarmonyMedicalDocumentFilePicker.pickImages(context, 9);
      const files = localFiles.map((f: MedicalUploadLocalFile): MedicalAttachmentInput => f.toAttachment());
      if (files.length > 0) {
        this.viewModel.appendFiles(files);
        this.trace('medical.upload.picking.files_selected', `source=album;count=${files.length}`);
      }
    } catch (_e) {
      this.trace('medical.upload.picking.file_picker_cancelled', 'source=album');
    } finally {
      this.isPickingFile = false;
    }
  }

  private async pickImagesAndPDFs(): Promise<void> {
    if (this.isPickingFile) {
      return;
    }
    this.isPickingFile = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const localFiles = await HarmonyMedicalDocumentFilePicker.pickImagesAndPDFs(context, 9);
      const files = localFiles.map((f: MedicalUploadLocalFile): MedicalAttachmentInput => f.toAttachment());
      if (files.length > 0) {
        this.viewModel.appendFiles(files);
        this.trace('medical.upload.picking.files_selected', `source=file;count=${files.length}`);
      }
    } catch (_e) {
      this.trace('medical.upload.picking.file_picker_cancelled', 'source=file');
    } finally {
      this.isPickingFile = false;
    }
  }

  private openAddMenu(): void {
    // 先打开相册；PDF 入口并列在卡片内次按钮，避免 ContentCover 内嵌套 Menu。
    this.pickImages();
  }

  private trace(event: string, detail: string = ''): void {
    const fields = new LogFields();
    fields.operation = 'medical_upload_picking_view';
    fields.detail = `member=${this.viewModel.selectedMemberID};files=${this.viewModel.selectedFiles.length};` +
      `kind=${this.viewModel.selectedKind};${detail}`;
    Logger.info(event, LogModule.HOME, fields);
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Scroll() {
        Column({ space: 16 }) {
          this.MemberCard()
          this.ReportKindPicker()

          if (this.hasFiles()) {
            this.SelectedFilesSummaryCard()
            this.FilePreviewGrid()
          }

          this.ContinueAddButton()
          this.TipsCard()

          if (this.viewModel.errorMessage.length > 0) {
            Text(this.viewModel.errorMessage)
              .width('100%')
              .fontSize(13)
              .fontColor('#D93025')
          }

          Blank().height(this.hasFiles() ? 84 : 24)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      if (this.hasFiles()) {
        Column() {
          Divider().color('#E5E5EA')
          this.BottomActionBar()
        }
        .width('100%')
        .backgroundColor(Color.White)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
    .bindSheet($$this.showPreviewSheet, this.UnifiedFilePreviewBuilder(), {
      height: SheetSize.LARGE,
      onDisappear: () => {
        this.showPreviewSheet = false;
      }
    })
  }

  @Builder
  private MemberCard() {
    Column() {
      Row() {
        Column({ space: 6 }) {
          Text(MedicalUploadL10n.text('medical.upload.current_member'))
            .width('100%')
            .fontSize(12)
            .fontColor('#777777')
          Text(this.viewModel.selectedMemberName.length > 0 ?
            this.viewModel.selectedMemberName :
            MedicalUploadL10n.text('medical.upload.member.not_selected'))
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1C1E')
        }
        .layoutWeight(1)
        Text(this.showMemberChoices ? '收起⌃' : '选择成员›')
          .fontSize(14)
          .fontColor('#0A84FF')
      }
      .width('100%')
      .padding(16)
      .onClick(() => {
        this.showMemberChoices = !this.showMemberChoices;
        this.showKindChoices = false;
      })

      if (this.showMemberChoices) {
        Divider().color('#E5E5EA')
        Column() {
          ForEach(this.viewModel.members(), (member: Member) => {
            Row() {
              Text(member.name)
                .layoutWeight(1)
                .fontSize(15)
                .fontColor('#1C1C1E')
              if (member.id === this.viewModel.selectedMemberID) {
                Text('✓').fontSize(18).fontColor('#34A853')
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 13, bottom: 13 })
            .onClick(() => this.selectMember(member.id))
          }, (member: Member): string => `${member.id}`)
        }
      }
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(12)
    .border({ width: 1, color: '#E2E2E7' })
  }

  @Builder
  private SelectedFilesSummaryCard() {
    Row() {
      Text(MedicalUploadL10n.text('medical.upload.picking.summary.title'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
      Blank()
      Row({ space: 8 }) {
        if (this.imageCount() > 0) {
          Text(MedicalUploadL10n.format('medical.upload.picking.image_count', this.imageCount()))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#F2F2F7')
            .borderRadius(8)
        }
        if (this.documentCount() > 0) {
          Text(MedicalUploadL10n.format('medical.upload.picking.document_count', this.documentCount()))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#F2F2F7')
            .borderRadius(8)
        }
      }
    }
    .width('100%')
    .padding(16)
    .linearGradient({
      angle: 90,
      colors: [['#1F34C759', 0.0], ['#1A32ADE6', 1.0]]
    })
    .borderRadius(12)
  }

  @Builder
  private ReportKindPicker() {
    Column() {
      Row({ space: 12 }) {
        Column() {
          SymbolGlyph(medicalDocumentKindSymbol(this.viewModel.selectedKind))
            .fontSize(18)
            .fontColor(['#0A84FF'])
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#EEF6FF')
        .borderRadius(10)

        Column({ space: 2 }) {
          Text(MedicalUploadL10n.text('medical.upload.picking.report_type'))
            .width('100%')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#777777')
          Text(medicalDocumentKindPickerLabel(this.viewModel.selectedKind))
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1C1E')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.showKindChoices ? '收起⌃' : '更改›')
          .fontSize(14)
          .fontColor('#0A84FF')
      }
      .width('100%')
      .padding(16)
      .onClick(() => {
        this.showKindChoices = !this.showKindChoices;
        this.showMemberChoices = false;
      })

      if (this.showKindChoices) {
        Divider().color('#B7D3F4')
        Column() {
          ForEach(medicalDocumentKindAllCases(), (kind: MedicalDocumentKind) => {
            Row() {
              Text(medicalDocumentKindPickerLabel(kind))
                .layoutWeight(1)
                .fontSize(15)
                .fontColor('#1C1C1E')
              if (kind === this.viewModel.selectedKind) {
                Text('✓').fontSize(18).fontColor('#0A84FF')
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 13, bottom: 13 })
            .onClick(() => this.selectKind(kind))
          }, (kind: MedicalDocumentKind): string => kind)
        }
      }
    }
    .width('100%')
    .backgroundColor('#EEF6FF')
    .borderRadius(12)
    .border({ width: 1, color: '#B7D3F4' })
  }

  @Builder
  private FilePreviewGrid() {
    Grid() {
      ForEach(this.viewModel.selectedFiles, (file: MedicalAttachmentInput, index: number) => {
        GridItem() {
          this.FileSquareCard(file, index)
        }
      }, (file: MedicalAttachmentInput): string => file.previewId)
    }
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(12)
    .rowsGap(12)
    .width('100%')
  }

  @Builder
  private FileSquareCard(file: MedicalAttachmentInput, index: number) {
    MedicalDocumentFilePreviewSquareCard({
      item: MedicalDocumentUploadAttachmentPreview.fromAttachment(file),
      showDelete: true,
      onPreview: () => {
        this.previewInputs =
          MedicalDocumentUploadAttachmentPreview.fromAttachments(this.viewModel.selectedFiles);
        this.previewIndex = index;
        this.showPreviewSheet = true;
      },
      onDelete: () => {
        this.viewModel.removeFile(file.previewId);
      }
    })
  }

  @Builder
  private ContinueAddButton() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('+')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0A84FF')
        Text(MedicalUploadL10n.text('medical.upload.picking.add_files'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0A84FF')
      }
      .width('100%')
      .height(48)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#EAF3FF')
      .borderRadius(12)
      .border({ width: 2, color: '#0A84FF', style: BorderStyle.Dashed })
      .enabled(!this.isPickingFile)
      .onClick(() => this.openAddMenu())

      Row({ space: 12 }) {
        Button('从相册选择')
          .layoutWeight(1)
          .height(40)
          .fontColor('#0A84FF')
          .backgroundColor('#EAF3FF')
          .enabled(!this.isPickingFile)
          .onClick(() => this.pickImages())
        Button('选择图片/PDF')
          .layoutWeight(1)
          .height(40)
          .fontColor(Color.White)
          .backgroundColor('#0A84FF')
          .enabled(!this.isPickingFile)
          .onClick(() => this.pickImagesAndPDFs())
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private TipsCard() {
    Column({ space: 8 }) {
      Text(MedicalUploadL10n.text('medical.upload.picking.tip.auto_type'))
        .width('100%')
        .fontSize(12)
        .fontColor('#0A84FF')
        .textAlign(TextAlign.Start)
      Text(MedicalUploadL10n.text('medical.upload.picking.tip.formats'))
        .width('100%')
        .fontSize(12)
        .fontColor('#0A84FF')
        .textAlign(TextAlign.Start)
    }
    .padding(12)
    .width('100%')
    .backgroundColor('#EEF6FF')
    .borderRadius(10)
  }

  @Builder
  private BottomActionBar() {
    Row({ space: 12 }) {
      Button(MedicalUploadL10n.text('medical.upload.picking.clear'))
        .layoutWeight(1)
        .height(52)
        .fontColor('#333333')
        .backgroundColor('#E9E9ED')
        .onClick(() => this.viewModel.setSelectedFiles([]))
      Button(MedicalUploadL10n.text('medical.upload.start'))
        .layoutWeight(2)
        .height(52)
        .fontColor(Color.White)
        .backgroundColor(this.viewModel.canStartRecognition ? '#34A853' : '#A8CDB3')
        .enabled(this.viewModel.canStartRecognition)
        .onClick(() => this.viewModel.startRecognitionTask())
    }
    .padding({ left: 16, right: 16, top: 10, bottom: 12 })
    .width('100%')
  }

  @Builder
  private UnifiedFilePreviewBuilder() {
    UnifiedFilePreview({
      inputs: this.previewInputs,
      startIndex: this.previewIndex,
      onClose: () => {
        this.showPreviewSheet = false;
      }
    })
  }
}

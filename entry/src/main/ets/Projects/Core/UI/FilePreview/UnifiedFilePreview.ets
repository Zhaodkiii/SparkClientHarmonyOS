import { FilePreviewInput } from './FilePreviewInput';
import { LocalFileImageThumbnail } from
  '../../../Features/Home/Presentation/MedicalLists/MedicineBox/LocalFileImageThumbnail';

/**
 * 统一文件预览容器。对齐 iOS `UnifiedFilePreview`：
 * 仅负责预览路由，不承载上传/下载业务逻辑。
 */
@Component
export struct UnifiedFilePreview {
  @Prop inputs: FilePreviewInput[] = [];
  @Prop startIndex: number = 0;
  onClose?: () => void;

  @State private currentIndex: number = 0;

  aboutToAppear(): void {
    this.currentIndex = this.clampIndex(this.startIndex);
  }

  private clampIndex(index: number): number {
    if (this.inputs.length === 0) {
      return 0;
    }
    if (index < 0) {
      return 0;
    }
    if (index >= this.inputs.length) {
      return 0;
    }
    return index;
  }

  private currentInput(): FilePreviewInput | undefined {
    if (this.inputs.length === 0) {
      return undefined;
    }
    const index = this.clampIndex(this.currentIndex);
    return this.inputs[index];
  }

  @Builder
  private fallbackView(icon: string, title: string, message: string) {
    Column({ space: 12 }) {
      Text(icon)
        .fontSize(36)
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
      Text(message)
        .fontSize(13)
        .fontColor('#8E8E93')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(24)
  }

  @Builder
  private previewBody(input: FilePreviewInput) {
    if (!input.isLocalFileAvailable()) {
      this.fallbackView('⚠️', '无法预览', '文件不存在或无法访问。')
    } else if (input.isImageType()) {
      if (input.isContentUri() || input.previewUri().startsWith('http')) {
        Image(input.previewUri())
          .objectFit(ImageFit.Contain)
          .width('100%')
          .layoutWeight(1)
      } else {
        LocalFileImageThumbnail({ filePath: input.localFilePath() })
          .width('100%')
          .layoutWeight(1)
      }
    } else {
      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.doc_text'))
          .fontSize(40)
          .fontColor(['#0A84FF'])
        Text(input.isPdfType() ? 'PDF 文档' : '文档')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
        Text(input.resolvedDisplayName())
          .fontSize(13)
          .fontColor('#CCCCCC')
          .maxLines(3)
          .textAlign(TextAlign.Center)
          .padding({ left: 24, right: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  build() {
    Column() {
      Row() {
        Blank().layoutWeight(1)
        Text('完成')
          .fontSize(16)
          .fontColor('#0A84FF')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            if (this.onClose) {
              this.onClose();
            }
          })
      }
      .width('100%')

      if (this.inputs.length === 0) {
        this.fallbackView('📄', '无法预览', '未提供可预览的文件。')
      } else if (this.inputs.length === 1) {
        this.previewBody(this.inputs[0])
      } else {
        Swiper() {
          ForEach(this.inputs, (input: FilePreviewInput) => {
            Column() {
              this.previewBody(input)
            }
            .width('100%')
            .height('100%')
          }, (input: FilePreviewInput) => input.id)
        }
        .index(this.currentIndex)
        .indicator(true)
        .loop(false)
        .layoutWeight(1)
        .onChange((index: number) => {
          this.currentIndex = index;
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}

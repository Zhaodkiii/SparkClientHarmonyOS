import { FilePreviewInput } from '../../../../../Core/UI/FilePreview/FilePreviewInput';
import { LocalFileImageThumbnail } from './LocalFileImageThumbnail';

/**
 * 正方形预览格，图片走缩略图，非图片走文档图标。
 */
@Component
export struct MedicalDocumentFilePreviewSquareCard {
  @Prop item: FilePreviewInput = new FilePreviewInput();
  @Prop showDelete: boolean = true;
  onPreview?: () => void;
  onDelete?: () => void;

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.item.isImageType()) {
        if (this.item.isContentUri()) {
          Image(this.item.previewUri())
            .objectFit(ImageFit.Cover)
            .width('100%')
            .height('100%')
            .borderRadius(12)
            .border({ width: 0.5, color: '#C6C6C8' })
            .clip(true)
            .onClick(() => this.onPreview?.())
        } else {
          LocalFileImageThumbnail({ filePath: this.item.localFilePath() })
            .width('100%')
            .height('100%')
            .borderRadius(12)
            .border({ width: 0.5, color: '#C6C6C8' })
            .clip(true)
            .onClick(() => this.onPreview?.())
        }
      } else {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.doc_text'))
            .fontSize(28)
            .fontColor(['#007AFF'])
          Text(this.item.resolvedDisplayName())
            .fontSize(11)
            .maxLines(2)
            .textAlign(TextAlign.Center)
            .fontColor('#8E8E93')
            .padding({ left: 6, right: 6 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(12)
        .border({ width: 0.5, color: '#C6C6C8' })
        .linearGradient({
          angle: 135,
          colors: [['#1A007AFF', 0.0], ['#1A5856D6', 1.0]]
        })
        .onClick(() => this.onPreview?.())
      }

      if (this.showDelete) {
        Button({ type: ButtonType.Circle }) {
          Text('×')
            .fontSize(14)
            .fontColor(Color.White)
        }
        .width(24)
        .height(24)
        .backgroundColor('#FF3B30')
        .offset({ x: 8, y: -8 })
        .onClick(() => this.onDelete?.())
      }
    }
    .aspectRatio(1)
  }
}

// 向后兼容：旧路径仍从此文件导出 FilePreviewInput
export { FilePreviewInput } from '../../../../../Core/UI/FilePreview/FilePreviewInput';

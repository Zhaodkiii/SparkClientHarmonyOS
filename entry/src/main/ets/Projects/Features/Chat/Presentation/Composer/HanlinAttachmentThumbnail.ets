import {
  ChatComposerAttachmentKind,
  ChatComposerAttachmentPreview,
  ChatComposerAttachmentPreviewParams,
  ChatComposerAttachmentSource
} from './Models/ChatComposerDraftModels';
import { ComposerTheme } from './Models/ComposerTheme';

function emptyAttachment(): ChatComposerAttachmentPreview {
  const params: ChatComposerAttachmentPreviewParams = {
    source: ChatComposerAttachmentSource.PHOTO_LIBRARY,
    kind: ChatComposerAttachmentKind.IMAGE,
    sourceUri: '',
    displayName: ''
  };
  return ChatComposerAttachmentPreview.create(params);
}

/** 附件缩略图，对标 iOS HanlinAttachmentThumbnail。 */
@Component
export struct HanlinAttachmentThumbnail {
  @Prop attachment: ChatComposerAttachmentPreview = emptyAttachment();
  @Prop uploadProgress: number = -1;
  @Prop isSelected: boolean = false;
  onTap: () => void = () => {};
  onRemove: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Stack() {
        if (this.attachment.isImage && this.attachment.sourceUri.length > 0) {
          Image(this.attachment.sourceUri)
            .width(80)
            .height(80)
            .objectFit(ImageFit.Cover)
            .borderRadius(15)
        } else {
          Column({ space: 6 }) {
            Text(this.attachment.isPDF ? 'PDF' : 'FILE')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(ComposerTheme.textSecondary)
            Text(this.attachment.displayName)
              .fontSize(10)
              .fontColor(ComposerTheme.textTertiary)
              .maxLines(1)
              .constraintSize({ maxWidth: 68 })
          }
          .width(80)
          .height(80)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(ComposerTheme.secondaryFill)
          .borderRadius(15)
        }

        if (this.uploadProgress >= 0 && this.uploadProgress < 0.999) {
          Column() {
            Progress({ value: this.uploadProgress * 100, total: 100, type: ProgressType.Ring })
              .width(28)
              .height(28)
              .color(Color.White)
          }
          .width(80)
          .height(80)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('rgba(0,0,0,0.45)')
          .borderRadius(15)
        }
      }
      .width(80)
      .height(80)
      .borderRadius(15)
      .border({
        width: 2,
        color: this.isSelected ? ComposerTheme.accent : Color.Transparent
      })
      .clip(true)
      .onClick(() => this.onTap())

      Text('×')
        .fontSize(11)
        .fontColor(Color.White)
        .width(20)
        .height(20)
        .textAlign(TextAlign.Center)
        .backgroundColor('rgba(0,0,0,0.72)')
        .borderRadius(10)
        .margin(6)
        .onClick(() => this.onRemove())
    }
  }
}

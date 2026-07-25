import { ComposerTheme } from './Models/ComposerTheme';

/** 添加附件 Sheet，对标 iOS HanlinAttachmentSheet。 */
@Component
export struct HanlinAttachmentSheet {
  @Prop isCameraAvailable: boolean = true;
  onPhotos: () => void = () => {};
  onCamera: () => void = () => {};
  onFiles: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Text('添加附件')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textAlign(TextAlign.Start)
        .fontColor(ComposerTheme.textPrimary)

      Text('选择图片、拍照或上传文件')
        .fontSize(14)
        .fontColor(ComposerTheme.textSecondary)
        .width('100%')

      this.attachmentRow('▣', '照片', '从相册选择图片', () => this.onPhotos())
      this.attachmentRow(
        '◎',
        '拍照',
        this.isCameraAvailable ? '使用相机拍摄' : '相机不可用',
        () => this.onCamera(),
        !this.isCameraAvailable
      )
      this.attachmentRow('▤', '文件', '上传文档或 PDF', () => this.onFiles())
    }
    .width('100%')
    .padding(20)
  }

  @Builder
  private attachmentRow(
    icon: string,
    title: string,
    subtitle: string,
    action: () => void,
    disabled: boolean = false
  ) {
    Row({ space: 14 }) {
      Stack() {
        Circle({ width: 38, height: 38 }).fill(ComposerTheme.withOpacity(ComposerTheme.accent, 0.12))
        Text(icon).fontSize(18).fontColor(ComposerTheme.accent)
      }
      .width(38)
      .height(38)

      Column({ space: 2 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Medium).alignSelf(ItemAlign.Start)
        Text(subtitle).fontSize(12).fontColor(ComposerTheme.textSecondary).alignSelf(ItemAlign.Start)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(ComposerTheme.secondaryGrouped)
    .borderRadius(18)
    .opacity(disabled ? 0.4 : 1)
    .onClick(() => {
      if (!disabled) {
        action();
      }
    })
  }
}

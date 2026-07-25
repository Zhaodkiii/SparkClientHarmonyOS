import { HealthResourceRef } from './Models/HealthResourceRef';
import { ComposerTheme } from './Models/ComposerTheme';

/** 健康资料引用缩略卡片，对标 iOS HanlinHealthResourceThumbnail。 */
@Component
export struct HanlinHealthResourceThumbnail {
  @Prop refItem: HealthResourceRef = HealthResourceRef.fromRaw('', 0, 0, '', '');
  @Prop index: number = 1;
  @Prop total: number = 1;
  onTap: () => void = () => {};
  onRemove: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 4 }) {
        Row() {
          Text(`${this.index}/${this.total}`)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(ComposerTheme.textSecondary)
          Blank()
        }
        .width('100%')

        if ((this.refItem.typeBadge ?? '').length > 0) {
          Text(this.refItem.typeBadge)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(ComposerTheme.accent)
            .maxLines(1)
        }

        Text(this.refItem.displayTitle)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(ComposerTheme.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .alignSelf(ItemAlign.Start)

        if (this.refItem.displaySubtitle.length > 0) {
          Text(this.refItem.displaySubtitle)
            .fontSize(10)
            .fontColor(ComposerTheme.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width(132)
      .height(84)
      .alignItems(HorizontalAlign.Start)
      .padding(8)
      .backgroundColor(ComposerTheme.secondaryFill)
      .borderRadius(12)
      .border({ width: 1, color: 'rgba(0,0,0,0.08)' })
      .onClick(() => this.onTap())

      Text('×')
        .fontSize(12)
        .fontColor(Color.White)
        .width(18)
        .height(18)
        .textAlign(TextAlign.Center)
        .backgroundColor('rgba(0,0,0,0.55)')
        .borderRadius(9)
        .margin(4)
        .onClick(() => this.onRemove())
    }
  }
}

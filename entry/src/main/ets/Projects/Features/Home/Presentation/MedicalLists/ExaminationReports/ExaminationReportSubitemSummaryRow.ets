import { RemoteMedExamDetail } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import {
  ExaminationReportCategory,
  examinationCategoryIcon,
  examinationCategoryTint
} from './ExaminationReportCategory';
import { ExaminationReportDetailSupport } from './ExaminationReportDetailSupport';

/**
 * 检查报告明细摘要行。对齐 iOS ExaminationReportSubitemSummaryRow。
 */
@Component
export struct ExaminationReportSubitemSummaryRow {
  @Prop category: ExaminationReportCategory = 'laboratory';
  @Prop item: RemoteMedExamDetail = new RemoteMedExamDetail();
  @Prop showsTrailingChevron: boolean = true;

  private subtitleText(): string {
    const subtitle = ExaminationReportDetailSupport.subitemSubtitle(this.category, this.item);
    return subtitle.length > 0 ? subtitle : '点击查看详情';
  }

  build() {
    Row({ space: 10 }) {
      Column() {
        SymbolGlyph(examinationCategoryIcon(this.category))
          .fontSize(16)
          .fontColor([examinationCategoryTint(this.category)])
      }
      .width(38)
      .height(38)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(`${examinationCategoryTint(this.category)}24`)
      .borderRadius(10)

      Column({ space: 4 }) {
        Text(ExaminationReportDetailSupport.subitemTitle(this.item))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.subtitleText())
          .fontSize(12)
          .fontColor('#8E8E93')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.showsTrailingChevron) {
        Text('›')
          .fontSize(16)
          .fontColor('#C7C7CC')
      }
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .padding(10)
    .backgroundColor('#F8F8FA')
    .borderRadius(10)
  }
}

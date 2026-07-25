import {
  RemoteExaminationReportWithAttachments,
  RemoteMedExamDetail
} from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { isPotentiallyAbnormalFlag, nonEmptyText } from '../Shared/HealthExamFlagSupport';
import { ExaminationReportDetailSupport } from './ExaminationReportDetailSupport';

/**
 * 影像检查单项明细页。对齐 iOS ImagingReportDetailPage：
 * 按 medExamDetails 渲染卡片（分类/方式/部位/结果/诊断）。
 */
@Component
export struct ImagingReportDetailPage {
  @Prop report: RemoteExaminationReportWithAttachments = new RemoteExaminationReportWithAttachments();
  @Prop navigationTitleOverride: string = '';

  private detailItems(): RemoteMedExamDetail[] {
    return ExaminationReportDetailSupport.sortedDetails(this.report);
  }

  @Builder
  private DetailRow(label: string, value: string) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(12)
        .fontColor('#8E8E93')
      Text(value.length > 0 ? value : '—')
        .fontSize(14)
        .fontColor('#1C1C1E')
        .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
  }

  @Builder
  private ImagingDetailCard(item: RemoteMedExamDetail) {
    Column({ space: 12 }) {
      Row() {
        Text(nonEmptyText(item.itemName).length > 0 ? item.itemName : `项目 #${item.id}`)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
          .layoutWeight(1)
        if (nonEmptyText(item.flag).length > 0) {
          Text(item.flag)
            .fontSize(12)
            .fontColor(isPotentiallyAbnormalFlag(item.flag) ? '#FF3B30' : '#8E8E93')
        }
      }
      .width('100%')

      this.DetailRow('分类', nonEmptyText(item.category))
      this.DetailRow('检查方式', nonEmptyText(item.modality))
      this.DetailRow('部位', nonEmptyText(item.bodyPart))
      this.DetailRow('结果', ExaminationReportDetailSupport.resultValueWithUnit(item))

      if (nonEmptyText(item.diagnosis).length > 0) {
        Column({ space: 4 }) {
          Text('诊断')
            .fontSize(12)
            .fontColor('#8E8E93')
            .width('100%')
          Text(nonEmptyText(item.diagnosis))
            .fontSize(14)
            .fontColor('#1C1C1E')
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#F2F2F7' })
  }

  build() {
    Column({ space: 12 }) {
      if (this.detailItems().length === 0) {
        Text('暂无影像明细')
          .fontSize(14)
          .fontColor('#8E8E93')
          .width('100%')
          .padding(24)
          .textAlign(TextAlign.Center)
      } else {
        ForEach(this.detailItems(), (item: RemoteMedExamDetail) => {
          this.ImagingDetailCard(item)
        }, (item: RemoteMedExamDetail): string => `img-detail-${item.id}`)
      }
    }
    .width('100%')
  }
}

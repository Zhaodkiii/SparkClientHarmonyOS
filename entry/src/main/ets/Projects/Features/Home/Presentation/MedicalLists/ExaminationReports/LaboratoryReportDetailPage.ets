import {
  RemoteExaminationReportWithAttachments,
  RemoteMedExamDetail
} from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { nonEmptyText } from '../Shared/HealthExamFlagSupport';
import { ExaminationReportDetailSupport } from './ExaminationReportDetailSupport';

/**
 * 实验室检查明细表。对齐 iOS LaboratoryReportDetailPage：
 * 横向可滚动的表格式（项目/结果/参考范围/状态）。
 */
@Component
export struct LaboratoryReportDetailPage {
  @Prop report: RemoteExaminationReportWithAttachments = new RemoteExaminationReportWithAttachments();
  @Prop navigationTitleOverride: string = '';

  private detailItems(): RemoteMedExamDetail[] {
    return ExaminationReportDetailSupport.sortedDetails(this.report);
  }

  @Builder
  private HeaderCell(text: string, width: number) {
    Text(text)
      .fontSize(12)
      .fontColor('#8E8E93')
      .width(width)
      .padding({ left: 12, right: 12 })
  }

  @Builder
  private TableHeader() {
    Row() {
      this.HeaderCell('项目', 180)
      this.HeaderCell('结果', 140)
      this.HeaderCell('参考范围', 150)
      this.HeaderCell('状态', 120)
    }
    .width(590)
    .padding({ top: 10, bottom: 10 })
    .backgroundColor('#F8F8FA')
    .border({ width: { bottom: 1 }, color: '#E5E5EA' })
  }

  @Builder
  private TableRow(item: RemoteMedExamDetail) {
    Row() {
      Text(nonEmptyText(item.itemName).length > 0 ? item.itemName : `项目 #${item.id}`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
        .width(180)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 12, right: 12 })

      Text(ExaminationReportDetailSupport.resultValueWithUnit(item))
        .fontSize(14)
        .fontColor('#1C1C1E')
        .width(140)
        .padding({ left: 12, right: 12 })

      Text(nonEmptyText(item.referenceRange).length > 0 ? item.referenceRange : '—')
        .fontSize(12)
        .fontColor('#8E8E93')
        .width(150)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 12, right: 12 })

      Text(ExaminationReportDetailSupport.flagDisplayText(item.flag))
        .fontSize(12)
        .fontColor(ExaminationReportDetailSupport.flagColor(item.flag))
        .width(120)
        .padding({ left: 12, right: 12 })
    }
    .width(590)
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: '#F2F2F780' })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    if (this.detailItems().length === 0) {
      Text('暂无检验明细')
        .fontSize(14)
        .fontColor('#8E8E93')
        .width('100%')
        .padding(24)
        .textAlign(TextAlign.Center)
    } else {
      Scroll() {
        Column() {
          this.TableHeader()
          ForEach(this.detailItems(), (item: RemoteMedExamDetail) => {
            this.TableRow(item)
          }, (item: RemoteMedExamDetail): string => `lab-row-${item.id}`)
        }
        .width(590)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)
      .width('100%')
    }
  }
}

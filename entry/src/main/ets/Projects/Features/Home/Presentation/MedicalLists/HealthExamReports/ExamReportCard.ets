import {
  RemoteHealthExamReportWithAttachments,
  RemoteMedExamDetail
} from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import {
  formatExamDateText,
  isPotentiallyAbnormalFlag,
  nonEmptyText
} from '../Shared/HealthExamFlagSupport';

/**
 * 体检报告列表卡片。对齐 iOS ExamReportCard 信息结构（摘要/统计/明细预览）。
 */
@Component
export struct ExamReportCard {
  @Prop report: RemoteHealthExamReportWithAttachments = new RemoteHealthExamReportWithAttachments();
  @Prop isLoadingDetails: boolean = false;
  onOpenDetail?: () => void;

  private dateText(): string {
    return formatExamDateText(this.report.examDate);
  }

  private institutionText(): string {
    return nonEmptyText(this.report.institutionName);
  }

  private detailItems(): RemoteMedExamDetail[] {
    return this.report.medExamDetails;
  }

  private abnormalCount(): number {
    const items = this.detailItems();
    let count = 0;
    for (let i = 0; i < items.length; i++) {
      if (isPotentiallyAbnormalFlag(items[i].flag)) {
        count += 1;
      }
    }
    return count;
  }

  private normalCount(): number {
    const total = this.detailItems().length;
    const abnormal = this.abnormalCount();
    return total > abnormal ? total - abnormal : 0;
  }

  private canOpenDetail(): boolean {
    return this.detailItems().length > 0;
  }

  private previewRows(): RemoteMedExamDetail[] {
    const items = this.detailItems();
    const rows: RemoteMedExamDetail[] = [];
    for (let i = 0; i < items.length && rows.length < 6; i++) {
      if (!isPotentiallyAbnormalFlag(items[i].flag)) {
        rows.push(items[i]);
      }
    }
    return rows;
  }

  private resultText(item: RemoteMedExamDetail): string {
    const value = nonEmptyText(item.resultValue);
    const unit = nonEmptyText(item.unit);
    if (value.length > 0 && unit.length > 0) {
      return `${value}${unit}`;
    }
    return value.length > 0 ? value : unit;
  }

  private categoryText(item: RemoteMedExamDetail): string {
    const category = nonEmptyText(item.category);
    const sub = nonEmptyText(item.subCategory);
    if (category.length > 0 && sub.length > 0) {
      return `${category} · ${sub}`;
    }
    return category.length > 0 ? category : sub;
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        Row() {
          Row({ space: 6 }) {
            if (this.dateText().length > 0) {
              Text(this.dateText())
                .fontSize(13)
                .fontColor('#1C1C1E')
            }
            Text('体检')
              .fontSize(11)
              .fontColor('#1C1C1E')
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .backgroundColor('#F2F2F7')
              .borderRadius(6)
          }
          Blank()
          if (this.isLoadingDetails) {
            Row({ space: 6 }) {
              LoadingProgress().width(14).height(14)
              Text('查看详情')
                .fontSize(13)
                .fontColor('#0A84FF')
            }
          } else {
            Text('查看详情')
              .fontSize(13)
              .fontColor(this.canOpenDetail() ? '#0A84FF' : '#AEAEB2')
              .onClick(() => {
                if (this.canOpenDetail() && this.onOpenDetail) {
                  this.onOpenDetail();
                }
              })
          }
        }
        .width('100%')

        if (this.institutionText().length > 0) {
          Text(this.institutionText())
            .fontSize(12)
            .fontColor('#8E8E93')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        Row({ space: 8 }) {
          this.statCell(`${this.detailItems().length}`, '项目', '#0A84FF', '#0A84FF14')
          this.statCell(`${this.normalCount()}`, '正常', '#34C759', '#34C75914')
          this.statCell(`${this.abnormalCount()}`, '异常', '#FF3B30', '#FF3B3014')
        }
        .width('100%')
      }
      .padding(16)
      .width('100%')

      if (this.isLoadingDetails) {
        Row({ space: 10 }) {
          LoadingProgress().width(16).height(16)
          Text('正在加载明细…')
            .fontSize(12)
            .fontColor('#8E8E93')
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#F2F2F7')
      }

      if (this.previewRows().length > 0) {
        Column({ space: 10 }) {
          Text('关注项')
            .fontSize(13)
            .fontColor('#1C1C1E')
            .width('100%')
          ForEach(this.previewRows(), (item: RemoteMedExamDetail) => {
            Column({ space: 4 }) {
              Text(nonEmptyText(item.itemName).length > 0 ? item.itemName : `项目 #${item.id}`)
                .fontSize(14)
                .fontColor('#1C1C1E')
                .width('100%')
              if (this.categoryText(item).length > 0) {
                Text(this.categoryText(item))
                  .fontSize(12)
                  .fontColor('#8E8E93')
                  .width('100%')
              }
              if (this.resultText(item).length > 0) {
                Text(this.resultText(item))
                  .fontSize(12)
                  .fontColor('#3A3A3C')
                  .width('100%')
              }
            }
            .width('100%')
            .padding({ top: 4, bottom: 4 })
          }, (item: RemoteMedExamDetail) => `preview-${item.id}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })
      } else if (nonEmptyText(this.report.summary).length > 0 && this.report.detailsLoaded) {
        Text(nonEmptyText(this.report.summary))
          .fontSize(13)
          .fontColor('#3A3A3C')
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 16 })
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E5E5EA' })
    .onClick(() => {
      if (this.canOpenDetail() && this.onOpenDetail) {
        this.onOpenDetail();
      }
    })
  }

  @Builder
  statCell(value: string, label: string, textColor: string, bg: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(textColor)
      Text(label)
        .fontSize(11)
        .fontColor(textColor)
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .backgroundColor(bg)
    .borderRadius(10)
    .alignItems(HorizontalAlign.Center)
  }
}

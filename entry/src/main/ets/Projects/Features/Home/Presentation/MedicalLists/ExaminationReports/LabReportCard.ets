import {
  RemoteExaminationReportWithAttachments,
  RemoteManagedFile,
  RemoteMedExamDetail
} from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { FileTransferService } from '../../../../../../Core/FileStorage/FileTransferService';
import { MedicalAttachmentIconView, MedicalAttachmentListView } from '../Shared/MedicalAttachmentComponents';
import {
  ExaminationReportCategory,
  examinationCategoryIcon,
  examinationCategoryTint,
  formatExaminationDateText,
  resolveExaminationCategory
} from './ExaminationReportCategory';
import {
  isPotentiallyAbnormalFlag,
  nonEmptyText
} from '../Shared/HealthExamFlagSupport';

/**
 * 检查报告三类卡片。对齐 iOS LabReportCard（实验室/影像/病理分型）。
 * 头部：圆形分类图标 + 标题/副标题 + 日期/机构 meta 行；右侧「查看详情」+ 附件展开。
 * 详情门禁：medExamDetails.length > 0。
 */
@Component
export struct LabReportCard {
  @Prop report: RemoteExaminationReportWithAttachments = new RemoteExaminationReportWithAttachments();
  @Prop isLoadingDetails: boolean = false;
  fileTransferService?: FileTransferService;
  onOpenDetail?: () => void;

  @State private isAttachmentsExpanded: boolean = false;
  @State private isAbnormalExpanded: boolean = false;

  private category(): ExaminationReportCategory {
    return resolveExaminationCategory(this.report);
  }

  private titleText(): string {
    const name = nonEmptyText(this.report.itemName);
    if (name.length > 0) {
      return name;
    }
    return `检查 #${this.report.id}`;
  }

  private subtitleText(): string {
    const category = nonEmptyText(this.report.category);
    const sub = nonEmptyText(this.report.subCategory);
    if (category.length > 0 && sub.length > 0) {
      return `${category} · ${sub}`;
    }
    return category.length > 0 ? category : sub;
  }

  private detailItems(): RemoteMedExamDetail[] {
    return this.report.medExamDetails;
  }

  private attachments(): RemoteManagedFile[] {
    return this.report.attachments;
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

  private abnormalPreviewRows(): RemoteMedExamDetail[] {
    const items = this.detailItems();
    const rows: RemoteMedExamDetail[] = [];
    for (let i = 0; i < items.length && rows.length < 5; i++) {
      if (isPotentiallyAbnormalFlag(items[i].flag)) {
        rows.push(items[i]);
      }
    }
    return rows;
  }

  private pathologyPreviewRows(): RemoteMedExamDetail[] {
    const items = this.detailItems();
    const rows: RemoteMedExamDetail[] = [];
    for (let i = 0; i < items.length && rows.length < 5; i++) {
      rows.push(items[i]);
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

  private narrativeFallback(): string {
    const impression = nonEmptyText(this.report.impression);
    if (impression.length > 0) {
      return impression;
    }
    return nonEmptyText(this.report.findings);
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        Row({ space: 8 }) {
          this.titleCluster()

          Blank()

          Column({ space: 8 }) {
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

            if (this.attachments().length > 0) {
              MedicalAttachmentIconView({
                count: this.attachments().length,
                isExpanded: this.isAttachmentsExpanded,
                onTap: () => {
                  this.isAttachmentsExpanded = !this.isAttachmentsExpanded;
                }
              })
            }
          }
          .alignItems(HorizontalAlign.End)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')

        if (this.isAttachmentsExpanded && this.attachments().length > 0) {
          MedicalAttachmentListView({
            attachments: this.attachments(),
            fileTransferService: this.fileTransferService
          })
        }

        if (this.category() === 'laboratory') {
          this.laboratorySection()
        } else if (this.category() === 'imaging') {
          this.imagingSection()
        } else {
          this.pathologySection()
        }
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
  titleCluster() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .fill(`${examinationCategoryTint(this.category())}1A`)
          .width(36)
          .height(36)
        SymbolGlyph(examinationCategoryIcon(this.category()))
          .fontSize(16)
          .fontColor([examinationCategoryTint(this.category())])
      }
      .width(36)
      .height(36)

      Column({ space: 4 }) {
        Text(this.titleText())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.subtitleText().length > 0) {
          Text(this.subtitleText())
            .fontSize(12)
            .fontColor('#8E8E93')
        }

        Row({ space: 10 }) {
          if (formatExaminationDateText(this.report).length > 0) {
            Text(formatExaminationDateText(this.report))
              .fontSize(12)
              .fontColor('#8E8E93')
          }
          if (nonEmptyText(this.report.organizationName).length > 0) {
            Text(nonEmptyText(this.report.organizationName))
              .fontSize(12)
              .fontColor('#8E8E93')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
    }
    .alignItems(VerticalAlign.Top)
    .layoutWeight(1)
  }

  @Builder
  laboratorySection() {
    Column({ space: 10 }) {
      if (this.report.detailsLoaded) {
        Row({ space: 8 }) {
          this.statCell(`${this.detailItems().length}`, '项目', '#0A84FF', '#0A84FF14')
          this.statCell(`${this.normalCount()}`, '正常', '#34C759', '#34C75914')
          this.statCell(`${this.abnormalCount()}`, '异常', '#FF3B30', '#FF3B3014')
        }
        .width('100%')
      }

      if (this.abnormalPreviewRows().length > 0) {
        this.abnormalDisclosure()
      } else if (this.narrativeFallback().length > 0 && this.report.detailsLoaded) {
        Text(this.narrativeFallback())
          .fontSize(13)
          .fontColor('#3A3A3C')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  abnormalDisclosure() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        Text('!')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .width(16)
          .height(16)
          .textAlign(TextAlign.Center)
          .backgroundColor('#FF9500')
          .borderRadius(8)
        Text('异常要点')
          .fontSize(13)
          .fontColor('#FF9500')
        Blank()
        Text(`${this.abnormalPreviewRows().length}`)
          .fontSize(11)
          .fontColor(Color.White)
          .padding({ left: 6, right: 6, top: 1, bottom: 1 })
          .backgroundColor('#FF9500')
          .borderRadius(6)
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(11)
          .fontColor(['#FF9500'])
          .rotate({ angle: this.isAbnormalExpanded ? 90 : 0 })
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })
      .onClick(() => {
        this.isAbnormalExpanded = !this.isAbnormalExpanded;
      })

      if (this.isAbnormalExpanded) {
        Column({ space: 6 }) {
          ForEach(this.abnormalPreviewRows(), (item: RemoteMedExamDetail) => {
            Text(`${nonEmptyText(item.itemName)}：${this.resultText(item)}`)
              .fontSize(13)
              .fontColor('#3A3A3C')
              .width('100%')
          }, (item: RemoteMedExamDetail) => `abn-${item.id}`)
        }
        .width('100%')
        .padding({ bottom: 10 })
      } else {
        Text('点击展开')
          .fontSize(12)
          .fontColor('#AEAEB2')
          .width('100%')
          .padding({ bottom: 10 })
      }
    }
    .width('100%')
    .backgroundColor('#FF95000D')
    .borderRadius(8)
    .padding({ left: 12, right: 12 })
  }

  @Builder
  imagingSection() {
    Column({ space: 6 }) {
      if (nonEmptyText(this.report.departmentName).length > 0) {
        Text(`科室 ${nonEmptyText(this.report.departmentName)}`)
          .fontSize(13)
          .fontColor('#3A3A3C')
          .width('100%')
      }
      if (nonEmptyText(this.report.doctorName).length > 0) {
        Text(`医生 ${nonEmptyText(this.report.doctorName)}`)
          .fontSize(13)
          .fontColor('#3A3A3C')
          .width('100%')
      }
      if (nonEmptyText(this.report.impression).length > 0) {
        Text(nonEmptyText(this.report.impression))
          .fontSize(13)
          .fontColor('#1C1C1E')
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  pathologySection() {
    Column({ space: 6 }) {
      if (nonEmptyText(this.report.category).length > 0) {
        Text(`分类 ${nonEmptyText(this.report.category)}`)
          .fontSize(13)
          .fontColor('#3A3A3C')
          .width('100%')
      }
      if (nonEmptyText(this.report.subCategory).length > 0) {
        Text(`亚类 ${nonEmptyText(this.report.subCategory)}`)
          .fontSize(13)
          .fontColor('#3A3A3C')
          .width('100%')
      }
      if (nonEmptyText(this.report.findings).length > 0) {
        Text(nonEmptyText(this.report.findings))
          .fontSize(13)
          .fontColor('#1C1C1E')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      if (nonEmptyText(this.report.impression).length > 0) {
        Text(nonEmptyText(this.report.impression))
          .fontSize(13)
          .fontColor('#1C1C1E')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      if (this.pathologyPreviewRows().length > 0) {
        ForEach(this.pathologyPreviewRows(), (item: RemoteMedExamDetail) => {
          Text(`${nonEmptyText(item.itemName)} ${nonEmptyText(item.flag)} ${this.resultText(item)}`)
            .fontSize(12)
            .fontColor('#8E8E93')
            .width('100%')
        }, (item: RemoteMedExamDetail) => `path-${item.id}`)
      }
    }
    .width('100%')
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

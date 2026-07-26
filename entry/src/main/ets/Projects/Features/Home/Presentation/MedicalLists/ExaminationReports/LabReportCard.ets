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
 * 检查报告三类卡片。对齐 iOS `LabReportCard.swift`（实验室/影像/病理分型）。
 * 结构：头部（分类图标 + 标题/副标题 + 日期/机构）+ 分割线 → 加载态 → 分类内容区。
 * 卡片整体使用轻材质卡片视觉（白底 + 细边框 + 阴影），对齐 iOS `.ultraThinMaterial` 卡片观感。
 * 详情入口始终可点（鸿蒙策略，见 HOS-MED-EXAM-0005）：明细懒加载由列表与详情页承接，不在卡片层阻断跳转；
 * 与 iOS「无明细即置灰禁用」的差异以视觉弱化（灰色文案）呈现，但不阻断点击。
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

  private abnormalItems(): RemoteMedExamDetail[] {
    const items = this.detailItems();
    const rows: RemoteMedExamDetail[] = [];
    for (let i = 0; i < items.length; i++) {
      if (isPotentiallyAbnormalFlag(items[i].flag)) {
        rows.push(items[i]);
      }
    }
    return rows;
  }

  private abnormalCount(): number {
    return this.abnormalItems().length;
  }

  private normalCount(): number {
    const total = this.detailItems().length;
    const abnormal = this.abnormalCount();
    return total > abnormal ? total - abnormal : 0;
  }

  /** 是否可进入详情。对齐 iOS `canNavigateToDetail`，仅用于视觉弱化，不阻断鸿蒙实际跳转。 */
  private canNavigateToDetail(): boolean {
    return this.detailItems().length > 0;
  }

  private triggerOpenDetail(): void {
    if (this.onOpenDetail) {
      this.onOpenDetail();
    }
  }

  /** 将 #RRGGBB 与 0–1 透明度合成鸿蒙 #AARRGGBB。 */
  private withAlpha(hex: string, alpha: number): string {
    const a = Math.round(alpha * 255).toString(16).padStart(2, '0').toUpperCase();
    return `#${a}${hex.replace('#', '').toUpperCase()}`;
  }

  private toggleAttachments(): void {
    animateTo({ duration: 260, curve: Curve.Friction }, () => {
      this.isAttachmentsExpanded = !this.isAttachmentsExpanded;
    });
  }

  private toggleAbnormalExpanded(): void {
    animateTo({ duration: 260, curve: Curve.Friction }, () => {
      this.isAbnormalExpanded = !this.isAbnormalExpanded;
    });
  }

  private abnormalPreviewRows(): RemoteMedExamDetail[] {
    const items = this.abnormalItems();
    return items.length > 5 ? items.slice(0, 5) : items;
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

  /** 对齐 iOS `detailText`：印象优先，其次所见，用作无异常明细时的重点信息兜底文案。 */
  private narrativeFallback(): string {
    const impression = nonEmptyText(this.report.impression);
    if (impression.length > 0) {
      return impression;
    }
    return nonEmptyText(this.report.findings);
  }

  private hasNarrativeFallback(): boolean {
    return this.narrativeFallback().length > 0;
  }

  build() {
    Column() {
      // 头部：标题簇 + 日期机构 + 查看详情 + 附件入口。对齐 iOS headerSection，底部叠加分割线。
      Column({ space: 12 }) {
        Row({ space: 8 }) {
          // 头部主信息区：标题、日期、机构点击进入详情（对齐 iOS NavigationLink 头部区域）。
          Column({ space: 12 }) {
            this.titleCluster()
            this.dateMetaRow()
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .onClick(() => {
            this.triggerOpenDetail();
          })

          // 右侧动作区：详情按钮与附件入口各自独立，不得冒泡到头部主信息点击。
          Column({ space: 10 }) {
            this.detailAction()

            MedicalAttachmentIconView({
              count: this.attachments().length,
              isExpanded: this.isAttachmentsExpanded,
              onTap: () => {
                this.toggleAttachments();
              }
            })
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
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.TOP)))
        }
      }
      .padding(16)
      .width('100%')
      .backgroundColor(this.withAlpha('#FFFFFF', 0.05))
      .border({ width: { bottom: 1 }, color: this.withAlpha('#3C3C43', 0.35) })

      if (this.isLoadingDetails) {
        this.loadingSection()
      }

      // 卡片主体内容区点击进入详情；内部可交互块（重点信息展开）自带 onClick，优先消费事件。
      Column() {
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
      .onClick(() => {
        this.triggerOpenDetail();
      })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: this.withAlpha('#FFFFFF', 0.2) })
    .shadow({ radius: 10, color: this.withAlpha('#000000', 0.06), offsetX: 0, offsetY: 4 })
    .clip(true)
  }

  @Builder
  titleCluster() {
    Row({ space: 8 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .fill(this.withAlpha(examinationCategoryTint(this.category()), 0.1))
          .width(40)
          .height(40)
        SymbolGlyph(examinationCategoryIcon(this.category()))
          .fontSize(18)
          .fontColor([examinationCategoryTint(this.category())])
      }
      .width(40)
      .height(40)

      Column({ space: 4 }) {
        Text(this.titleText())
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C1C1E')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.subtitleText().length > 0) {
          Text(this.subtitleText())
            .fontSize(12)
            .fontColor('#8E8E93')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
  }

  /** 对齐 iOS `dateMetaRow`：calendar/building 图标 + 日期、机构名的元信息行。 */
  @Builder
  dateMetaRow() {
    Row({ space: 12 }) {
      if (formatExaminationDateText(this.report).length > 0) {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.calendar'))
            .fontSize(12)
            .fontColor(['#8E8E93'])
          Text(formatExaminationDateText(this.report))
            .fontSize(12)
            .fontColor('#8E8E93')
        }
      }
      if (nonEmptyText(this.report.organizationName).length > 0) {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.building'))
            .fontSize(12)
            .fontColor(['#8E8E93'])
          Text(nonEmptyText(this.report.organizationName))
            .fontSize(12)
            .fontColor('#8E8E93')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
  }

  /** 对齐 iOS `detailAction`：加载中 / 可进入 / 弱化三态，鸿蒙始终允许点击。 */
  @Builder
  detailAction() {
    if (this.isLoadingDetails) {
      Row({ space: 6 }) {
        LoadingProgress().width(14).height(14).color('#0A84FF')
        Text('查看详情')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0A84FF')
      }
      .onClick(() => {
        this.triggerOpenDetail();
      })
    } else if (this.canNavigateToDetail()) {
      Row({ space: 4 }) {
        Text('查看详情')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0A84FF')
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(11)
          .fontColor(['#0A84FF'])
      }
      .onClick(() => {
        this.triggerOpenDetail();
      })
    } else {
      Row({ space: 4 }) {
        Text('查看详情')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#8E8E93')
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(11)
          .fontColor(['#8E8E93'])
      }
      .opacity(0.5)
      .onClick(() => {
        // 鸿蒙策略：无明细时仍允许进入详情，由详情页补拉（对齐 HOS-MED-EXAM-0005）。
        this.triggerOpenDetail();
      })
    }
  }

  @Builder
  loadingSection() {
    Row({ space: 10 }) {
      LoadingProgress().width(16).height(16)
      Text('正在加载明细…')
        .fontSize(12)
        .fontColor('#8E8E93')
      Blank()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.withAlpha('#F2F2F7', 0.65))
    .onClick(() => {
      this.triggerOpenDetail();
    })
  }

  @Builder
  laboratorySection() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        this.statCell(`${this.detailItems().length}`, '检查项', '#007AFF', this.withAlpha('#007AFF', 0.08))
        this.statCell(`${this.normalCount()}`, '正常', '#34C759', this.withAlpha('#34C759', 0.08))
        this.statCell(`${this.abnormalCount()}`, '重点', '#FF3B30', this.withAlpha('#FF3B30', 0.08))
      }
      .width('100%')
      .padding({ bottom: 12 })

      if (this.abnormalItems().length > 0) {
        this.abnormalDisclosure()
      } else if (this.hasNarrativeFallback()) {
        this.narrativeDisclosure()
      }
    }
    .width('100%')
  }

  /** 对齐 iOS `abnormalSection`：橙色可展开重点信息条，展示前 5 条异常明细。 */
  @Builder
  abnormalDisclosure() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill'))
          .fontSize(15)
          .fontColor(['#FF9500'])
        Text('重点信息')
          .fontSize(14)
          .fontColor('#FF9500')
        Blank()
        Text(`${this.abnormalCount()}`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor('#FF9500')
          .borderRadius(6)
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(11)
          .fontColor([this.withAlpha('#FF9500', 0.85)])
          .rotate({ angle: this.isAbnormalExpanded ? 0 : -90 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.withAlpha('#FF9500', 0.05))
      .border({ width: { bottom: 1 }, color: this.withAlpha('#FF9500', 0.1) })
      .onClick(() => {
        this.toggleAbnormalExpanded();
      })

      if (this.isAbnormalExpanded) {
        Column({ space: 6 }) {
          ForEach(this.abnormalPreviewRows(), (item: RemoteMedExamDetail) => {
            Text(`${nonEmptyText(item.itemName)}：${this.resultText(item)}`)
              .fontSize(14)
              .fontColor('#3A3A3C')
              .width('100%')
          }, (item: RemoteMedExamDetail) => `abn-${item.id}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.TOP)))
      } else {
        Text('轻点标题展开重点信息')
          .fontSize(12)
          .fontColor('#8E8E93')
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      }
    }
    .width('100%')
    .backgroundColor(this.withAlpha('#FF9500', 0.05))
    .borderRadius(8)
    .clip(true)
  }

  /** 无异常明细但有印象/所见文案时，仍用同款橙色重点信息条展示纯文本。对齐 iOS 无异常时的 fallback 分支。 */
  @Builder
  narrativeDisclosure() {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill'))
          .fontSize(15)
          .fontColor(['#FF9500'])
        Text('重点信息')
          .fontSize(14)
          .fontColor('#FF9500')
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(11)
          .fontColor([this.withAlpha('#FF9500', 0.85)])
          .rotate({ angle: this.isAbnormalExpanded ? 0 : -90 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.withAlpha('#FF9500', 0.05))
      .border({ width: { bottom: 1 }, color: this.withAlpha('#FF9500', 0.1) })
      .onClick(() => {
        this.toggleAbnormalExpanded();
      })

      if (this.isAbnormalExpanded) {
        Text(this.narrativeFallback())
          .fontSize(14)
          .fontColor('#3A3A3C')
          .width('100%')
          .padding(12)
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.TOP)))
      } else {
        Text('轻点标题展开重点信息')
          .fontSize(12)
          .fontColor('#8E8E93')
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      }
    }
    .width('100%')
    .backgroundColor(this.withAlpha('#FF9500', 0.05))
    .borderRadius(8)
    .clip(true)
  }

  /** 对齐 iOS `infoRow`：label（caption/次要色）+ value（subheadline/主色）同行展示。 */
  @Builder
  infoRow(label: string, value: string) {
    if (value.length > 0) {
      Row({ space: 8 }) {
        Text(label)
          .fontSize(12)
          .fontColor('#8E8E93')
        Text(value)
          .fontSize(15)
          .fontColor('#1C1C1E')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  /** 对齐 iOS `multilineInfoBlock`：label 在上、value 多行在下的纵向信息块。 */
  @Builder
  multilineInfoBlock(label: string, value: string) {
    if (value.length > 0) {
      Column({ space: 4 }) {
        Text(label)
          .fontSize(12)
          .fontColor('#8E8E93')
        Text(value)
          .fontSize(15)
          .fontColor('#1C1C1E')
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
  }

  @Builder
  imagingSection() {
    Column({ space: 12 }) {
      this.infoRow('科室', nonEmptyText(this.report.departmentName))
      this.infoRow('医生', nonEmptyText(this.report.doctorName))
      this.multilineInfoBlock('检查结论', nonEmptyText(this.report.impression))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  pathologySection() {
    Column({ space: 12 }) {
      this.infoRow('分类', nonEmptyText(this.report.category))
      this.infoRow('子分类', nonEmptyText(this.report.subCategory))
      this.multilineInfoBlock('检查所见', nonEmptyText(this.report.findings))
      this.multilineInfoBlock('检查结论', nonEmptyText(this.report.impression))
      this.detailItemsSection()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  /** 对齐 iOS `detailItemsSection`：病理明细卡片化列表，前 5 条。 */
  @Builder
  detailItemsSection() {
    if (this.pathologyPreviewRows().length > 0) {
      Column({ space: 8 }) {
        Text('明细')
          .fontSize(12)
          .fontColor('#8E8E93')

        ForEach(this.pathologyPreviewRows(), (item: RemoteMedExamDetail) => {
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(nonEmptyText(item.itemName))
                .fontSize(15)
                .fontColor('#1C1C1E')
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(nonEmptyText(item.flag).length > 0 ? nonEmptyText(item.flag) : nonEmptyText(item.resultValue))
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(isPotentiallyAbnormalFlag(item.flag) ? '#FF3B30' : '#8E8E93')
            }
            .width('100%')

            Text(this.resultText(item))
              .fontSize(12)
              .fontColor('#8E8E93')
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(10)
          .backgroundColor('#F2F2F7')
          .borderRadius(8)
        }, (item: RemoteMedExamDetail) => `path-${item.id}`)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
  }

  @Builder
  statCell(value: string, label: string, textColor: string, bg: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(textColor)
      Text(label)
        .fontSize(11)
        .fontColor('#8E8E93')
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .backgroundColor(bg)
    .borderRadius(8)
    .alignItems(HorizontalAlign.Center)
  }
}

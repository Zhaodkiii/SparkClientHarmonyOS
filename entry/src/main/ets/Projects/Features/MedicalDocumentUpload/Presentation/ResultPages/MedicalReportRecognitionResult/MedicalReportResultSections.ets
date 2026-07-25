import { MedicalReportRecognitionDraft } from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicalDocumentResultSectionCard } from '../MedicalDocumentResultSupport';
import { MedicalDocumentResultDetailNavigationSupport } from '../MedicalDocumentResultDetailNavigationSupport';
import { MedicalValidationIssueInlineView } from '../PreSubmitValidation/MedicalValidationIssueInlineView';
import { ExaminationReportCategory } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportCategory';
import { CategoryCount, MedicalReportResultSupport } from './MedicalReportResultSupport';
import { CaseMatchedAttachmentsGridView } from '../CaseMatchedAttachmentsGridView';

/**
 * 分类分组的检查报告卡片。对齐 iOS `MedicalReportCardsSectionView`：
 * 按检验 / 影像 / 病理分组，卡片可跳转本地草稿详情页。
 */
@Component
export struct MedicalReportCardsSectionView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  onOpenCardDetail: (index: number, category: ExaminationReportCategory) => void = () => {};
  onManageAttachments: (index: number) => void = () => {};

  private reports(): MedicalReportRecognitionDraft[] {
    return MedicalReportResultSupport.reports(this.viewModel);
  }

  private indexedByCategory(category: ExaminationReportCategory): number[] {
    const list = this.reports();
    const indices: number[] = [];
    for (let i = 0; i < list.length; i++) {
      if (MedicalReportResultSupport.categoryOf(list[i].category) === category) {
        indices.push(i);
      }
    }
    return indices;
  }

  private hasCardIssues(index: number): boolean {
    return MedicalReportResultSupport.cardIssues(this.viewModel, index).length > 0;
  }

  private canOpenDetail(): boolean {
    return MedicalDocumentResultDetailNavigationSupport.makeContext(
      this.viewModel.selectedMemberID,
      this.viewModel
    ) !== undefined;
  }

  private cardMetaText(report: MedicalReportRecognitionDraft): string {
    const parts: string[] = [];
    if ((report.hospital ?? '').length > 0) {
      parts.push(report.hospital ?? '');
    }
    if ((report.doctor ?? '').length > 0) {
      parts.push(report.doctor ?? '');
    }
    if ((report.date ?? '').length > 0) {
      parts.push(report.date ?? '');
    }
    return parts.join(' · ');
  }

  private openDetail(index: number, category: ExaminationReportCategory): void {
    if (!this.canOpenDetail()) {
      return;
    }
    this.onOpenCardDetail(index, category);
  }

  private issueLines(index: number): string[] {
    return MedicalReportResultSupport.issueSummaryLines(this.viewModel, index);
  }

  @Builder
  private CategoryHeader(category: ExaminationReportCategory, count: number) {
    Row({ space: 6 }) {
      Text(MedicalReportResultSupport.categoryTitle(category))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(MedicalReportResultSupport.categoryTint(category))
      Text(`${count}`)
        .fontSize(11)
        .fontColor('#8E8E93')
        .padding({ left: 6, right: 6, top: 1, bottom: 1 })
        .backgroundColor('#F2F2F7')
        .borderRadius(6)
    }
    .width('100%')
  }

  @Builder
  private CardClinicalText(report: MedicalReportRecognitionDraft, category: ExaminationReportCategory) {
    if (category === 'imaging' || category === 'pathology') {
      Column({ space: 6 }) {
        if (MedicalReportResultSupport.resolvedFindingsText(report).length > 0) {
          Text('所见')
            .fontSize(11)
            .fontColor('#8E8E93')
            .width('100%')
          Text(MedicalReportResultSupport.resolvedFindingsText(report))
            .fontSize(14)
            .fontColor('#1C1C1E')
            .width('100%')
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (MedicalReportResultSupport.resolvedImpressionText(report).length > 0 &&
          MedicalReportResultSupport.resolvedImpressionText(report) !==
          MedicalReportResultSupport.resolvedFindingsText(report)) {
          Text('印象')
            .fontSize(11)
            .fontColor('#8E8E93')
            .width('100%')
          Text(MedicalReportResultSupport.resolvedImpressionText(report))
            .fontSize(14)
            .fontColor('#1C1C1E')
            .width('100%')
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else {
      Text(report.content && report.content.length > 0 ? report.content : '-')
        .fontSize(14)
        .fontColor('#1C1C1E')
        .width('100%')
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  @Builder
  private MatchedAttachments(index: number, report: MedicalReportRecognitionDraft) {
    if (this.viewModel.typedDraftRevision >= 0 && report.attachmentFileIds.length > 0) {
      CaseMatchedAttachmentsGridView({
        title: '匹配附件',
        attachments: MedicalReportResultSupport.matchedAttachments(this.viewModel, report.attachmentFileIds),
        onManage: () => {
          this.onManageAttachments(index);
        }
      })
    }
  }

  @Builder
  private IssueLines(index: number) {
    Column({ space: 4 }) {
      ForEach(this.issueLines(index), (line: string) => {
        MedicalValidationIssueInlineView({ message: line })
      }, (line: string, i: number): string => `mr-issue-${index}-${i}-${line}`)
    }
    .width('100%')
  }

  @Builder
  private ReportCard(index: number, report: MedicalReportRecognitionDraft, category: ExaminationReportCategory) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(report.title.length > 0 ? report.title : '未填写')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.hasCardIssues(index) ? '#C93400' : '#1C1C1E')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.hasCardIssues(index)) {
          Text('!')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .width(18)
            .height(18)
            .textAlign(TextAlign.Center)
            .backgroundColor('#FF3B30')
            .borderRadius(9)
        }
        if (this.canOpenDetail()) {
          Text('›')
            .fontSize(18)
            .fontColor('#C7C7CC')
        }
      }
      .width('100%')

      this.IssueLines(index)

      if (this.cardMetaText(report).length > 0) {
        Text(this.cardMetaText(report))
          .fontSize(12)
          .fontColor('#8E8E93')
          .width('100%')
      }

      this.CardClinicalText(report, category)

      if (report.details.length > 0) {
        Text(`${report.details.length} 项明细`)
          .fontSize(12)
          .fontColor(MedicalReportResultSupport.categoryTint(category))
      }

      this.MatchedAttachments(index, report)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.hasCardIssues(index) ? '#FFF9F7' : '#FFFFFF')
    .borderRadius(12)
    .border({ width: this.hasCardIssues(index) ? 1 : 0, color: '#FFD9CC' })
    .id(`preSubmitValidation.card.examinationReport.${index}`)
    .onClick(() => {
      this.openDetail(index, category);
    })
  }

  @Builder
  private CategoryBlock(category: ExaminationReportCategory, indices: number[]) {
    if (indices.length > 0) {
      Column({ space: 10 }) {
        this.CategoryHeader(category, indices.length)
        ForEach(indices, (index: number) => {
          this.ReportCard(index, this.reports()[index], category)
        }, (index: number): string => {
          const report = this.reports()[index];
          return `mr-card-${index}-${this.viewModel.typedDraftRevision}-` +
            `${report.attachmentFileIds.join(',')}`;
        })
      }
      .width('100%')
    }
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 2 }) {
          Text('检查报告明细')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1C1E')
          Text('点击查看或编辑报告详情')
            .fontSize(12)
            .fontColor('#8E8E93')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text(`共 ${this.reports().length}`)
          .fontSize(12)
          .fontColor('#8E8E93')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#F2F2F7')
          .borderRadius(8)
        Text('新增')
          .fontSize(13)
          .fontColor('#0A84FF')
          .margin({ left: 10 })
          .onClick(() => {
            MedicalReportResultSupport.addReport(this.viewModel);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.reports().length === 0) {
        Column({ space: 8 }) {
          Text('暂无报告草稿')
            .fontSize(14)
            .fontColor('#8E8E93')
            .width('100%')
            .textAlign(TextAlign.Center)
          Text('点击「新增」添加一条检查报告')
            .fontSize(12)
            .fontColor('#AEAEB2')
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })
      } else {
        this.CategoryBlock('laboratory', this.indexedByCategory('laboratory'))
        this.CategoryBlock('imaging', this.indexedByCategory('imaging'))
        this.CategoryBlock('pathology', this.indexedByCategory('pathology'))
      }
    }
    .width('100%')
  }
}

/**
 * 检查报告统计概览（独立区块，供其他场景复用）。
 * 识别结果页请使用 `MedicalReportMemberConfirmSectionView`。
 */
@Component
export struct MedicalReportStatsSectionView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  private counts(): CategoryCount[] {
    return MedicalReportResultSupport.categoryCounts(MedicalReportResultSupport.reports(this.viewModel));
  }

  @Builder
  private StatChip(item: CategoryCount) {
    Column({ space: 6 }) {
      Text(MedicalReportResultSupport.categoryTitle(item.category))
        .fontSize(12)
        .fontColor('#8E8E93')
        .width('100%')
      Text(`${item.count}`)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(MedicalReportResultSupport.categoryTint(item.category))
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(10)
    .backgroundColor('#F2F2F7')
    .borderRadius(12)
  }

  @Builder
  private StatsContent() {
    Row({ space: 10 }) {
      ForEach(this.counts(), (item: CategoryCount) => {
        this.StatChip(item)
      }, (item: CategoryCount): string => `stat-${item.category}`)
    }
    .width('100%')
  }

  build() {
    MedicalDocumentResultSectionCard({
      title: '检查报告统计',
      subtitle: '按检验 / 影像 / 病理分类统计报告数量',
      content: () => {
        this.StatsContent()
      }
    })
  }
}

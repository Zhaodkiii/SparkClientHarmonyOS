import {
  HealthExamRecognitionDraft,
  MedicalReportItem
} from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import {
  MedicalDocumentResultSectionCard,
  MedicalValidatedEditableField
} from '../MedicalDocumentResultSupport';
import { HealthExamRiskCounts, HealthExamResultSupport } from './HealthExamResultSupport';

@Component
export struct HealthExamBasicInfoEditorView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  private draft(): HealthExamRecognitionDraft {
    return HealthExamResultSupport.ensureDraft(this.viewModel);
  }

  @Builder
  private BasicFields() {
    Column({ space: 10 }) {
      MedicalValidatedEditableField({
        label: '体检机构',
        value: this.draft().institutionName ?? '',
        fieldKey: 'health_exam.institution_name',
        scrollTargetID: 'preSubmitValidation.field.health_exam.institution_name',
        errorMessage: HealthExamResultSupport.err(this.viewModel, 'health_exam.institution_name'),
        onValueChange: (v: string) => {
          this.draft().institutionName = v;
          this.viewModel.notifyTypedDraftChanged(['health_exam.institution_name']);
        }
      })
      MedicalValidatedEditableField({
        label: '报告号',
        value: this.draft().reportNo ?? '',
        onValueChange: (v: string) => {
          this.draft().reportNo = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '体检日期',
        value: this.draft().examDate ?? '',
        placeholder: 'yyyy-MM-dd',
        fieldKey: 'health_exam.exam_date',
        scrollTargetID: 'preSubmitValidation.field.health_exam.exam_date',
        errorMessage: HealthExamResultSupport.err(this.viewModel, 'health_exam.exam_date'),
        onValueChange: (v: string) => {
          this.draft().examDate = v;
          this.viewModel.notifyTypedDraftChanged(['health_exam.exam_date']);
        }
      })
      MedicalValidatedEditableField({
        label: '体检类型',
        value: this.draft().examType ?? '',
        onValueChange: (v: string) => {
          this.draft().examType = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '综述',
        value: this.draft().summary ?? '',
        onValueChange: (v: string) => {
          this.draft().summary = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
    }
    .width('100%')
  }

  build() {
    MedicalDocumentResultSectionCard({
      title: '基础信息',
      subtitle: '机构 / 报告号 / 日期',
      content: () => {
        this.BasicFields()
      }
    })
  }
}

@Component
export struct HealthExamRiskOverviewSectionView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  private counts(): HealthExamRiskCounts {
    return HealthExamResultSupport.riskCounts(
      HealthExamResultSupport.ensureDraft(this.viewModel));
  }

  @Builder
  private RiskChip(title: string, value: string, color: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
      Text(title)
        .fontSize(12)
        .fontColor('#8E8E93')
    }
    .layoutWeight(1)
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Row({ space: 10 }) {
      this.RiskChip('高风险', `${this.counts().high}`, '#C93400')
      this.RiskChip('中风险', `${this.counts().medium}`, '#D97706')
      this.RiskChip('低风险', `${this.counts().low}`, '#0A7A4B')
    }
    .width('100%')
  }
}

@Component
export struct HealthExamItemsSectionView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  @Prop filterMode: string = 'all';
  onFilterChange: (mode: string) => void = (_mode: string) => {};

  private draft(): HealthExamRecognitionDraft {
    return HealthExamResultSupport.ensureDraft(this.viewModel);
  }

  private visibleItems(): MedicalReportItem[] {
    return HealthExamResultSupport.visibleItems(this.draft(), this.filterMode);
  }

  @Builder
  private FilterChip(label: string, mode: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.filterMode === mode ? Color.White : '#0A84FF')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.filterMode === mode ? '#0A84FF' : '#E8F2FF')
      .borderRadius(14)
      .onClick(() => this.onFilterChange(mode))
  }

  @Builder
  private ItemRow(item: MedicalReportItem, index: number) {
    Column({ space: 4 }) {
      Text(item.itemName ?? `项目 ${index + 1}`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
        .width('100%')
      Text(`${item.resultValue ?? '—'} ${item.unit ?? ''}`.trim())
        .fontSize(13)
        .fontColor('#3C3C43')
        .width('100%')
      if ((item.referenceRange ?? '').length > 0) {
        Text(`参考：${item.referenceRange}`)
          .fontSize(12)
          .fontColor('#8E8E93')
          .width('100%')
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#F7F7F9')
    .borderRadius(10)
    .id(`preSubmitValidation.card.healthExamReport.item.${index}`)
  }

  @Builder
  private ItemsContent() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        this.FilterChip('全部', 'all')
        this.FilterChip('异常', 'abnormal')
        this.FilterChip('正常', 'normal')
      }
      .width('100%')

      if (this.visibleItems().length === 0) {
        Text('暂无明细项，可保存后补充')
          .fontSize(13)
          .fontColor('#8E8E93')
          .width('100%')
      } else {
        ForEach(this.visibleItems(), (item: MedicalReportItem, index: number) => {
          this.ItemRow(item, index)
        }, (item: MedicalReportItem, index: number): string => {
          return `he-item-${index}-${item.itemName ?? ''}-${item.resultValue ?? ''}`;
        })
      }
    }
    .width('100%')
  }

  build() {
    MedicalDocumentResultSectionCard({
      title: '检查明细',
      badgeText: `${this.draft().items.length}`,
      content: () => {
        this.ItemsContent()
      }
    })
  }
}

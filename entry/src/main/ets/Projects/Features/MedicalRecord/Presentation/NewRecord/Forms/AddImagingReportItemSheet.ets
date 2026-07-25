import { ItemDraft } from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { ExaminationReportDraftMapping } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDraftMapping';
import { ExamFormBottomBar, ExamFormTextAreaField, ExamFormTextField } from './ExamFormFieldSupport';

/**
 * 影像检查子项编辑页。对齐 iOS `AddImagingReportItemSheet`。
 */
@Component
export struct AddImagingReportItemSheet {
  @Prop initialDraft: ItemDraft = new ItemDraft();
  onSubmit?: (draft: ItemDraft) => void;
  onCancel?: () => void;

  @State private category: string = '';
  @State private subCategory: string = '';
  @State private itemName: string = '';
  @State private modality: string = '';
  @State private bodyPart: string = '';
  @State private resultAt: string = '';
  @State private diagnosis: string = '';
  @State private flag: string = '';
  @State private itemId: string = '';

  aboutToAppear(): void {
    const draft = ExaminationReportDraftMapping.cloneItemDraft(this.initialDraft);
    this.itemId = draft.id.length > 0 ? draft.id : ExaminationReportDraftMapping.newItemId();
    this.category = draft.category ?? '';
    this.subCategory = draft.subCategory ?? '';
    this.itemName = draft.itemName ?? '';
    this.modality = draft.modality ?? '';
    this.bodyPart = draft.bodyPart ?? '';
    this.resultAt = (draft.resultAt ?? '').length > 0 ?
      (draft.resultAt ?? '') : ExaminationReportDraftMapping.todayDateText();
    this.diagnosis = draft.diagnosis ?? '';
    this.flag = draft.flag ?? '';
  }

  private canSubmit(): boolean {
    return this.category.trim().length > 0
      && this.itemName.trim().length > 0
      && this.modality.trim().length > 0
      && this.bodyPart.trim().length > 0
      && this.diagnosis.trim().length > 0;
  }

  private submit(): void {
    const draft = new ItemDraft();
    draft.id = this.itemId;
    draft.category = this.category.trim();
    draft.subCategory = this.subCategory.trim().length > 0 ? this.subCategory.trim() : undefined;
    draft.itemName = this.itemName.trim();
    draft.modality = this.modality.trim();
    draft.bodyPart = this.bodyPart.trim();
    draft.resultAt = this.resultAt.trim();
    draft.diagnosis = this.diagnosis.trim();
    draft.flag = this.flag.trim().length > 0 ? this.flag.trim() : undefined;
    if (this.onSubmit) {
      this.onSubmit(draft);
    }
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 14 }) {
          Text('影像检查项目')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')

          ExamFormTextField({
            label: '检查分类',
            placeholder: '如 放射检查',
            required: true,
            value: $category
          })
          ExamFormTextField({
            label: '子分类',
            placeholder: '可选',
            value: $subCategory
          })
          ExamFormTextField({
            label: '项目名称',
            placeholder: '如 胸部 CT',
            required: true,
            value: $itemName
          })
          Row({ space: 12 }) {
            Column() {
              ExamFormTextField({
                label: '检查方式',
                placeholder: 'CT / MRI',
                required: true,
                value: $modality
              })
            }
            .layoutWeight(1)
            Column() {
              ExamFormTextField({
                label: '检查部位',
                placeholder: '如 胸部',
                required: true,
                value: $bodyPart
              })
            }
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          ExamFormTextField({
            label: '检查日期',
            placeholder: 'yyyy-MM-dd',
            value: $resultAt
          })
          ExamFormTextAreaField({
            label: '所见与结论',
            placeholder: '填写影像所见与诊断结论',
            value: $diagnosis
          })
          ExamFormTextField({
            label: '标记（可选）',
            placeholder: '异常标记',
            value: $flag
          })
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)

      ExamFormBottomBar({
        canSubmit: this.canSubmit(),
        saveTitle: '完成',
        onCancel: () => {
          if (this.onCancel) {
            this.onCancel();
          }
        },
        onSave: () => {
          this.submit();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
  }
}

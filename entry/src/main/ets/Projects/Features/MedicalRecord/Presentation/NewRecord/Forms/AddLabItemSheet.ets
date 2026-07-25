import { ItemDraft } from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { ExaminationReportDraftMapping } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDraftMapping';
import {
  ExamFormBottomBar,
  ExamFormTextAreaField,
  ExamFormTextField,
  SPARK_LAB_COMMON_UNITS,
  SPARK_LAB_FLAG_OPTIONS,
  SPARK_LAB_MORE_UNITS
} from './ExamFormFieldSupport';

/**
 * 检验子项编辑页。对齐 iOS `AddLabItemSheet`。
 */
@Component
export struct AddLabItemSheet {
  @Prop initialDraft: ItemDraft = new ItemDraft();
  onSubmit?: (draft: ItemDraft) => void;
  onCancel?: () => void;

  @State private itemName: string = '';
  @State private resultValue: string = '';
  @State private unit: string = 'g/L';
  @State private referenceRange: string = '';
  @State private flag: string = '正常';
  @State private category: string = '';
  @State private subCategory: string = '';
  @State private itemId: string = '';

  aboutToAppear(): void {
    const draft = ExaminationReportDraftMapping.cloneItemDraft(this.initialDraft);
    this.itemId = draft.id.length > 0 ? draft.id : ExaminationReportDraftMapping.newItemId();
    this.itemName = draft.itemName ?? '';
    this.resultValue = draft.resultValue ?? '';
    this.unit = (draft.unit ?? '').length > 0 ? (draft.unit ?? 'g/L') : 'g/L';
    this.referenceRange = draft.referenceRange ?? '';
    this.flag = (draft.flag ?? '').length > 0 ? (draft.flag ?? '正常') : '正常';
    this.category = draft.category ?? '';
    this.subCategory = draft.subCategory ?? '';
  }

  private canSubmit(): boolean {
    return this.itemName.trim().length > 0
      && this.resultValue.trim().length > 0
      && this.unit.trim().length > 0
      && this.flag.trim().length > 0;
  }

  private submit(): void {
    const draft = new ItemDraft();
    draft.id = this.itemId;
    draft.itemName = this.itemName.trim();
    draft.resultValue = this.resultValue.trim();
    draft.unit = this.unit.trim();
    draft.referenceRange = this.referenceRange.trim().length > 0 ? this.referenceRange.trim() : undefined;
    draft.flag = this.flag.trim();
    draft.category = this.category.trim().length > 0 ? this.category.trim() : undefined;
    draft.subCategory = this.subCategory.trim().length > 0 ? this.subCategory.trim() : undefined;
    if (this.onSubmit) {
      this.onSubmit(draft);
    }
  }

  @Builder
  private unitChip(unitValue: string) {
    Text(unitValue)
      .fontSize(12)
      .fontColor(this.unit === unitValue ? '#FFFFFF' : '#0A84FF')
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(this.unit === unitValue ? '#0A84FF' : '#EAF3FF')
      .borderRadius(14)
      .onClick(() => {
        this.unit = unitValue;
      })
  }

  @Builder
  private flagChip(flagValue: string) {
    Text(flagValue)
      .fontSize(12)
      .fontColor(this.flag === flagValue ? '#FFFFFF' : '#5856D6')
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(this.flag === flagValue ? '#5856D6' : '#F2F0FF')
      .borderRadius(14)
      .onClick(() => {
        this.flag = flagValue;
      })
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 14 }) {
          Text('检验项目')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')

          Row({ space: 12 }) {
            Column() {
              ExamFormTextField({
                label: '项目名称',
                placeholder: '如 血红蛋白',
                required: true,
                value: $itemName
              })
            }
            .layoutWeight(1)

            Column() {
              ExamFormTextField({
                label: '结果',
                placeholder: '数值或文本',
                required: true,
                value: $resultValue
              })
            }
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          Column({ space: 8 }) {
            Text('单位 *')
              .fontSize(13)
              .fontColor('#666666')
              .width('100%')
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(SPARK_LAB_COMMON_UNITS, (unitValue: string) => {
                this.unitChip(unitValue)
              }, (unitValue: string): string => `lab-unit-common-${unitValue}`)
              ForEach(SPARK_LAB_MORE_UNITS, (unitValue: string) => {
                this.unitChip(unitValue)
              }, (unitValue: string): string => `lab-unit-more-${unitValue}`)
            }
            .width('100%')
            TextInput({ text: this.unit, placeholder: '自定义单位' })
              .width('100%')
              .height(40)
              .fontSize(15)
              .backgroundColor('#F2F2F7')
              .borderRadius(8)
              .onChange((text: string) => {
                this.unit = text;
              })
          }
          .width('100%')

          ExamFormTextField({
            label: '参考范围',
            placeholder: '如 3.5-9.5',
            value: $referenceRange
          })

          Column({ space: 8 }) {
            Text('结果状态 *')
              .fontSize(13)
              .fontColor('#666666')
              .width('100%')
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(SPARK_LAB_FLAG_OPTIONS, (flagValue: string) => {
                this.flagChip(flagValue)
              }, (flagValue: string): string => `lab-flag-${flagValue}`)
            }
            .width('100%')
          }
          .width('100%')

          ExamFormTextField({
            label: '分类（可选）',
            placeholder: '一级分类',
            value: $category
          })
          ExamFormTextField({
            label: '子分类（可选）',
            placeholder: '二级分类',
            value: $subCategory
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

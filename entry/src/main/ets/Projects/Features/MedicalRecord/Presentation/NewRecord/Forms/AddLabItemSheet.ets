import { ItemDraft } from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { ExaminationReportDraftMapping } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDraftMapping';
import {
  EXAM_FORM_PAGE_BACKGROUND,
  ExamFormBottomBar,
  ExamFormDivider,
  ExamFormInlineHeadline,
  ExamFormMenuCustomRow,
  ExamFormMenuSection,
  ExamFormSheetHeader,
  ExamFormTextField,
  SPARK_LAB_COMMON_UNITS,
  SPARK_LAB_FLAG_OPTIONS,
  SPARK_LAB_MORE_UNITS,
  SparkLabExamCategoryCascadeRow
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
  @State private sheetKeyboardVisible: boolean = false;

  aboutToAppear(): void {
    const draft = ExaminationReportDraftMapping.cloneItemDraft(this.initialDraft);
    this.itemId = draft.id.length > 0 ? draft.id : ExaminationReportDraftMapping.newItemId();
    this.itemName = draft.itemName ?? '';
    this.resultValue = draft.resultValue ?? '';
    const unitText = (draft.unit ?? '').trim();
    this.unit = unitText.length > 0 ? unitText : (SPARK_LAB_COMMON_UNITS[0] ?? 'g/L');
    this.referenceRange = draft.referenceRange ?? '';
    const flagText = (draft.flag ?? '').trim();
    this.flag = flagText.length > 0 ? flagText : '正常';
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

  private unitSections(): ExamFormMenuSection[] {
    return [
      new ExamFormMenuSection('常用单位', SPARK_LAB_COMMON_UNITS),
      new ExamFormMenuSection('更多单位', SPARK_LAB_MORE_UNITS)
    ];
  }

  private flagSections(): ExamFormMenuSection[] {
    return [
      new ExamFormMenuSection('', SPARK_LAB_FLAG_OPTIONS)
    ];
  }

  private keyboardFocusChanged(visible: boolean): void {
    this.sheetKeyboardVisible = visible;
  }

  private dismissKeyboard(): void {
    this.sheetKeyboardVisible = false;
  }

  @Builder
  private formBody() {
    Column({ space: 16 }) {
      ExamFormInlineHeadline({ title: '新增检验项' })

      Row({ space: 12 }) {
        Column() {
          ExamFormTextField({
            label: '项目',
            placeholder: '如：血红蛋白',
            required: true,
            value: $itemName,
            onKeyboardFocus: (visible: boolean): void => {
              this.keyboardFocusChanged(visible);
            }
          })
        }
        .layoutWeight(1)

        Column() {
          ExamFormTextField({
            label: '结果',
            placeholder: '如：142',
            required: true,
            value: $resultValue,
            onKeyboardFocus: (visible: boolean): void => {
              this.keyboardFocusChanged(visible);
            }
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      ExamFormMenuCustomRow({
        label: '单位',
        required: true,
        sections: this.unitSections(),
        customMenuTitle: '自定义单位',
        customPlaceholder: '输入自定义单位',
        customAutofocus: true,
        value: $unit,
        onKeyboardFocus: (visible: boolean): void => {
          this.keyboardFocusChanged(visible);
        }
      })

      ExamFormTextField({
        label: '参考范围',
        placeholder: '如：115-150',
        value: $referenceRange,
        onKeyboardFocus: (visible: boolean): void => {
          this.keyboardFocusChanged(visible);
        }
      })

      ExamFormMenuCustomRow({
        label: '状态',
        required: true,
        sections: this.flagSections(),
        customMenuTitle: '自定义状态',
        customPlaceholder: '输入自定义状态',
        showLeadingIcon: true,
        customAutofocus: true,
        value: $flag,
        onKeyboardFocus: (visible: boolean): void => {
          this.keyboardFocusChanged(visible);
        }
      })

      ExamFormDivider({ verticalPadding: 8 })

      Text('分类（可选覆盖表单顶部一级/二级）')
        .fontSize(12)
        .fontColor('#8E8E93')
        .width('100%')
        .lineHeight(16)

      SparkLabExamCategoryCascadeRow({
        primaryTitle: '分类',
        secondaryTitle: '子分类',
        primaryPlaceholder: '如：血常规',
        secondaryPlaceholder: '如：肝功能（可选）',
        primaryRequired: false,
        primary: $category,
        secondary: $subCategory,
        onKeyboardFocus: (visible: boolean): void => {
          this.keyboardFocusChanged(visible);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      ExamFormSheetHeader({ title: '新增检验项' })

      Scroll() {
        this.formBody()
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 16, right: 16, top: 4, bottom: 24 })

      ExamFormBottomBar({
        canSubmit: this.canSubmit(),
        saveTitle: '完成',
        keyboardVisible: this.sheetKeyboardVisible,
        onKeyboardDone: (): void => {
          this.dismissKeyboard();
        },
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
    .backgroundColor(EXAM_FORM_PAGE_BACKGROUND)
  }
}

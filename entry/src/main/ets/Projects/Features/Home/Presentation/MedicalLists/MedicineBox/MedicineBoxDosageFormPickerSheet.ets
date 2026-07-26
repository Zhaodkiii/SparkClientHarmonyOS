import { MedicineBoxDosageFormCatalog } from './MedicineBoxDosageFormCatalog';
import { EXAM_FORM_PAGE_BACKGROUND, ExamFormSheetHeader } from
  '../../../../MedicalRecord/Presentation/NewRecord/Forms/ExamFormFieldSupport';

/** 剂型选择 Sheet。对齐 iOS `MedicineBoxDosageFormPickerSheet`。 */
@Component
export struct MedicineBoxDosageFormPickerSheet {
  @Prop selectedValue: string = '';
  onSelect?: (value: string) => void;
  onClose?: () => void;

  @Builder
  private optionRow(value: string) {
    Row({ space: 12 }) {
      Text(value)
        .fontSize(17)
        .fontColor('#1C1C1E')
        .layoutWeight(1)
      if (this.selectedValue.trim() === value) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(16)
          .fontColor(['#0A84FF'])
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      if (this.onSelect) {
        this.onSelect(value);
      }
    })
  }

  @Builder
  private section(title: string, options: string[]) {
    Column({ space: 0 }) {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#3C3C43')
        .width('100%')
        .padding({ left: 4, bottom: 8 })
      Column() {
        ForEach(options, (option: string, index: number) => {
          Column() {
            this.optionRow(option)
            if (index < options.length - 1) {
              Divider().color('#EBEBF0').strokeWidth(0.5).margin({ left: 16, right: 16 })
            }
          }
        }, (option: string): string => option)
      }
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(16)
      .shadow({
        radius: 10,
        color: '#14000000',
        offsetX: 0,
        offsetY: 2
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      ExamFormSheetHeader({ title: '选取剂型' })

      Scroll() {
        Column({ space: 20 }) {
          this.section('常见形式', MedicineBoxDosageFormCatalog.commonForms)
          this.section('更多形式', MedicineBoxDosageFormCatalog.moreForms)
          Blank().height(24)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(EXAM_FORM_PAGE_BACKGROUND)
  }
}

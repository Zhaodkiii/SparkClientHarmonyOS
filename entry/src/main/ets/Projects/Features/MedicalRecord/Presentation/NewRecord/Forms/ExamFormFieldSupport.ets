/** 检验常用单位。对齐 iOS `sparkLabCommonUnits` / `sparkLabMoreUnits`。 */
export const SPARK_LAB_COMMON_UNITS: string[] = [
  'g/L', '10^9/L', '10^12/L', '%', 'fL', 'pg', 'U/L', 'IU/L'
];

export const SPARK_LAB_MORE_UNITS: string[] = [
  'mmol/L', 'μmol/L', 'mg/L', 'ng/mL', 'pmol/L', 'mIU/L', 'IU/mL',
  'mmHg', '次/分', '℃', 'μg/L', 'nmol/L'
];

export const SPARK_LAB_FLAG_OPTIONS: string[] = [
  '正常', '偏高', '偏低', '异常', '↑', '↓', 'H', 'L'
];

/**
 * 表单通用字段行。对齐 iOS `SparkFormTextRow` 的简化 ArkUI 版本。
 */
@Component
export struct ExamFormTextField {
  @Prop label: string = '';
  @Prop placeholder: string = '';
  @Prop required: boolean = false;
  @Link value: string;

  build() {
    Column({ space: 4 }) {
      Row({ space: 4 }) {
        Text(this.label)
          .fontSize(13)
          .fontColor('#666666')
        if (this.required) {
          Text('*')
            .fontSize(13)
            .fontColor('#FF3B30')
        }
      }
      .width('100%')

      TextInput({ text: this.value, placeholder: this.placeholder })
        .width('100%')
        .height(40)
        .fontSize(15)
        .backgroundColor('#F2F2F7')
        .borderRadius(8)
        .onChange((text: string) => {
          this.value = text;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct ExamFormTextAreaField {
  @Prop label: string = '';
  @Prop placeholder: string = '';
  @Link value: string;

  build() {
    Column({ space: 4 }) {
      Text(this.label)
        .fontSize(13)
        .fontColor('#666666')
        .width('100%')
      TextArea({ text: this.value, placeholder: this.placeholder })
        .width('100%')
        .height(96)
        .fontSize(15)
        .backgroundColor('#F2F2F7')
        .borderRadius(8)
        .onChange((text: string) => {
          this.value = text;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct ExamFormBottomBar {
  @Prop canSubmit: boolean = true;
  @Prop saveTitle: string = '保存';
  onCancel?: () => void;
  onSave?: () => void;

  build() {
    Row({ space: 12 }) {
      Button('取消')
        .layoutWeight(1)
        .backgroundColor('#F2F2F7')
        .fontColor('#1C1C1E')
        .onClick(() => {
          if (this.onCancel) {
            this.onCancel();
          }
        })
      Button(this.saveTitle)
        .layoutWeight(1)
        .backgroundColor(this.canSubmit ? '#0A84FF' : '#C7C7CC')
        .fontColor(Color.White)
        .enabled(this.canSubmit)
        .onClick(() => {
          if (this.canSubmit && this.onSave) {
            this.onSave();
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }
}

/** 字段级 inline 校验文案。对齐 iOS inline validation hint。 */
@Component
export struct MedicalValidationIssueInlineView {
  @Prop message: string = '';

  build() {
    if (this.message.length === 0) {
      Column() {}
    } else {
      Text(this.message)
        .fontSize(12)
        .fontColor('#C93400')
        .width('100%')
    }
  }
}

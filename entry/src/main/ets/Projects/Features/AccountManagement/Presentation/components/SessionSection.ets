@Component
export struct SessionSection {
  @Prop signingOut: boolean = false;
  onSignOut?: () => void;

  build() {
    Column() {
      Text($r('app.string.account_section_session'))
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .margin({ bottom: 8 })

      Row() {
        Text($r('app.string.account_sign_out'))
          .fontSize(16)
          .fontColor('#FF3B30')
          .layoutWeight(1)
        if (this.signingOut) {
          LoadingProgress().width(20).height(20)
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .onClick(() => {
        if (!this.signingOut && this.onSignOut) {
          this.onSignOut();
        }
      })
    }
    .width('100%')
  }
}

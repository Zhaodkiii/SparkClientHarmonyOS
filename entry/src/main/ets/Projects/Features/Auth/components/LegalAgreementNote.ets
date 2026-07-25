/**
 * 对应 iOS LoginLegalAgreementNote：勾选行只打开协议半屏，不直接 toggle。
 */
@Component
export struct LegalAgreementNote {
  @Prop hasAgreed: boolean = false;
  @Prop @Watch('onShakeTriggerChanged') shakeTrigger: number = 0;
  @Prop showsValidationHighlight: boolean = false;
  onOpenAgreementPrompt: () => void = () => {
  };

  @State private shakeOffsetX: number = 0;

  private onShakeTriggerChanged(): void {
    this.playShakeAnimation();
  }

  private playShakeAnimation(): void {
    const sequence: number[] = [8, -8, 6, -6, 3, -3, 0];
    let delay: number = 0;
    for (let i = 0; i < sequence.length; i++) {
      const offset: number = sequence[i];
      setTimeout(() => {
        animateTo({ duration: 40, curve: Curve.EaseInOut }, () => {
          this.shakeOffsetX = offset;
        });
      }, delay);
      delay += 40;
    }
  }

  build() {
    Row({ space: 10 }) {
      Text(this.hasAgreed ? '☑' : '☐')
        .fontSize(18)
        .fontColor(this.hasAgreed ? '#3A86FF' : $r('sys.color.font_secondary'))
        .onClick(() => {
          this.onOpenAgreementPrompt();
        })

      Column({ space: 4 }) {
        Text($r('app.string.auth_legal_prefix'))
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
          .alignSelf(ItemAlign.Start)

        Row({ space: 2 }) {
          Text($r('app.string.auth_legal_terms'))
            .fontSize(11)
            .fontColor('#3A86FF')
          Text($r('app.string.auth_legal_and'))
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
          Text($r('app.string.auth_legal_privacy'))
            .fontSize(11)
            .fontColor('#3A86FF')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 10, bottom: 10 })
    .backgroundColor(this.showsValidationHighlight ? 'rgba(255,0,0,0.06)' : Color.Transparent)
    .borderRadius(10)
    .border({
      width: 1,
      color: this.showsValidationHighlight ? 'rgba(255,0,0,0.45)' : Color.Transparent,
      radius: 10
    })
    .translate({ x: this.shakeOffsetX })
    .onClick(() => {
      this.onOpenAgreementPrompt();
    })
    .margin({ top: 4 })
  }
}

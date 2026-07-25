/**
 * 对应 iOS LoginInitialLegalPromptContent：首次/未同意时的协议半屏。
 */
@Component
export struct LoginLegalPromptSheet {
  onDisagree: () => void = () => {
  };
  onAgree: () => void = () => {
  };
  onOpenTerms: () => void = () => {
  };
  onOpenPrivacy: () => void = () => {
  };

  build() {
    Column() {
      Scroll() {
        Column({ space: 22 }) {
          Text($r('app.string.auth_legal_prompt_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .textAlign(TextAlign.Center)

          Column({ space: 6 }) {
            Text($r('app.string.auth_legal_prompt_intro'))
              .fontSize(15)
              .lineHeight(22)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')

            Row({ space: 4 }) {
              Text($r('app.string.auth_legal_terms'))
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#007AFF')
                .onClick(() => {
                  this.onOpenTerms();
                })
              Text($r('app.string.auth_legal_and'))
                .fontSize(15)
                .fontColor($r('sys.color.font_secondary'))
              Text($r('app.string.auth_legal_privacy'))
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#007AFF')
                .onClick(() => {
                  this.onOpenPrivacy();
                })
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Text($r('app.string.auth_legal_health_disclaimer'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .lineHeight(22)
            .width('100%')

          Column({ space: 16 }) {
            this.permissionRow($r('app.string.auth_legal_perm_device'))
            this.permissionRow($r('app.string.auth_legal_perm_location'))
            this.permissionRow($r('app.string.auth_legal_perm_photos'))
            this.permissionRow($r('app.string.auth_legal_perm_microphone'))
            this.permissionRow($r('app.string.auth_legal_perm_logs'))
          }
          .width('100%')

          Text($r('app.string.auth_legal_perm_note'))
            .fontSize(15)
            .lineHeight(22)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')

          Text($r('app.string.auth_legal_security_commitment'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .lineHeight(22)
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 26, right: 26, top: 26, bottom: 18 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      Row({ space: 18 }) {
        Button($r('app.string.auth_legal_disagree'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor('#F2F2F7')
          .borderRadius(12)
          .layoutWeight(1)
          .height(50)
          .onClick(() => {
            this.onDisagree();
          })

        Button($r('app.string.auth_legal_agree_continue'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor('#007AFF')
          .borderRadius(12)
          .layoutWeight(1)
          .height(50)
          .onClick(() => {
            this.onAgree();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 12, bottom: 24 })
      .backgroundColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  permissionRow(text: Resource) {
    Row({ space: 10 }) {
      Column()
        .width(9)
        .height(9)
        .borderRadius(4.5)
        .backgroundColor($r('sys.color.font_secondary'))
        .margin({ top: 8 })
      Text(text)
        .fontSize(15)
        .lineHeight(21)
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}

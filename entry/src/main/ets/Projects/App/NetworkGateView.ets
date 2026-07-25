@Component
export struct NetworkGateView {
  build() {
    Column({ space: 12 }) {
      Text($r('app.string.startup_network_offline_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
      Text($r('app.string.startup_network_offline_desc'))
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 32, right: 32 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Color.White)
  }
}

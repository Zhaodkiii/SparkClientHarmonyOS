@Component
export struct CameraPlaceholderPage {
  build() {
    Column() {
      Text($r('app.string.tab_camera'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })
      Text($r('app.string.camera_placeholder_desc'))
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

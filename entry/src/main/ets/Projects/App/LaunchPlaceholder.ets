@Component
export struct LaunchPlaceholder {
  build() {
    Column() {
      Text($r('app.string.nav_launch_loading'))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

/**
 * 登录页 / 手机号页顶部渐变图标，对齐 iOS headerCluster。
 */
@Component
export struct AuthHeroIcon {
  @Prop kind: string = 'shield'; // shield | phone
  onTap: () => void = () => {
  };

  build() {
    Stack() {
      Column()
        .width(90)
        .height(90)
        .borderRadius(this.kind === 'phone' ? 20 : 18)
        .linearGradient({
          angle: 135,
          colors: this.kind === 'phone'
            ? [['#0A84FF', 0.0], ['#30B0C7', 1.0]]
            : [['#0A84FF', 0.0], ['#5856D6', 1.0]]
        })

      Text(this.kind === 'phone' ? '☎' : '🛡')
        .fontSize(36)
        .fontColor('rgba(255,255,255,0.95)')
    }
    .width(90)
    .height(90)
    .shadow({
      radius: this.kind === 'phone' ? 14 : 12,
      color: 'rgba(0,0,0,0.1)',
      offsetX: 0,
      offsetY: this.kind === 'phone' ? 8 : 4
    })
    .onClick(() => {
      this.onTap();
    })
  }
}

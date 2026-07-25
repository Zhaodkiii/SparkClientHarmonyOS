import { AccountProfile } from '../../Domain/AccountProfile';

@Component
export struct AccountProfileCard {
  @Prop profileLoading: boolean = false;
  @Prop profile: AccountProfile | undefined = undefined;

  build() {
    Column() {
      if (this.profileLoading && !this.profile) {
        LoadingProgress().width(40).height(40)
        Text($r('app.string.account_profile_loading'))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .margin({ top: 8 })
      } else if (this.profile) {
        Stack() {
          Circle()
            .width(64)
            .height(64)
            .fill('#0A84FF')
          Text(this.avatarLetter())
            .fontSize(28)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
        }
        .width(64)
        .height(64)
        .margin({ bottom: 12 })

        Text(this.profile.displayTitle())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.profile.signInMethodDescription())
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Center)
  }

  private avatarLetter(): string {
    const title = this.profile?.displayTitle() ?? '?';
    return title.length > 0 ? title.substring(0, 1).toUpperCase() : '?';
  }
}

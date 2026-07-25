import {
  AccountIdentityList,
  AccountIdentityProviders,
  AccountIdentityStatus
} from '../../Domain/AccountIdentityModels';

@Component
export struct AccountIdentitySection {
  @Prop identitiesLoading: boolean = false;
  /** 必须用 @Prop：无装饰器的父传参只在初始化生效，会导致列表永远不刷新、一直停在加载态 */
  @Prop identityList: AccountIdentityList | undefined = undefined;
  onBind?: (provider: string) => void;
  onChange?: (provider: string) => void;

  build() {
    Column() {
      Text($r('app.string.account_section_identity'))
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .margin({ bottom: 8 })

      Column() {
        if (this.identitiesLoading && !this.identityList) {
          Row() {
            LoadingProgress().width(24).height(24)
            Text($r('app.string.account_identity_loading'))
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ left: 8 })
          }
          .padding(16)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.identityList) {
          if (this.identityList.identities.length === 0) {
            Text('暂无可管理的登录方式')
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
              .padding(16)
              .width('100%')
              .textAlign(TextAlign.Center)
          } else {
            ForEach(this.identityList.identities, (item: AccountIdentityStatus, index: number) => {
              Column() {
                this.identityRow(item)
                if (index < this.identityList!.identities.length - 1) {
                  Divider().color('#F0F0F0').margin({ left: 16, right: 16 })
                }
              }
            }, (item: AccountIdentityStatus) => item.provider)
          }
        }
      }
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
    }
    .width('100%')
  }

  @Builder
  identityRow(item: AccountIdentityStatus) {
    Row() {
      Column() {
        Text(AccountIdentityProviders.title(item.provider))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        if (item.bound) {
          Text(item.maskedValue.length > 0 ? item.maskedValue : '已绑定')
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: 4 })
        } else {
          Text($r('app.string.account_identity_unbound'))
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (AccountIdentityProviders.isComingSoon(item.provider)) {
        Text('即将支持')
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .onClick(() => {
            if (item.bound && item.modifiable && this.onChange) {
              this.onChange(item.provider);
            } else if (!item.bound && item.bindable && this.onBind) {
              this.onBind(item.provider);
            }
          })
      } else if (item.bound && item.modifiable) {
        Text($r('app.string.account_identity_change'))
          .fontSize(14)
          .fontColor('#0A84FF')
          .onClick(() => {
            if (this.onChange) {
              this.onChange(item.provider);
            }
          })
      } else if (!item.bound && item.bindable) {
        Text($r('app.string.account_identity_bind'))
          .fontSize(14)
          .fontColor('#0A84FF')
          .onClick(() => {
            if (this.onBind) {
              this.onBind(item.provider);
            }
          })
      } else if (item.bound) {
        Text('已绑定')
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .width('100%')
    .padding(16)
  }
}

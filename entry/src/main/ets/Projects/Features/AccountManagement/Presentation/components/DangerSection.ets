import { AccountDeactivationOptions } from '../../Domain/AccountDeactivationModels';

@Component
export struct DangerSection {
  @Link showAdvanced: boolean;
  options: AccountDeactivationOptions = new AccountDeactivationOptions();
  onBeginDeactivation?: () => void;
  onOptionsChanged?: () => void;

  build() {
    Column() {
      Text($r('app.string.account_section_danger'))
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .margin({ bottom: 8 })

      Column() {
        Text('注销将停用账号并处理相关数据')
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .padding({ left: 16, right: 16, top: 14 })

        Row() {
          Text('高级选项')
            .fontSize(14)
            .layoutWeight(1)
          Text(this.showAdvanced ? '收起' : '展开')
            .fontSize(13)
            .fontColor('#0A84FF')
        }
        .width('100%')
        .padding(16)
        .onClick(() => {
          this.showAdvanced = !this.showAdvanced;
        })

        if (this.showAdvanced) {
          Column({ space: 8 }) {
            Toggle({ type: ToggleType.Switch, isOn: this.options.immediateDeactivation })
              .onChange((isOn: boolean) => {
                this.options.immediateDeactivation = isOn;
                if (this.onOptionsChanged) {
                  this.onOptionsChanged();
                }
              })
            Text(this.options.immediateDeactivation ? '立即注销' : '延迟注销')
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
            TextInput({ text: this.options.reason, placeholder: '注销原因（可选）' })
              .onChange((v: string) => {
                this.options.reason = v;
                if (this.onOptionsChanged) {
                  this.onOptionsChanged();
                }
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
          .alignItems(HorizontalAlign.Start)
        }

        Divider().color('#F0F0F0')

        Row() {
          Text($r('app.string.account_deactivation_title'))
            .fontSize(16)
            .fontColor('#FF3B30')
            .layoutWeight(1)
          Text('›')
            .fontSize(18)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .padding(16)
        .onClick(() => {
          if (this.onBeginDeactivation) {
            this.onBeginDeactivation();
          }
        })
      }
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(12)
    }
    .width('100%')
  }
}

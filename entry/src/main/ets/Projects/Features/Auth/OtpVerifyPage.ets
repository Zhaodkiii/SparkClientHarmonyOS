import { AuthNavContext } from './AuthNavContext';
import { LoginViewModel } from './LoginViewModel';
import { OtpCodeInput } from './components/OtpCodeInput';

/**
 * 对应 iOS OTPVerifyView：6 位验证码 + 倒计时重发 + 底部验证登录。
 */
@Component
export struct OtpVerifyPage {
  private vm: LoginViewModel = AuthNavContext.ensureViewModel();
  @State code: string = '';
  @State otpCountdownSec: number = 0;
  @State otpRequesting: boolean = false;
  @State busy: boolean = false;
  @State errorText: string = '';
  @State isVerifying: boolean = false;

  aboutToAppear(): void {
    this.vm = AuthNavContext.ensureViewModel();
    this.vm.setOnChanged(() => {
      this.syncFromViewModel();
    });
    this.syncFromViewModel();
  }

  build() {
    NavDestination() {
      Column() {
        Column({ space: 18 }) {
          Row() {
            Button('←')
              .width(40)
              .height(40)
              .borderRadius(20)
              .type(ButtonType.Normal)
              .onClick(() => {
                const stack = AuthNavContext.pathStack;
                if (stack) {
                  stack.pop();
                }
              })
            Text($r('app.string.auth_otp_nav_title'))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Blank().width(40)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })

          Column({ space: 6 }) {
            Text($r('app.string.auth_otp_title'))
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
            Row({ space: 4 }) {
              Text($r('app.string.auth_otp_sent_to'))
                .fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
              Text(this.vm.maskedPhone())
                .fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
            }
          }
          .margin({ top: 6 })
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          OtpCodeInput({
            code: this.code,
            onCodeChange: (v: string) => {
              this.code = v;
              if (v.replace(/[^\d]/g, '').length >= 6) {
                this.onVerify();
              }
            }
          })
            .margin({ top: 6 })
            .padding({ left: 16, right: 16 })

          if (this.otpCountdownSec > 0) {
            Row({ space: 2 }) {
              Text(`${this.otpCountdownSec}`)
                .fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
              Text($r('app.string.auth_otp_resend_countdown'))
                .fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
            }
          } else {
            Button($r('app.string.auth_otp_resend'))
              .fontSize(14)
              .type(ButtonType.Normal)
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: '#3A86FF', radius: 8 })
              .fontColor('#3A86FF')
              .enabled(!this.otpRequesting)
              .onClick(() => {
                this.vm.resendOtp().then(() => {
                  this.syncFromViewModel();
                });
              })
          }

          Row({ space: 8 }) {
            Text('🛡')
              .fontSize(14)
              .fontColor($r('sys.color.font_secondary'))
            Text($r('app.string.auth_otp_security_hint'))
              .fontSize(11)
              .fontColor($r('sys.color.font_secondary'))
              .layoutWeight(1)
          }
          .alignItems(VerticalAlign.Top)
          .padding(10)
          .backgroundColor('#FFFFFF')
          .borderRadius(10)
          .width('100%')
          .margin({ left: 16, right: 16 })

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(13)
              .fontColor(Color.Red)
              .padding({ left: 16, right: 16 })
          }

          Blank()
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Button() {
          Row({ space: 8 }) {
            if (this.isVerifying || this.busy) {
              LoadingProgress()
                .width(16)
                .height(16)
                .color(Color.White)
            }
            Text($r('app.string.auth_otp_verify_login'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
        }
        .type(ButtonType.Capsule)
        .backgroundColor('#007AFF')
        .width('100%')
        .height(48)
        .margin({ left: 16, right: 16, bottom: 24 })
        .enabled(!this.busy && !this.isVerifying && this.code.replace(/[^\d]/g, '').length >= 6)
        .onClick(() => {
          this.onVerify();
        })
      }
      .width('100%')
      .height('100%')
      .padding({ top: 8 })
      .backgroundColor('#F2F2F7')
    }
    .hideTitleBar(true)
    .backgroundColor('#F2F2F7')
  }

  private async onVerify(): Promise<void> {
    if (this.isVerifying || this.busy) {
      return;
    }
    const digits = this.code.replace(/[^\d]/g, '');
    if (digits.length < 6) {
      return;
    }
    this.isVerifying = true;
    await this.vm.verifyOtp(this.code);
    this.isVerifying = false;
    this.syncFromViewModel();
  }

  private syncFromViewModel(): void {
    this.otpCountdownSec = this.vm.state.otpCountdownSec;
    this.otpRequesting = this.vm.state.otpRequesting;
    this.busy = this.vm.state.busy;
    this.errorText = this.vm.state.errorText;
  }
}

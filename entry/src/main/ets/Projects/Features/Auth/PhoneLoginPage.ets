import { AuthNavContext } from './AuthNavContext';
import { LoginViewModel } from './LoginViewModel';
import { AuthHeroIcon } from './components/AuthHeroIcon';
import { RegionPickerSheet } from './components/RegionPickerSheet';
import { PhoneRegion } from './PhoneRegion';

/**
 * 对应 iOS PhoneLoginView：区号 + 手机号 + 发送验证码。
 */
@Component
export struct PhoneLoginPage {
  private vm: LoginViewModel = AuthNavContext.ensureViewModel();
  @State phone: string = '';
  @State showRegion: boolean = false;
  @State regionLabel: string = PhoneRegion.china().displayLabel(true);
  @State otpRequesting: boolean = false;
  @State busy: boolean = false;
  @State errorText: string = '';
  private isApplyingAutoRegion: boolean = false;

  aboutToAppear(): void {
    this.vm = AuthNavContext.ensureViewModel();
    this.vm.setOnChanged(() => {
      this.syncFromViewModel();
    });
    this.syncFromViewModel();
  }

  @Builder
  regionSheet() {
    RegionPickerSheet({
      selectedCode: this.vm.selectedRegion.code,
      onSelect: (region: PhoneRegion) => {
        this.vm.selectedRegion = region;
        this.regionLabel = region.displayLabel(true);
        this.showRegion = false;
      }
    })
  }

  build() {
    NavDestination() {
      Column({ space: 20 }) {
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
          Text($r('app.string.auth_phone_title'))
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Blank().width(40)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })

        this.headerHero()
        this.formPad()
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F2F2F7')
      .bindSheet($$this.showRegion, this.regionSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
        showClose: true
      })
    }
    .hideTitleBar(true)
    .backgroundColor('#F2F2F7')
  }

  @Builder
  headerHero() {
    Column({ space: 16 }) {
      AuthHeroIcon({ kind: 'phone' })

      Column({ space: 6 }) {
        Text($r('app.string.auth_phone_hero_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Text($r('app.string.auth_phone_hero_subtitle'))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
      }
      .margin({ top: 4 })
    }
    .width('100%')
    .padding({ top: 16, left: 16, right: 16 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  formPad() {
    Column({ space: 14 }) {
      Column({ space: 8 }) {
        Text($r('app.string.auth_phone_field_title'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .width('100%')

        Row() {
          Row({ space: 6 }) {
            Text(this.regionLabel)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            Text('▼')
              .fontSize(10)
              .fontColor($r('sys.color.font_secondary'))
          }
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          .backgroundColor('rgba(128,128,128,0.08)')
          .borderRadius(8)
          .onClick(() => {
            this.showRegion = true;
          })

          Divider()
            .vertical(true)
            .height(22)
            .margin({ left: 8, right: 8 })
            .color('rgba(128,128,128,0.25)')

          TextInput({ placeholder: '请输入手机号', text: this.phone })
            .type(InputType.PhoneNumber)
            .maxLength(this.vm.selectedRegion.maxLength)
            .layoutWeight(1)
            .backgroundColor(Color.Transparent)
            .padding({ left: 12, right: 12 })
            .height(48)
            .onChange((value: string) => {
              this.phone = value;
              this.applyAutoRegionAndStripPrefixIfNeeded(value);
            })
        }
        .width('100%')
        .padding(6)
        .backgroundColor('#FFFFFF')
        .borderRadius(10)
        .border({ width: 1, color: 'rgba(128,128,128,0.2)', radius: 10 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 16, right: 16 })

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(13)
          .fontColor(Color.Red)
          .width('100%')
          .padding({ left: 16, right: 16 })
      }

      Button() {
        Row({ space: 8 }) {
          if (this.otpRequesting) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(Color.White)
          }
          Text($r('app.string.auth_phone_send_otp'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
      }
      .type(ButtonType.Capsule)
      .backgroundColor('#007AFF')
      .width('100%')
      .height(48)
      .enabled(PhoneRegion.isPhoneReady(this.phone) && !this.otpRequesting && !this.busy)
      .opacity((PhoneRegion.isPhoneReady(this.phone) && !this.otpRequesting && !this.busy) ? 1 : 0.5)
      .margin({ left: 16, right: 16 })
      .onClick(() => {
        this.onRequestCode();
      })
    }
    .width('100%')
  }

  private applyAutoRegionAndStripPrefixIfNeeded(raw: string): void {
    if (this.isApplyingAutoRegion) {
      return;
    }
    if (this.otpRequesting || this.vm.state.otpId.length > 0) {
      return;
    }
    this.isApplyingAutoRegion = true;
    try {
      const detected = this.detectRegionNumber(raw);
      if (!detected) {
        return;
      }
      const regions = PhoneRegion.commonRegions();
      let matched: PhoneRegion | undefined = undefined;
      for (let i = 0; i < regions.length; i++) {
        if (`+${regions[i].dialCode}` === detected.dial) {
          matched = regions[i];
          break;
        }
      }
      if (!matched) {
        return;
      }
      this.vm.selectedRegion = matched;
      this.regionLabel = matched.displayLabel(true);
      this.phone = detected.nationalDigits;
    } finally {
      this.isApplyingAutoRegion = false;
    }
  }

  private detectRegionNumber(raw: string): DetectedRegionNumber | null {
    const cleaned = raw.replace(/\s/g, '');
    const regions = PhoneRegion.commonRegions();
    // 长区号优先，避免 +1 误伤
    const sorted = regions.slice().sort((a: PhoneRegion, b: PhoneRegion) => b.dialCode.length - a.dialCode.length);
    for (let i = 0; i < sorted.length; i++) {
      const dial = `+${sorted[i].dialCode}`;
      if (cleaned.startsWith(dial)) {
        return { dial: dial, nationalDigits: cleaned.substring(dial.length) };
      }
      const withoutPlus = `00${sorted[i].dialCode}`;
      if (cleaned.startsWith(withoutPlus)) {
        return { dial: dial, nationalDigits: cleaned.substring(withoutPlus.length) };
      }
      if (cleaned.startsWith(sorted[i].dialCode) && cleaned.length > sorted[i].dialCode.length + 5) {
        return { dial: dial, nationalDigits: cleaned.substring(sorted[i].dialCode.length) };
      }
    }
    return null;
  }

  private async onRequestCode(): Promise<void> {
    if (this.otpRequesting || this.busy) {
      return;
    }
    const resp = await this.vm.requestOtp(this.phone);
    const stack = AuthNavContext.pathStack;
    if (resp && stack) {
      stack.pushPathByName('auth.otp', null);
    }
    this.syncFromViewModel();
  }

  private syncFromViewModel(): void {
    this.otpRequesting = this.vm.state.otpRequesting;
    this.busy = this.vm.state.busy;
    this.errorText = this.vm.state.errorText;
    this.regionLabel = this.vm.selectedRegion.displayLabel(true);
  }
}

interface DetectedRegionNumber {
  dial: string;
  nationalDigits: string;
}

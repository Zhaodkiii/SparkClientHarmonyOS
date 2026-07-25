import { promptAction } from '@kit.ArkUI';
import { AppContainer } from '../../../../App/AppContainer';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { AccountIdentityList, AccountIdentityProvider } from '../Domain/AccountIdentityModels';
import { AccountProfile } from '../Domain/AccountProfile';
import { AccountVerificationChannel } from '../Domain/AccountDeactivationModels';
import { AccountManagementViewModel } from './AccountManagementViewModel';
import { AccountProfileCard } from './components/AccountProfileCard';
import { AccountInfoSection } from './components/AccountInfoSection';
import { AccountIdentitySection } from './components/AccountIdentitySection';
import { SessionSection } from './components/SessionSection';
import { DangerSection } from './components/DangerSection';
import { OtpCodeInput } from '../../Auth/components/OtpCodeInput';
import { PhoneRegion } from '../../Auth/PhoneRegion';
import { RegionPickerSheet } from '../../Auth/components/RegionPickerSheet';

@Component
export struct AccountManagementPage {
  onRequestClearSettingsNav?: () => void;
  private vm?: AccountManagementViewModel;
  @State private ready: boolean = false;
  @State private tick: number = 0;
  @State private showAdvanced: boolean = false;
  @State private showRegionPicker: boolean = false;
  /** 从 VM 同步到 @State，驱动子组件 @Prop 刷新（纯 class VM 字段本身不会触发 UI） */
  @State private profileLoading: boolean = false;
  @State private identitiesLoading: boolean = false;
  @State private signingOut: boolean = false;
  @State private errorBanner: string = '';
  @State private profile: AccountProfile | undefined = undefined;
  @State private identityList: AccountIdentityList | undefined = undefined;
  /** 弹层 phase 必须进 @State，否则 beginDeactivation / beginBind 后 UI 不会弹出 */
  @State private identityPhase: string = 'idle';
  @State private deactivationPhase: string = 'idle';
  @State private identityReauthOTPCode: string = '';
  @State private identityTargetOTPCode: string = '';
  @State private deactivationOTPCode: string = '';

  aboutToAppear(): void {
    const container = AppContainer.shared();
    if (!container) {
      return;
    }
    this.vm = container.createAccountManagementViewModel();
    this.vm.setOnChanged(() => {
      this.syncFromViewModel();
    });
    this.vm.setOnLocalNavClear(() => {
      if (this.onRequestClearSettingsNav) {
        this.onRequestClearSettingsNav();
      }
    });
    this.ready = true;
    this.vm.load();
  }

  private syncFromViewModel(): void {
    const vm = this.vm;
    if (!vm) {
      return;
    }
    const prevLoading = this.identitiesLoading;
    const prevHasList = this.identityList !== undefined;
    const prevCount = this.identityList !== undefined ? this.identityList.identities.length : -1;
    const prevIdentityPhase = this.identityPhase;
    const prevDeactivationPhase = this.deactivationPhase;
    this.profileLoading = vm.isLoadingProfile;
    this.identitiesLoading = vm.isLoadingIdentities;
    this.signingOut = vm.isSigningOut;
    this.errorBanner = vm.errorMessage;
    this.profile = vm.profile;
    this.identityList = vm.identityList;
    this.identityPhase = vm.identityFlow.phase;
    this.deactivationPhase = vm.deactivationFlow.phase;
    this.identityReauthOTPCode = vm.identityReauthOTPCode;
    this.identityTargetOTPCode = vm.identityTargetOTPCode;
    this.deactivationOTPCode = vm.otpCode;
    this.tick += 1;

    const nextHasList = this.identityList !== undefined;
    const nextCount = this.identityList !== undefined ? this.identityList.identities.length : -1;
    if (prevLoading !== this.identitiesLoading || prevHasList !== nextHasList || prevCount !== nextCount ||
      prevIdentityPhase !== this.identityPhase || prevDeactivationPhase !== this.deactivationPhase) {
      const fields = new LogFields();
      fields.operation = 'account.ui.sync';
      fields.detail =
        `profileLoading=${this.profileLoading} identitiesLoading=${this.identitiesLoading} hasProfile=${this.profile !== undefined} hasList=${nextHasList} listCount=${nextCount} identityPhase=${this.identityPhase} deactivationPhase=${this.deactivationPhase} tick=${this.tick}`;
      Logger.info('account.ui.sync', LogModule.AUTH, fields);
    }
  }

  private showIdentityOverlay(): boolean {
    return this.ready && this.vm !== undefined && this.identityPhase !== 'idle';
  }

  private showDeactivationOverlay(): boolean {
    return this.ready && this.vm !== undefined &&
      this.deactivationPhase !== 'idle' && this.deactivationPhase !== 'completed';
  }

  aboutToDisappear(): void {
    this.vm?.cancelIdentityFlow();
    this.vm?.cancelDeactivation();
  }

  build() {
    NavDestination() {
      Stack() {
        if (this.tick < 0) {
          Text('')
        }
        Scroll() {
          Column({ space: 16 }) {
            if (this.ready && this.vm !== undefined) {
              if (this.errorBanner.length > 0) {
                Text(this.errorBanner)
                  .fontSize(13)
                  .fontColor('#FF3B30')
                  .width('100%')
                  .padding(12)
                  .backgroundColor('#FFF5F5')
                  .borderRadius(8)
              }

              AccountProfileCard({
                profileLoading: this.profileLoading,
                profile: this.profile
              })

              AccountInfoSection({ profile: this.profile })

              AccountIdentitySection({
                identitiesLoading: this.identitiesLoading,
                identityList: this.identityList,
                onBind: (provider: string) => {
                  this.vm?.beginBind(provider as AccountIdentityProvider);
                },
                onChange: (provider: string) => {
                  this.vm?.beginChange(provider as AccountIdentityProvider);
                }
              })

              SessionSection({
                signingOut: this.signingOut,
                onSignOut: () => {
                  this.confirmSignOut();
                }
              })

              DangerSection({
                showAdvanced: $showAdvanced,
                options: this.vm.options,
                onBeginDeactivation: () => {
                  this.vm?.beginDeactivation();
                },
                onOptionsChanged: () => {
                  this.tick += 1;
                }
              })
            } else {
              LoadingProgress().width(40).height(40)
            }
          }
          .width('100%')
          .padding(16)
        }
        .width('100%')
        .height('100%')
        .align(Alignment.Top)

        if (this.showIdentityOverlay()) {
          this.identityOverlay()
        }
        if (this.showDeactivationOverlay()) {
          this.deactivationOverlay()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F2F2F7')
    }
    .title($r('app.string.account_title'))
    .backgroundColor('#F2F2F7')
    .onBackPressed(() => {
      if (this.onRequestClearSettingsNav) {
        this.onRequestClearSettingsNav();
      }
      return true;
    })
  }

  @Builder
  identityOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#99000000')
        .onClick(() => {
          if (this.identityPhase === 'choosingReauth' || this.identityPhase === 'comingSoon') {
            this.vm?.cancelIdentityFlow();
          }
        })
      Column() {
        this.identityOverlayBody()
      }
      .width('88%')
      .constraintSize({ maxHeight: '80%' })
      .backgroundColor(Color.White)
      .borderRadius(16)
      .padding(20)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  @Builder
  identityOverlayBody() {
    if (this.vm === undefined) {
      Text('')
    } else if (this.identityPhase === 'comingSoon') {
      Text('即将支持').fontSize(18).fontWeight(FontWeight.Medium)
      Text('Huawei 账号绑定即将开放')
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: 8, bottom: 16 })
      Button('知道了').onClick(() => {
        this.vm?.dismissIdentityComingSoon();
      })
    } else if (this.identityPhase === 'choosingReauth') {
      Text($r('app.string.account_verify_security_title')).fontSize(18).fontWeight(FontWeight.Medium)
      Text('修改登录方式前，请先验证身份')
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: 6, bottom: 12 })
      ForEach(this.vm.availableReauthChannels(), (ch: AccountVerificationChannel) => {
        Row() {
          Text(ch.title()).fontSize(15).layoutWeight(1)
          Text(ch.displayMasked.length > 0 ? ch.displayMasked : (ch.kind === 'huawei' ? '即将支持' : ''))
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
          Text(' ›').fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .onClick(() => {
          this.vm?.selectReauthChannel(ch);
        })
      }, (ch: AccountVerificationChannel) => ch.kind)
      Button('取消')
        .margin({ top: 8 })
        .backgroundColor(Color.Transparent)
        .fontColor($r('sys.color.font_secondary'))
        .onClick(() => {
          this.vm?.cancelIdentityFlow();
        })
    } else if (this.identityPhase === 'reauthOTP') {
      Text($r('app.string.account_verify_security_title')).fontSize(18).fontWeight(FontWeight.Medium)
      Text(this.vm.identityFlow.reauthChannel !== undefined ? this.vm.identityFlow.reauthChannel.displayMasked : '')
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: 6, bottom: 12 })
      OtpCodeInput({
        code: this.identityReauthOTPCode,
        focusKey: 'accountIdentityReauthOtpInput',
        onCodeChange: (v: string) => {
          if (this.vm !== undefined) {
            this.identityReauthOTPCode = v;
            this.vm.identityReauthOTPCode = v;
            this.tick += 1;
            if (v.length >= 6) {
              this.vm.submitReauthOTP();
            }
          }
        }
      })
      Button('取消')
        .margin({ top: 12 })
        .backgroundColor(Color.Transparent)
        .fontColor($r('sys.color.font_secondary'))
        .onClick(() => {
          this.vm?.cancelIdentityFlow();
        })
    } else if (this.identityPhase === 'enteringTarget') {
      Text(this.vm.identityFlow.operation?.purpose === 'bind_identity' ? '绑定新登录方式' : '修改登录方式')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })
      this.identityTargetInput()
      Button('获取验证码')
        .width('100%')
        .margin({ top: 16 })
        .enabled(this.vm.canRequestTargetOTP())
        .onClick(() => {
          this.vm?.requestIdentityTargetOTP();
        })
      Button('取消')
        .margin({ top: 8 })
        .backgroundColor(Color.Transparent)
        .fontColor($r('sys.color.font_secondary'))
        .onClick(() => {
          this.vm?.cancelIdentityFlow();
        })
    } else if (this.identityPhase === 'targetOTP' || this.identityPhase === 'submitting') {
      Text('输入验证码').fontSize(18).fontWeight(FontWeight.Medium)
      Text(this.vm.identityFlow.lockedPhone !== undefined ?
        this.vm.identityFlow.lockedPhone.displayValue : this.vm.identityFlow.lockedEmailDisplay)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: 6, bottom: 12 })
      OtpCodeInput({
        code: this.identityTargetOTPCode,
        focusKey: 'accountIdentityTargetOtpInput',
        onCodeChange: (v: string) => {
          if (this.vm !== undefined) {
            this.identityTargetOTPCode = v;
            this.vm.identityTargetOTPCode = v;
            this.tick += 1;
            if (v.length >= 6) {
              this.vm.submitIdentityTargetOTP();
            }
          }
        }
      })
      if (this.identityPhase === 'submitting') {
        LoadingProgress().width(28).height(28).margin({ top: 12 })
      }
      Button('取消')
        .margin({ top: 8 })
        .enabled(this.identityPhase !== 'submitting')
        .backgroundColor(Color.Transparent)
        .fontColor($r('sys.color.font_secondary'))
        .onClick(() => {
          this.vm?.cancelIdentityFlow();
        })
    } else if (this.identityPhase === 'completed') {
      Text('完成').fontSize(18).fontWeight(FontWeight.Medium)
      Button('好的').margin({ top: 16 }).onClick(() => {
        this.vm?.cancelIdentityFlow();
      })
    } else if (this.identityPhase === 'failed') {
      Text('操作失败').fontSize(18).fontWeight(FontWeight.Medium)
      Text(this.vm.identityFlow.errorMessage)
        .fontSize(14)
        .fontColor('#FF3B30')
        .margin({ top: 8, bottom: 16 })
      Button('关闭').onClick(() => {
        this.vm?.cancelIdentityFlow();
      })
    }
  }

  @Builder
  identityTargetInput() {
    if (this.vm === undefined) {
      Text('')
    } else if (this.vm.identityFlow.operation?.provider === 'phone') {
      Row({ space: 8 }) {
        Text(`+${this.vm.identityTargetRegion.dialCode}`)
          .fontSize(16)
          .padding(10)
          .backgroundColor('#F2F2F7')
          .borderRadius(8)
          .onClick(() => {
            this.showRegionPicker = true;
          })
        TextInput({
          text: this.vm.identityTargetPhoneLocal,
          placeholder: '手机号'
        })
          .type(InputType.PhoneNumber)
          .layoutWeight(1)
          .focusOnTouch(true)
          .enableKeyboardOnFocus(true)
          .onChange((v: string) => {
            if (this.vm !== undefined) {
              this.vm.identityTargetPhoneLocal = v.replace(/[^\d]/g, '');
              this.tick += 1;
            }
          })
      }
      .width('100%')
      .bindSheet($$this.showRegionPicker, this.regionSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
        showClose: true
      })
    } else {
      TextInput({
        text: this.vm.identityTargetEmail,
        placeholder: '邮箱地址'
      })
        .type(InputType.Email)
        .focusOnTouch(true)
        .enableKeyboardOnFocus(true)
        .onChange((v: string) => {
          if (this.vm !== undefined) {
            this.vm.identityTargetEmail = v.trim();
            this.tick += 1;
          }
        })
    }
  }

  @Builder
  regionSheet() {
    RegionPickerSheet({
      selectedCode: this.vm !== undefined ? this.vm.identityTargetRegion.code : 'CN',
      onSelect: (region: PhoneRegion) => {
        if (this.vm !== undefined) {
          this.vm.identityTargetRegion = region;
        }
        this.showRegionPicker = false;
        this.tick += 1;
      }
    })
  }

  @Builder
  deactivationOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#99000000')
        .onClick(() => {
          if (this.deactivationPhase === 'chooseVerification' ||
            this.deactivationPhase === 'comingSoon') {
            this.vm?.cancelDeactivation();
          }
        })
      Column() {
        this.deactivationOverlayBody()
      }
      .width('88%')
      .constraintSize({ maxHeight: '80%' })
      .backgroundColor(Color.White)
      .borderRadius(16)
      .padding(20)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  @Builder
  deactivationOverlayBody() {
    if (this.vm === undefined) {
      Text('')
    } else if (this.deactivationPhase === 'comingSoon') {
      Text('即将支持').fontSize(18).fontWeight(FontWeight.Medium)
      Button('关闭').margin({ top: 16 }).onClick(() => {
        this.vm?.cancelDeactivation();
      })
    } else if (this.deactivationPhase === 'chooseVerification') {
      Row({ space: 10 }) {
        Text('!')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#FF8A1D')
          .borderRadius(10)
        Text($r('app.string.account_verify_security_title'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FF8A1D')
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text('为了确保账户安全，注销账户前需要进行身份验证。')
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeight(22)
        .margin({ top: 16, bottom: 18 })
      if (this.vm.availableDeactivationChannels().length === 0) {
        Text('当前没有可用验证方式，请稍后重试')
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .padding(16)
          .backgroundColor('#F7F7FA')
          .borderRadius(12)
      } else {
        ForEach(this.vm.availableDeactivationChannels(), (ch: AccountVerificationChannel) => {
          Row({ space: 12 }) {
            Column() {
              Text(ch.kind === 'phone' ? '手' : (ch.kind === 'email' ? '邮' : '华'))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor(ch.kind === 'phone' ? '#22A447' : (ch.kind === 'email' ? '#FF3B30' : '#111111'))
            .borderRadius(10)
            Column() {
              Text(ch.title())
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor('#111111')
              Text(ch.displayMasked.length > 0 ? ch.displayMasked : (ch.kind === 'huawei' ? 'Huawei ID' : ''))
                .fontSize(13)
                .fontColor($r('sys.color.font_secondary'))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(28)
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .padding(16)
          .margin({ bottom: 10 })
          .backgroundColor('#F9F9FB')
          .borderRadius(12)
          .onClick(() => {
            this.vm?.selectDeactivationChannel(ch);
          })
        }, (ch: AccountVerificationChannel) => ch.kind)
      }
      Button('取消')
        .margin({ top: 8 })
        .backgroundColor(Color.Transparent)
        .fontColor('#0A84FF')
        .onClick(() => {
          this.vm?.cancelDeactivation();
        })
    } else if (this.deactivationPhase === 'enteringOTP') {
      Text('输入验证码').fontSize(18).fontWeight(FontWeight.Medium)
      Text(this.vm.deactivationFlow.channel !== undefined ? this.vm.deactivationFlow.channel.displayMasked : '')
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: 6, bottom: 12 })
      OtpCodeInput({
        code: this.deactivationOTPCode,
        focusKey: 'accountDeactivationOtpInput',
        onCodeChange: (v: string) => {
          if (this.vm !== undefined) {
            this.deactivationOTPCode = v;
            this.vm.otpCode = v;
            this.tick += 1;
            if (v.length >= 6) {
              this.vm.proceedDeactivationOTP();
            }
          }
        }
      })
      Button('取消')
        .margin({ top: 12 })
        .backgroundColor(Color.Transparent)
        .fontColor($r('sys.color.font_secondary'))
        .onClick(() => {
          this.vm?.cancelDeactivation();
        })
    } else if (this.deactivationPhase === 'finalConfirmation') {
      Text($r('app.string.account_deactivation_title')).fontSize(18).fontWeight(FontWeight.Medium)
      Text(`请输入「${this.vm.requiredConfirmationPhrase()}」以确认`)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: 8, bottom: 12 })
      TextInput({
        text: this.vm.confirmationPhraseInput,
        placeholder: $r('app.string.account_deactivation_confirm_phrase')
      })
        .focusOnTouch(true)
        .enableKeyboardOnFocus(true)
        .onChange((v: string) => {
          if (this.vm !== undefined) {
            this.vm.confirmationPhraseInput = v;
            this.tick += 1;
          }
        })
      Button($r('app.string.account_deactivation_submit'))
        .width('100%')
        .margin({ top: 16 })
        .backgroundColor('#FF3B30')
        .enabled(this.vm.confirmationMatches())
        .onClick(() => {
          this.vm?.confirmDeactivation();
        })
      Button('取消')
        .margin({ top: 8 })
        .backgroundColor(Color.Transparent)
        .fontColor($r('sys.color.font_secondary'))
        .onClick(() => {
          this.vm?.cancelDeactivation();
        })
    } else if (this.deactivationPhase === 'submitting') {
      LoadingProgress().width(36).height(36)
      Text('正在注销…').margin({ top: 12 })
    } else if (this.deactivationPhase === 'failed') {
      Text('注销失败').fontSize(18).fontWeight(FontWeight.Medium)
      Text(this.vm.deactivationFlow.errorMessage)
        .fontSize(14)
        .fontColor('#FF3B30')
        .margin({ top: 8, bottom: 16 })
      Button('关闭').onClick(() => {
        this.vm?.cancelDeactivation();
      })
    }
  }

  private confirmSignOut(): void {
    promptAction
      .showDialog({
        title: $r('app.string.account_sign_out_confirm_title'),
        message: $r('app.string.account_sign_out'),
        buttons: [
          { text: '取消', color: '#007AFF' },
          { text: $r('app.string.account_sign_out'), color: '#FF3B30' }
        ]
      })
      .then((result) => {
        if (result.index === 1) {
          this.vm?.confirmSignOut();
        }
      })
      .catch(() => {
        // ignore
      });
  }
}

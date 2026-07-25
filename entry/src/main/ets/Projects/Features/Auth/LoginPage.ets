import { AuthNavContext } from './AuthNavContext';
import { AuthHeroIcon } from './components/AuthHeroIcon';
import { LegalAgreementNote } from './components/LegalAgreementNote';
import { LoginLegalPromptSheet } from './components/LoginLegalPromptSheet';
import { LegalWebPage } from './components/LegalWebPage';
import { PhoneLoginPage } from './PhoneLoginPage';
import { OtpVerifyPage } from './OtpVerifyPage';
import { PendingLoginAction } from './AuthUiState';
import { LoginViewModel } from './LoginViewModel';

/**
 * 对应 iOS LoginView：登录首页 + 协议门禁 + 局部导航。
 */
@Component
export struct LoginPage {
  private loginStack: NavPathStack = new NavPathStack();
  private vm: LoginViewModel = AuthNavContext.ensureViewModel();
  @State tick: number = 0;
  @State showLegalPrompt: boolean = false;
  @State legalDocType: string = 'terms';
  @State legalTitle: string = '';
  @State showPhoneLogin: boolean = true;
  @State tapCount: number = 0;
  @State hasAgreedToLegal: boolean = false;
  @State legalAgreementShakeTrigger: number = 0;
  @State showsLegalValidationHighlight: boolean = false;
  @Prop isUpgradeSheet: boolean = false;
  private lastTapTime: number = 0;

  aboutToAppear(): void {
    AuthNavContext.pathStack = this.loginStack;
    AuthNavContext.viewModel = this.vm;
    this.vm.setOnChanged(() => {
      this.showLegalPrompt = this.vm.state.showLegalPrompt;
      this.hasAgreedToLegal = this.vm.state.legalAccepted;
      if (this.hasAgreedToLegal) {
        this.showsLegalValidationHighlight = false;
      }
      this.tick += 1;
    });
    this.vm.loadLegalAccepted().then(() => {
      this.hasAgreedToLegal = this.vm.state.legalAccepted;
      this.tick += 1;
      if (!this.hasAgreedToLegal) {
        this.presentInitialLegalPrompt(false);
      }
    });
  }

  aboutToDisappear(): void {
    if (!this.isUpgradeSheet) {
      AuthNavContext.reset();
    }
  }

  @Builder
  loginDestination(name: string) {
    if (name === 'auth.phone') {
      PhoneLoginPage()
    } else if (name === 'auth.otp') {
      OtpVerifyPage()
    } else if (name === 'auth.legal') {
      LegalWebPage({
        docType: this.legalDocType,
        titleText: this.legalTitle,
        onClose: () => {
          this.loginStack.pop();
        }
      })
    }
  }

  @Builder
  legalPromptBuilder() {
    LoginLegalPromptSheet({
      onDisagree: () => {
        this.vm.dismissLegalPrompt();
        this.hasAgreedToLegal = false;
        this.showLegalPrompt = false;
      },
      onAgree: () => {
        this.onLegalAgree();
      },
      onOpenTerms: () => {
        this.openLegal('terms');
      },
      onOpenPrivacy: () => {
        this.openLegal('privacy');
      }
    })
  }

  @Builder
  loadingOverlay() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color('#3A86FF')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(0,0,0,0.05)')
  }

  build() {
    Navigation(this.loginStack) {
      Stack() {
        Scroll() {
          Column({ space: 24 }) {
            this.headerCluster()
            this.actionButtons()
            LegalAgreementNote({
              hasAgreed: this.hasAgreedToLegal,
              shakeTrigger: this.legalAgreementShakeTrigger,
              showsValidationHighlight: this.showsLegalValidationHighlight,
              onOpenAgreementPrompt: () => {
                this.presentInitialLegalPrompt(true);
              }
            })

            if (this.vm.state.errorText.length > 0) {
              Text(this.vm.state.errorText)
                .fontSize(13)
                .fontColor(Color.Red)
                .width('100%')
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .padding(24)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .backgroundColor('#F2F2F7')
        .enabled(!this.vm.state.busy)

        if (this.vm.state.busy) {
          this.loadingOverlay()
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(!this.isUpgradeSheet)
    .title(this.isUpgradeSheet ? $r('app.string.auth_upgrade_title') : $r('app.string.auth_login_nav_title'))
    .mode(NavigationMode.Stack)
    .navDestination(this.loginDestination)
    .bindSheet($$this.showLegalPrompt, this.legalPromptBuilder(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: false,
      enableOutsideInteractive: false
    })
  }

  @Builder
  headerCluster() {
    Column({ space: 16 }) {
      AuthHeroIcon({
        kind: 'shield',
        onTap: () => {
          this.handleIconTap();
        }
      })
        .margin({ top: 28 })

      Column({ space: 6 }) {
        Text($r('app.string.auth_login_title'))
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
        Text($r('app.string.auth_login_welcome'))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
      }
      .margin({ bottom: 6 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  actionButtons() {
    Column({ space: 14 }) {
      Stack() {
        Button($r('app.string.auth_huawei_login'))
          .width('100%')
          .height(48)
          .borderRadius(24)
          .fontColor(Color.White)
          .backgroundColor('#1A1A1A')
          .opacity(this.hasAgreedToLegal ? 1 : 0.55)
          .enabled(this.hasAgreedToLegal && !this.vm.state.busy)
          .onClick(() => {
            this.onEntry('huawei');
          })

        if (!this.hasAgreedToLegal) {
          Column()
            .width('100%')
            .height(48)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.requireLegalAgreementBeforeLogin();
            })
        }
      }
      .width('100%')

      if (this.showPhoneLogin) {
        Row() {
          Divider()
            .layoutWeight(1)
            .color('rgba(128,128,128,0.2)')
          Text($r('app.string.auth_or_divider'))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ left: 8, right: 8 })
          Divider()
            .layoutWeight(1)
            .color('rgba(128,128,128,0.2)')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 6, bottom: 6 })

        Button() {
          Row({ space: 10 }) {
            Text('☎')
              .fontSize(16)
              .fontColor('#3A86FF')
            Text($r('app.string.auth_phone_login'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#3A86FF')
          }
        }
        .type(ButtonType.Normal)
        .borderRadius(10)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: 'rgba(58,134,255,0.35)', radius: 10 })
        .width('100%')
        .height(48)
        .enabled(!this.vm.state.busy)
        .onClick(() => {
          if (this.hasAgreedToLegal) {
            this.onEntry('phone');
          } else {
            this.requireLegalAgreementBeforeLogin();
          }
        })
      }

      if (!this.isUpgradeSheet) {
        Text($r('app.string.auth_guest_mode'))
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
          .margin({ top: 4 })
          .enabled(!this.vm.state.busy)
          .onClick(() => {
            if (this.hasAgreedToLegal) {
              this.onEntry('device');
            } else {
              this.requireLegalAgreementBeforeLogin();
            }
          })
      }
    }
    .width('100%')
  }

  private handleIconTap(): void {
    const now: number = Date.now();
    if (this.lastTapTime > 0 && now - this.lastTapTime > 1000) {
      this.tapCount = 0;
    }
    this.tapCount += 1;
    this.lastTapTime = now;
    if (this.tapCount >= 3) {
      this.showPhoneLogin = true;
      this.tapCount = 0;
    }
  }

  private requireLegalAgreementBeforeLogin(): void {
    this.presentInitialLegalPrompt(true);
  }

  private presentInitialLegalPrompt(showsWarning: boolean): void {
    if (showsWarning) {
      this.showsLegalValidationHighlight = true;
      this.legalAgreementShakeTrigger += 1;
    }
    this.vm.state.showLegalPrompt = true;
    this.showLegalPrompt = true;
    this.tick += 1;
  }

  private onEntry(action: PendingLoginAction): void {
    const allowed = this.vm.requestAction(action);
    this.showLegalPrompt = this.vm.state.showLegalPrompt;
    this.hasAgreedToLegal = this.vm.state.legalAccepted;
    if (!allowed) {
      this.presentInitialLegalPrompt(true);
      return;
    }
    this.runAction(action);
  }

  private async onLegalAgree(): Promise<void> {
    const action = await this.vm.acceptLegalAndContinue();
    this.hasAgreedToLegal = true;
    this.showsLegalValidationHighlight = false;
    this.showLegalPrompt = false;
    this.runAction(action);
  }

  private runAction(action: PendingLoginAction): void {
    if (action === 'huawei') {
      this.vm.showComingSoon();
      this.vm.state.pendingAction = 'none';
      this.tick += 1;
      return;
    }
    if (action === 'phone') {
      this.loginStack.pushPathByName('auth.phone', null);
      return;
    }
    if (action === 'device') {
      this.vm.signInWithDevice().then(() => {
        this.tick += 1;
      });
    }
  }

  private openLegal(docType: string): void {
    this.legalDocType = docType;
    this.legalTitle = docType === 'privacy' ? '隐私协议' : '服务条款';
    this.loginStack.pushPathByName('auth.legal', null);
  }
}

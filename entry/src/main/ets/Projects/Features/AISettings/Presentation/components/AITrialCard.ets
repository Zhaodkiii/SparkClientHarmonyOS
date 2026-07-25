import { promptAction } from '@kit.ArkUI';
import { AITrialStatus } from '../../../../../Core/AI/Domain/AIConfigModels';
import { L10n } from '../../../../../Foundation/L10n/L10n';
import { AISettingsUiTokens } from '../AISettingsUiTokens';

/** 对标 iOS AITrialSettingsView 试用入口卡片（不含试用厂商 Section）。 */
@Component
export struct AITrialCard {
  status?: AITrialStatus;
  message: string = '';
  submitting: boolean = false;
  /** 提交试用申请；成功返回 true（对标 iOS submitTrialApplication） */
  onApply: () => Promise<boolean> = async (): Promise<boolean> => {
    return false;
  };

  @State private trialPrivacyAccepted: boolean = false;
  private readonly badgeTitles: string[] = ['OpenAI', 'Gemini', 'Claude', 'DeepSeek', 'GLM'];

  private trialStatusCode(): string {
    if (this.status?.isActive === true) {
      return 'active';
    }
    return this.status?.status ?? 'none';
  }

  private isTrialActive(): boolean {
    return this.trialStatusCode() === 'active' || this.status?.isActive === true;
  }

  private daysRemaining(): number {
    const seconds = this.status?.remainingSeconds ?? 0;
    if (seconds <= 0) {
      return 0;
    }
    return Math.max(Math.ceil(seconds / 86400.0), 0);
  }

  private remainingDaysText(): string {
    const template = L10n.getString(
      $r('app.string.ai_settings_providers_trial_status_remaining_days'),
      '剩余 {days} 天'
    );
    const params: Record<string, string> = {};
    params['days'] = `${this.daysRemaining()}`;
    return L10n.format(template, params);
  }

  private trialButtonTitle(): Resource {
    switch (this.trialStatusCode()) {
      case 'active':
        return $r('app.string.ai_settings_providers_trial_action_active');
      case 'pending':
        return $r('app.string.ai_settings_providers_trial_action_pending');
      case 'rejected':
      case 'expired':
        return $r('app.string.ai_settings_providers_trial_action_reapply');
      default:
        return $r('app.string.ai_settings_providers_trial_action_apply');
    }
  }

  private showError(message: string): void {
    promptAction.showDialog({
      title: L10n.getString(
        $r('app.string.ai_settings_providers_editor_alert_notice_title'),
        '提示'
      ),
      message: message,
      buttons: [
        {
          text: L10n.getString($r('app.string.common_action_confirm'), '确定'),
          color: AISettingsUiTokens.accent
        }
      ]
    }).catch(() => {
    });
  }

  private async onApplyClick(): Promise<void> {
    if (this.submitting) {
      return;
    }
    if (!this.trialPrivacyAccepted) {
      this.showError(
        L10n.getString(
          $r('app.string.ai_settings_providers_trial_error_need_consent'),
          '请先勾选隐私同意后再提交申请'
        )
      );
      return;
    }
    const ok = await this.onApply();
    if (ok) {
      return;
    }
    if (this.message.length > 0) {
      this.showError(this.message);
      return;
    }
    this.showError(L10n.getString($r('app.string.api_error_unknown'), '操作失败，请稍后重试。'));
  }

  @Builder
  statusLabel() {
    Row({ space: 8 }) {
      if (this.trialStatusCode() === 'active') {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(16)
          .fontColor([AISettingsUiTokens.success])
        Text($r('app.string.ai_settings_providers_trial_status_active'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AISettingsUiTokens.textPrimary)
        if ((this.status?.remainingSeconds ?? 0) > 0) {
          Text(this.remainingDaysText())
            .fontSize(12)
            .fontColor(AISettingsUiTokens.textSecondary)
        }
      } else if (this.trialStatusCode() === 'pending') {
        SymbolGlyph($r('sys.symbol.clock_fill'))
          .fontSize(16)
          .fontColor([AISettingsUiTokens.warning])
        Text($r('app.string.ai_settings_providers_trial_status_pending'))
          .fontSize(14)
          .fontColor(AISettingsUiTokens.warning)
      } else if (this.trialStatusCode() === 'rejected') {
        SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
          .fontSize(16)
          .fontColor([AISettingsUiTokens.error])
        Text($r('app.string.ai_settings_providers_trial_status_rejected'))
          .fontSize(14)
          .fontColor(AISettingsUiTokens.error)
      } else if (this.trialStatusCode() === 'expired') {
        SymbolGlyph($r('sys.symbol.clock'))
          .fontSize(16)
          .fontColor([AISettingsUiTokens.textSecondary])
        Text($r('app.string.ai_settings_providers_trial_status_expired'))
          .fontSize(14)
          .fontColor(AISettingsUiTokens.textSecondary)
      } else {
        SymbolGlyph($r('sys.symbol.star_fill'))
          .fontSize(16)
          .fontColor([AISettingsUiTokens.textSecondary])
        Text($r('app.string.ai_settings_providers_trial_status_default'))
          .fontSize(14)
          .fontColor(AISettingsUiTokens.textSecondary)
      }
    }
  }

  @Builder
  trialConsentArea() {
    Column({ space: 6 }) {
      Text($r('app.string.ai_settings_providers_trial_consent_hint'))
        .fontSize(12)
        .fontColor(AISettingsUiTokens.textSecondary)
        .width('100%')

      Row() {
        Text($r('app.string.ai_settings_providers_trial_consent_toggle'))
          .fontSize(12)
          .fontColor(AISettingsUiTokens.textPrimary)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.trialPrivacyAccepted })
          .selectedColor(AISettingsUiTokens.accent)
          .onChange((isOn: boolean) => {
            this.trialPrivacyAccepted = isOn;
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  trialActionButton() {
    Button() {
      Row({ space: 8 }) {
        if (this.submitting) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(Color.White)
        }
        Text(this.trialButtonTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
      }
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(44)
    .type(ButtonType.Capsule)
    .backgroundColor(this.submitting ? AISettingsUiTokens.divider : AISettingsUiTokens.accent)
    .enabled(!this.submitting)
    .onClick(() => {
      this.onApplyClick();
    })
  }

  @Builder
  modelBadges() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.badgeTitles, (title: string) => {
          Text(title)
            .fontSize(12)
            .fontColor(AISettingsUiTokens.textSecondary)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#F2F2F7')
            .borderRadius(16)
        }, (title: string) => title)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.key'))
          .fontSize(22)
          .fontColor([AISettingsUiTokens.accent])
        Column({ space: 4 }) {
          Text($r('app.string.ai_settings_providers_trial_card_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AISettingsUiTokens.textPrimary)
          Text($r('app.string.ai_settings_providers_trial_card_subtitle'))
            .fontSize(14)
            .fontColor(AISettingsUiTokens.textSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 8 }) {
        this.statusLabel()
        if (!this.isTrialActive()) {
          this.trialConsentArea()
          this.trialActionButton()
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.modelBadges()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .backgroundColor(AISettingsUiTokens.cardBackground)
    .borderRadius(20)
    .border({
      width: 1,
      color: 'rgba(0,0,0,0.06)',
      radius: 20
    })
    .shadow({
      radius: 12,
      color: 'rgba(0,0,0,0.08)',
      offsetY: 4
    })
    .margin({ bottom: 8 })
  }
}

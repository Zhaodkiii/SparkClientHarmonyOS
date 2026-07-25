import { AIModelPresentation } from '../../Application/ProviderModelCatalogService';
import { priceTierColor, priceTierLabel } from '../../Application/AddOnlineModelModels';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { AISettingsIcon } from '../components/AISettingsIcon';
import { AISettingsBrandIcon } from '../components/AISettingsBrandIcon';
import { L10n } from '../../../../../Foundation/L10n/L10n';

/**
 * 对标 iOS ModelsSettingsMainRow：图标、标题、能力/价格胶囊、info、显隐 Toggle。
 */
@Component
export struct ModelsMainRowComponent {
  model: AIModelPresentation = new AIModelPresentation();
  showDivider: boolean = true;
  isEditing: boolean = false;
  isReadonly: boolean = false;
  onInfo: () => void = () => {
  };
  onToggleEnabled: (enabled: boolean) => void = (_e: boolean) => {
  };

  private isAgent(): boolean {
    return this.model.identity === 'agent';
  }

  @Builder
  private capabilityTags() {
    Row({ space: 8 }) {
      if (this.model.isLocal) {
        Text(L10n.getString($r('app.string.ai_settings_models_badge_local'), '本地'))
          .fontSize(12)
          .fontColor(AISettingsUiTokens.textSecondary)
      }
      if (this.isAgent() && this.model.baseModelName.length > 0) {
        Text(`基于 ${this.model.baseModelName}`)
          .fontSize(12)
          .fontColor(AISettingsUiTokens.textSecondary)
          .maxLines(1)
      }
      if (this.model.capabilities.supportsToolUse) {
        Text(L10n.getString($r('app.string.common_tools'), '工具'))
          .fontSize(12)
          .fontColor(AISettingsUiTokens.textSecondary)
      }
      if (this.model.capabilities.supportsMultimodal) {
        Text(L10n.getString($r('app.string.ai_settings_models_capability_visual_short'), '视觉'))
          .fontSize(12)
          .fontColor(AISettingsUiTokens.textSecondary)
      } else if (this.model.capabilities.supportsText) {
        Text(L10n.getString($r('app.string.ai_settings_models_capability_text_short'), '文本'))
          .fontSize(12)
          .fontColor(AISettingsUiTokens.textSecondary)
      }
      if (this.model.capabilities.supportsImageGen) {
        Text(L10n.getString($r('app.string.ai_settings_models_capability_image_gen_short'), '生图'))
          .fontSize(12)
          .fontColor(AISettingsUiTokens.textSecondary)
      }
      if (this.model.capabilities.supportsVoiceGen) {
        Text(L10n.getString($r('app.string.ai_settings_models_capability_voice_short'), '语音'))
          .fontSize(12)
          .fontColor(AISettingsUiTokens.textSecondary)
      }
      if (this.model.capabilities.supportsReasoning) {
        Text(L10n.getString($r('app.string.ai_settings_models_capability_reasoning_short'), '思考'))
          .fontSize(12)
          .fontColor(AISettingsUiTokens.textSecondary)
      }
      Text(priceTierLabel(this.model.priceTier))
        .fontSize(12)
        .fontColor(priceTierColor(this.model.priceTier))
    }
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Column() {
          if (this.isAgent()) {
            AISettingsIcon({ kind: 'agent', iconSize: 22 })
          } else {
            AISettingsBrandIcon({
              company: this.model.company.length > 0 ? this.model.company : 'LOCAL',
              iconSize: 24
            })
          }
        }
        .width(30)
        .height(30)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Column({ space: 4 }) {
          Text(this.model.displayName.length > 0 ? this.model.displayName : this.model.name)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AISettingsUiTokens.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          this.capabilityTags()
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (!this.isEditing) {
          Button() {
            SymbolGlyph($r('sys.symbol.star'))
              .fontSize(18)
              .fontColor([AISettingsUiTokens.textSecondary])
          }
          .width(32)
          .height(32)
          .backgroundColor(Color.Transparent)
          .enabled(!this.isReadonly)
          .onClick(() => {
            if (!this.isReadonly) {
              this.onInfo();
            }
          })

          Toggle({ type: ToggleType.Switch, isOn: this.model.isEnabled })
            .selectedColor(AISettingsUiTokens.accent)
            .enabled(!this.isReadonly)
            .onChange((on: boolean) => {
              if (this.isReadonly || on === this.model.isEnabled) {
                return;
              }
              this.onToggleEnabled(on);
            })
        }
      }
      .width('100%')
      .constraintSize({ minHeight: 56 })
      .padding({
        left: 12,
        right: 16,
        top: 12,
        bottom: 12
      })
      .alignItems(VerticalAlign.Center)

      if (this.showDivider) {
        Divider()
          .color(AISettingsUiTokens.divider)
          .strokeWidth(0.5)
          .margin({ left: 52, right: 16 })
      }
    }
    .width('100%')
  }
}

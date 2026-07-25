import { ProProviderCredentialPresentation } from '../../Application/ProviderModelCatalogService';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { AISettingsBrandIcon } from './AISettingsBrandIcon';

/**
 * 模型厂商列表单行：对标 iOS APIKeysSettingsView.providerRow。
 * 左侧整块点击进编辑页；custom 显示铅笔；右侧独立 Switch 启停。
 */
@Component
export struct ProviderRowComponent {
  provider: ProProviderCredentialPresentation = new ProProviderCredentialPresentation();
  showDivider: boolean = true;
  onRowClick: () => void = () => {
  };
  onToggleEnabled: (providerId: string, enabled: boolean) => void = () => {
  };

  private isCustom(): boolean {
    return this.provider.source === 'custom';
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        // 对标 MainNavigationLink：图标 + 名称 +（custom）铅笔
        Row({ space: 12 }) {
          AISettingsBrandIcon({ company: this.provider.company, iconSize: 24 })
            .width(24)
            .height(24)

          Text(this.provider.localizedName)
            .fontSize(AISettingsUiTokens.titleRow)
            .fontWeight(FontWeight.Regular)
            .fontColor(AISettingsUiTokens.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (this.isCustom()) {
            // 对标 iOS pencil（工程暂无公司/编辑位图资源，用字符保证可编译）
            Text('✎')
              .fontSize(14)
              .fontColor(AISettingsUiTokens.textSecondary)
          }
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.onRowClick();
        })

        // 独立开关，对标 Toggle；不与行点击共用手势
        Toggle({ type: ToggleType.Switch, isOn: this.provider.enabled })
          .selectedColor(AISettingsUiTokens.accent)
          .onChange((isOn: boolean) => {
            if (isOn === this.provider.enabled) {
              return;
            }
            this.onToggleEnabled(this.provider.providerId, isOn);
          })
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
          .margin({ left: 48, right: 16 })
      }
    }
    .width('100%')
  }
}

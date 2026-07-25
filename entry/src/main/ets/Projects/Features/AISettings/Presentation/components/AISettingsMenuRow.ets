import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { AISettingsIcon, AISettingsIconKind } from './AISettingsIcon';

@Component
export struct AISettingsMenuRow {
  title: string | Resource = '';
  subtitle: string | Resource = '';
  iconKind: AISettingsIconKind = 'key';
  showDivider: boolean = true;
  trailing: string = '';
  onRowClick: () => void = () => {
  };

  build() {
    Column() {
      Row() {
        Column() {
          AISettingsIcon({ kind: this.iconKind })
        }
        .width(AISettingsUiTokens.iconSlot)
        .height(AISettingsUiTokens.iconSlot)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text(this.title)
            .fontSize(AISettingsUiTokens.titleRow)
            .fontWeight(FontWeight.Medium)
            .fontColor(AISettingsUiTokens.textPrimary)
            .maxLines(1)
          Text(this.subtitle)
            .fontSize(AISettingsUiTokens.subtitleRow)
            .fontColor(AISettingsUiTokens.textSecondary)
            .margin({ top: 4 })
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 8 })

        if (this.trailing.length > 0) {
          Text(this.trailing)
            .fontSize(13)
            .fontColor(AISettingsUiTokens.textSecondary)
            .margin({ right: 6 })
        }

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(AISettingsUiTokens.chevronSize)
          .fontColor([AISettingsUiTokens.textSecondary])
      }
      .width('100%')
      .constraintSize({ minHeight: AISettingsUiTokens.rowMinHeight })
      .padding({
        left: 12,
        right: 16,
        top: 14,
        bottom: 14
      })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onRowClick();
      })

      if (this.showDivider) {
        Divider()
          .color(AISettingsUiTokens.divider)
          .strokeWidth(0.5)
          .margin({ left: AISettingsUiTokens.iconSlot + 20, right: 16 })
      }
    }
    .width('100%')
  }
}

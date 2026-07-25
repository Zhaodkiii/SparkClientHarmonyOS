import { AISettingsUiTokens } from '../AISettingsUiTokens';

@Component
export struct AISettingsNavHeader {
  title: string | Resource = '';
  /** 根页大标题模式：左侧仅返回，标题在下方单独渲染 */
  largeTitleMode: boolean = false;
  showBack: boolean = true;
  actionTitle: string = '';
  /** 右上角图标（优先于 actionTitle），对标 iOS plus.circle.fill */
  actionSymbol: Resource | null = null;
  actionEnabled: boolean = true;
  onBack: () => void = () => {
  };
  onAction: () => void = () => {
  };

  build() {
    Row() {
      if (this.showBack) {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_backward'))
            .fontSize(22)
            .fontColor([AISettingsUiTokens.textPrimary])
        }
        .width(AISettingsUiTokens.backBtnSize)
        .height(AISettingsUiTokens.backBtnSize)
        .borderRadius(AISettingsUiTokens.backBtnSize / 2)
        .backgroundColor('#E5E5EA')
        .accessibilityText('返回')
        .onClick(() => {
          this.onBack();
        })
      } else {
        Blank()
          .width(AISettingsUiTokens.backBtnSize)
      }

      if (!this.largeTitleMode) {
        Text(this.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AISettingsUiTokens.textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Blank()
          .layoutWeight(1)
      }

      if (this.actionSymbol !== null) {
        Button() {
          SymbolGlyph(this.actionSymbol)
            .fontSize(24)
            .fontColor([AISettingsUiTokens.accent])
        }
        .width(AISettingsUiTokens.backBtnSize)
        .height(AISettingsUiTokens.backBtnSize)
        .backgroundColor(Color.Transparent)
        .enabled(this.actionEnabled)
        .accessibilityText(this.actionTitle.length > 0 ? this.actionTitle : '添加')
        .onClick(() => {
          this.onAction();
        })
      } else if (this.actionTitle.length > 0) {
        Button(this.actionTitle)
          .fontSize(16)
          .fontColor(AISettingsUiTokens.accent)
          .backgroundColor(Color.Transparent)
          .enabled(this.actionEnabled)
          .onClick(() => {
            this.onAction();
          })
      } else {
        Blank()
          .width(AISettingsUiTokens.backBtnSize)
      }
    }
    .width('100%')
    .height(AISettingsUiTokens.headerHeight)
    .padding({
      left: AISettingsUiTokens.pagePaddingH,
      right: AISettingsUiTokens.pagePaddingH
    })
    .alignItems(VerticalAlign.Center)
  }
}

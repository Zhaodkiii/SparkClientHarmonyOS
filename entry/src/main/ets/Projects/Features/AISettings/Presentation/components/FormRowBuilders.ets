import { AISettingsUiTokens } from '../AISettingsUiTokens';

/**
 * 对标 iOS AddOnlineModelSheet.formInputRow：图标 + 输入框。
 * 使用 @Prop + 回调，避免 @Builder 内 $$this / @Link 崩溃。
 */
@Component
export struct FormInputRow {
  iconSymbol: Resource = $r('sys.symbol.doc_text');
  title: string = '';
  prompt: string = '';
  @Prop text: string = '';
  onTextChange: (v: string) => void = (_v: string) => {
  };

  build() {
    Row({ space: 12 }) {
      SymbolGlyph(this.iconSymbol)
        .fontSize(18)
        .fontColor([AISettingsUiTokens.accent])
      TextInput({
        text: this.text,
        placeholder: this.prompt.length > 0 ? this.prompt : this.title
      })
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .padding(0)
        .onChange((value: string) => {
          this.onTextChange(value);
        })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 16, right: 16 })
  }
}

/**
 * 对标 iOS formToggleRow：图标 + 标题 + Switch。
 */
@Component
export struct FormToggleRow {
  iconSymbol: Resource = $r('sys.symbol.star');
  title: string = '';
  @Prop isOn: boolean = false;
  onToggleChange: (v: boolean) => void = (_v: boolean) => {
  };

  build() {
    Row({ space: 12 }) {
      SymbolGlyph(this.iconSymbol)
        .fontSize(18)
        .fontColor([AISettingsUiTokens.accent])
      Text(this.title)
        .fontSize(16)
        .fontColor(AISettingsUiTokens.textPrimary)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor(AISettingsUiTokens.accent)
        .onChange((on: boolean) => {
          this.onToggleChange(on);
        })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10, left: 16, right: 16 })
  }
}

/**
 * 对标 iOS formMenuRow：图标 + 标题 + 右侧自定义内容（Picker/Select）。
 */
@Component
export struct FormMenuRow {
  iconSymbol: Resource = $r('sys.symbol.key');
  title: string = '';
  @BuilderParam trailing: () => void;

  build() {
    Row({ space: 12 }) {
      SymbolGlyph(this.iconSymbol)
        .fontSize(18)
        .fontColor([AISettingsUiTokens.accent])
      Text(this.title)
        .fontSize(16)
        .fontColor(AISettingsUiTokens.textPrimary)
      Blank()
      this.trailing()
    }
    .width('100%')
    .padding({ top: 10, bottom: 10, left: 16, right: 16 })
  }
}

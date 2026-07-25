import { AISettingsUiTokens } from '../AISettingsUiTokens';

export type AISettingsIconKind = 'key' | 'models' | 'preferences' | 'tasks' | 'provider' | 'agent' | 'local';

@Component
export struct AISettingsIcon {
  kind: AISettingsIconKind = 'key';
  iconSize: number = AISettingsUiTokens.iconSize;

  private symbol(): Resource {
    // 使用常见系统符号；语义对齐 iOS SF Symbols，不保证逐像素一致
    if (this.kind === 'key') {
      return $r('sys.symbol.key');
    }
    if (this.kind === 'models') {
      return $r('sys.symbol.square_stack_3d');
    }
    if (this.kind === 'preferences') {
      return $r('sys.symbol.square_stack_3d');
    }
    if (this.kind === 'tasks') {
      return $r('sys.symbol.doc_text');
    }
    if (this.kind === 'provider') {
      return $r('sys.symbol.key');
    }
    if (this.kind === 'agent') {
      return $r('sys.symbol.key');
    }
    return $r('sys.symbol.doc_text');
  }

  build() {
    SymbolGlyph(this.symbol())
      .fontSize(this.iconSize)
      .fontColor([AISettingsUiTokens.accent])
      .fontWeight(FontWeight.Medium)
  }
}

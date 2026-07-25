/**
 * 专业版 Composer 色板。工程 color.json 尚未沉淀完整语义色时，用常量对齐 iOS/设计稿。
 */
export class ComposerTheme {
  static readonly accent: string = '#008DFF';
  static readonly accentSoft: string = '#EAF5FF';
  static readonly accentBorder: string = '#B9DEFA';
  static readonly textPrimary: string = '#1C1C1E';
  static readonly textSecondary: string = '#8E8E93';
  static readonly textTertiary: string = '#A1A1A6';
  static readonly gray: string = '#8E8E93';
  static readonly secondaryFill: string = '#F2F2F7';
  static readonly secondaryBackground: string = '#F2F2F7';
  static readonly background: string = '#FFFFFF';
  static readonly secondaryGrouped: string = '#F2F2F7';
  static readonly systemRed: string = '#D64F4F';
  static readonly systemGreen: string = '#34C759';
  static readonly systemPurple: string = '#AF52DE';
  static readonly systemBrown: string = '#A2845E';
  static readonly systemOrange: string = '#FF9500';
  static readonly systemTeal: string = '#30B0C7';
  static readonly systemBlue: string = '#007AFF';
  static readonly darkChip: string = '#29292B';
  static readonly darkChipBorder: string = '#48484A';
  static readonly materialSoft: string = '#FFFFFF99';
  static readonly systemGray6: string = '#F2F2F7';

  static withOpacity(hex: string, opacity: number): string {
    const clean = hex.replace('#', '');
    if (clean.length !== 6) {
      return hex;
    }
    const r = Number.parseInt(clean.substring(0, 2), 16);
    const g = Number.parseInt(clean.substring(2, 4), 16);
    const b = Number.parseInt(clean.substring(4, 6), 16);
    return `rgba(${r},${g},${b},${opacity})`;
  }
}

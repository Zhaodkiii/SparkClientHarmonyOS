/**
 * 对齐 iOS `AIPromptKeywords`（Projects/Core/AIRuntime/AIPromptKeywords.swift）。
 * 提示词中可被运行时替换/开关的关键字常量。
 */
export class AIPromptKeywords {
  static readonly currentDate: string = '{{CURRENT_DATE}}';

  static contains(keyword: string, text: string): boolean {
    return text.indexOf(keyword) >= 0;
  }

  /** 按行开关某个关键字：enabled 时确保关键字独占一行存在，否则移除该行。 */
  static setting(keyword: string, enabled: boolean, text: string): string {
    let lines = text.split('\n')
      .map(line => line.trim())
      .filter(line => line !== keyword);
    if (enabled) {
      lines.push(keyword);
    }
    return lines.join('\n');
  }
}

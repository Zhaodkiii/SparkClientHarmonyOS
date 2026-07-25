import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { i18n } from '@kit.LocalizationKit';

/**
 * 对齐 iOS `AIPromptL10n`：
 * - table Prompts → `Prompts.strings`
 * - table ToolPrompts → `ToolPrompts.strings`
 *
 * 资源路径：`rawfile/ai/prompts/{zh-Hans|zh-Hant|en}/{Prompts|ToolPrompts}.strings`
 * 与 iOS lproj 文件原样一致；改 iOS 后覆盖同名 rawfile。
 */
export class AIPromptL10n {
  private static readonly TABLE_PROMPTS: string = 'Prompts.strings';
  private static readonly TABLE_TOOL_PROMPTS: string = 'ToolPrompts.strings';

  private static context?: common.UIAbilityContext;
  /** `${locale}/${fileName}` → (key → value) */
  private static readonly tableCache: Map<string, Map<string, string>> = new Map();

  private readonly preferredLocales: string[];

  static bindContext(context: common.UIAbilityContext): void {
    AIPromptL10n.context = context;
  }

  static clearContextForTests(): void {
    AIPromptL10n.context = undefined;
    AIPromptL10n.tableCache.clear();
  }

  constructor(languageCode?: string) {
    this.preferredLocales = AIPromptL10n.resolvePreferredLocales(languageCode);
  }

  prompt(key: string, fallback: string): string {
    return this.localizedString(AIPromptL10n.TABLE_PROMPTS, key, fallback);
  }

  promptIfExists(key: string): string | undefined {
    return this.localizedStringIfExists(AIPromptL10n.TABLE_PROMPTS, key);
  }

  promptFormat(key: string, fallback: string, args: Array<string | number>): string {
    return AIPromptL10n.format(this.prompt(key, fallback), args);
  }

  /** 对齐 iOS `tool(_:)`：读 ToolPrompts；缺 key 时回退 fallback 或 key 本身。 */
  tool(key: string, fallback?: string): string {
    return this.localizedString(AIPromptL10n.TABLE_TOOL_PROMPTS, key, fallback ?? key);
  }

  toolIfExists(key: string): string | undefined {
    return this.localizedStringIfExists(AIPromptL10n.TABLE_TOOL_PROMPTS, key);
  }

  toolFormat(key: string, fallback: string, args: Array<string | number>): string {
    return AIPromptL10n.format(this.tool(key, fallback), args);
  }

  static format(template: string, args: Array<string | number>): string {
    let result = template;
    let argIndex = 0;
    while (argIndex < args.length) {
      const atPos = result.indexOf('%@');
      const dPos = result.indexOf('%d');
      let useAt = false;
      if (atPos >= 0 && (dPos < 0 || atPos < dPos)) {
        useAt = true;
      } else if (dPos < 0) {
        break;
      }
      const token = useAt ? '%@' : '%d';
      const pos = useAt ? atPos : dPos;
      const replacement = `${args[argIndex]}`;
      result = result.substring(0, pos) + replacement + result.substring(pos + token.length);
      argIndex++;
    }
    return result;
  }

  private localizedString(fileName: string, key: string, fallback: string): string {
    for (let i = 0; i < this.preferredLocales.length; i++) {
      const value = AIPromptL10n.lookup(this.preferredLocales[i], fileName, key);
      if (value !== undefined) {
        return value;
      }
    }
    return fallback;
  }

  private localizedStringIfExists(fileName: string, key: string): string | undefined {
    for (let i = 0; i < this.preferredLocales.length; i++) {
      const value = AIPromptL10n.lookup(this.preferredLocales[i], fileName, key);
      if (value !== undefined) {
        return value;
      }
    }
    return undefined;
  }

  private static resolvePreferredLocales(languageCode?: string): string[] {
    let code = languageCode ?? '';
    if (code.length === 0) {
      try {
        code = i18n.System.getSystemLanguage() ?? '';
      } catch (_e) {
        code = 'en';
      }
    }
    const lower = code.toLowerCase().split('_').join('-');
    const ordered: string[] = [];

    if (lower.indexOf('zh-hans') === 0 || lower === 'zh-cn' || lower === 'zh-sg' ||
      lower.indexOf('zh-cn') === 0 || lower.indexOf('zh-sg') === 0) {
      ordered.push('zh-Hans');
    } else if (
      lower.indexOf('zh-hant') === 0 ||
      lower.indexOf('zh-tw') === 0 ||
      lower.indexOf('zh-hk') === 0 ||
      lower.indexOf('zh-mo') === 0
    ) {
      ordered.push('zh-Hant');
    } else if (lower === 'zh' || lower.indexOf('zh-') === 0) {
      ordered.push('zh-Hans');
    }

    const languageOnly = lower.split('-')[0];
    if (languageOnly.length > 0) {
      ordered.push(languageOnly);
    }
    ordered.push('en');

    const deduped: string[] = [];
    for (let i = 0; i < ordered.length; i++) {
      if (deduped.indexOf(ordered[i]) < 0) {
        deduped.push(ordered[i]);
      }
    }
    return deduped;
  }

  private static lookup(localeFolder: string, fileName: string, key: string): string | undefined {
    const table = AIPromptL10n.loadTable(localeFolder, fileName);
    if (!table) {
      return undefined;
    }
    return table.get(key);
  }

  private static loadTable(localeFolder: string, fileName: string): Map<string, string> | undefined {
    const cacheKey = `${localeFolder}/${fileName}`;
    const cached = AIPromptL10n.tableCache.get(cacheKey);
    if (cached) {
      return cached;
    }
    const ctx = AIPromptL10n.context;
    if (!ctx) {
      return undefined;
    }
    const path = `ai/prompts/${localeFolder}/${fileName}`;
    try {
      const data = ctx.resourceManager.getRawFileContentSync(path);
      const bytes = data as Uint8Array;
      const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const text = decoder.decodeToString(bytes);
      if (!text || text.length === 0) {
        return undefined;
      }
      const table = AIPromptL10n.parseStringsFile(text);
      AIPromptL10n.tableCache.set(cacheKey, table);
      return table;
    } catch (_e) {
      return undefined;
    }
  }

  static parseStringsFile(text: string): Map<string, string> {
    const result: Map<string, string> = new Map();
    let i = 0;
    const n = text.length;
    while (i < n) {
      while (i < n) {
        const ch = text.charAt(i);
        if (ch === ' ' || ch === '\t' || ch === '\r' || ch === '\n') {
          i++;
          continue;
        }
        if (ch === '/' && i + 1 < n && text.charAt(i + 1) === '/') {
          i += 2;
          while (i < n && text.charAt(i) !== '\n') {
            i++;
          }
          continue;
        }
        if (ch === '/' && i + 1 < n && text.charAt(i + 1) === '*') {
          i += 2;
          while (i + 1 < n && !(text.charAt(i) === '*' && text.charAt(i + 1) === '/')) {
            i++;
          }
          i = Math.min(i + 2, n);
          continue;
        }
        break;
      }
      if (i >= n || text.charAt(i) !== '"') {
        if (i < n) {
          i++;
        }
        continue;
      }
      const keyParsed = AIPromptL10n.parseQuoted(text, i);
      if (!keyParsed) {
        break;
      }
      i = keyParsed.next;
      while (i < n && (text.charAt(i) === ' ' || text.charAt(i) === '\t' || text.charAt(i) === '\r' ||
        text.charAt(i) === '\n')) {
        i++;
      }
      if (i >= n || text.charAt(i) !== '=') {
        continue;
      }
      i++;
      while (i < n && (text.charAt(i) === ' ' || text.charAt(i) === '\t' || text.charAt(i) === '\r' ||
        text.charAt(i) === '\n')) {
        i++;
      }
      if (i >= n || text.charAt(i) !== '"') {
        continue;
      }
      const valParsed = AIPromptL10n.parseQuoted(text, i);
      if (!valParsed) {
        break;
      }
      i = valParsed.next;
      while (i < n && (text.charAt(i) === ' ' || text.charAt(i) === '\t' || text.charAt(i) === '\r' ||
        text.charAt(i) === '\n')) {
        i++;
      }
      if (i < n && text.charAt(i) === ';') {
        i++;
      }
      result.set(keyParsed.value, valParsed.value);
    }
    return result;
  }

  private static parseQuoted(text: string, startQuote: number): PromptStringsToken | undefined {
    if (text.charAt(startQuote) !== '"') {
      return undefined;
    }
    let j = startQuote + 1;
    let out = '';
    const n = text.length;
    while (j < n) {
      const c = text.charAt(j);
      if (c === '\\' && j + 1 < n) {
        const nxt = text.charAt(j + 1);
        if (nxt === 'n') {
          out += '\n';
        } else if (nxt === 't') {
          out += '\t';
        } else if (nxt === 'r') {
          out += '\r';
        } else if (nxt === '"') {
          out += '"';
        } else if (nxt === '\\') {
          out += '\\';
        } else {
          out += nxt;
        }
        j += 2;
        continue;
      }
      if (c === '"') {
        return { value: out, next: j + 1 };
      }
      out += c;
      j++;
    }
    return undefined;
  }
}

interface PromptStringsToken {
  value: string;
  next: number;
}

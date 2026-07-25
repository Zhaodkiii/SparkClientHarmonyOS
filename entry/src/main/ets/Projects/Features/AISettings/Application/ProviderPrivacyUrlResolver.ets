import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

type PrivacyJsonRec = Record<string, Object | string | number | boolean | null>;

/**
 * 从 iOS 同源 APIKeys.json 按 company 解析隐私政策 URL。
 * 当前 RDB 尚未落库 privacyPolicyURL，编辑页用此解析器对标 iOS 展示。
 */
export class ProviderPrivacyUrlResolver {
  private static byCompanyUpper: Map<string, string> = new Map();
  private static loaded: boolean = false;

  static async ensureLoaded(context: common.UIAbilityContext): Promise<void> {
    if (ProviderPrivacyUrlResolver.loaded) {
      return;
    }
    try {
      const data = await context.resourceManager.getRawFileContent('ai/source/AISettings/APIKeys.json');
      const bytes: Uint8Array = data as Uint8Array;
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const text: string = decoder.decodeWithStream(bytes);
      ProviderPrivacyUrlResolver.byCompanyUpper = ProviderPrivacyUrlResolver.parsePrivacyMap(text);
      ProviderPrivacyUrlResolver.loaded = true;
    } catch (_e) {
      ProviderPrivacyUrlResolver.loaded = true;
    }
  }

  private static parsePrivacyMap(text: string): Map<string, string> {
    const map: Map<string, string> = new Map();
    let parsed: Object;
    try {
      parsed = JSON.parse(text) as Object;
    } catch (_e) {
      return map;
    }
    if (!Array.isArray(parsed)) {
      return map;
    }
    const rows: Object[] = parsed as Object[];
    for (let i = 0; i < rows.length; i++) {
      const value: Object = rows[i];
      if (!value || typeof value !== 'object' || Array.isArray(value)) {
        continue;
      }
      const row: PrivacyJsonRec = value as PrivacyJsonRec;
      const company: string = ProviderPrivacyUrlResolver.readText(row, 'company');
      let url: string = ProviderPrivacyUrlResolver.readText(row, 'privacyPolicyURL');
      if (url.length === 0) {
        url = ProviderPrivacyUrlResolver.readText(row, 'privacyPolicyUrl');
      }
      if (company.length > 0 && url.length > 0) {
        map.set(company.toUpperCase(), url);
      }
    }
    return map;
  }

  private static readText(row: PrivacyJsonRec, key: string): string {
    const v: Object | string | number | boolean | null = row[key];
    if (v === null || v === undefined) {
      return '';
    }
    if (typeof v === 'string') {
      return v.trim();
    }
    return `${v}`.trim();
  }

  static urlForCompany(company: string): string {
    const key: string = company.trim().toUpperCase();
    if (key.length === 0) {
      return '';
    }
    return ProviderPrivacyUrlResolver.byCompanyUpper.get(key) ?? '';
  }
}

import { common } from '@kit.AbilityKit';
import { LocalProvider, normalizeProviderId } from '../Domain/AIConfigModels';
import { AIConfigFlowLog } from '../Infrastructure/AIConfigFlowLog';
import { AIProviderNameCatalog } from './AIProviderNameCatalog';
import { isLocalProviderId, LOCAL_PROVIDER_ID } from '../Domain/AILocalProviderIds';

/**
 * 统一 Provider 显示名解析。
 * 规则对齐 iOS localizedDisplayName：
 * custom → 用户名；local → 本地模型资源；系统 → company 资源；缺失 → 安全 fallback（不显示资源 key）。
 */
export class AIProviderDisplayNameResolver {
  private static context?: common.UIAbilityContext;

  static bindContext(context: common.UIAbilityContext): void {
    AIProviderDisplayNameResolver.context = context;
  }

  static clearContextForTests(): void {
    AIProviderDisplayNameResolver.context = undefined;
  }

  /** 从完整 Provider 解析显示名 */
  static display(provider: LocalProvider): string {
    return AIProviderDisplayNameResolver.displayParts(
      provider.id,
      provider.company,
      provider.name,
      provider.source,
      provider.kind
    );
  }

  /** 仅有 id/company 时的轻量解析（模型行、错误文案） */
  static displayByIds(providerId: string, company?: string, name?: string, source?: string): string {
    const kind = isLocalProviderId(providerId) || (company ?? '').toUpperCase() === 'LOCAL' ? 'local' : 'api';
    return AIProviderDisplayNameResolver.displayParts(
      providerId,
      company ?? '',
      name ?? '',
      source ?? '',
      kind
    );
  }

  private static displayParts(
    providerId: string,
    company: string,
    name: string,
    source: string,
    kind: string
  ): string {
    // 1. 自定义：优先用户输入名称
    if (source === 'custom' || providerId.indexOf('custom:') === 0) {
      const customName = (name || '').trim();
      if (customName.length > 0) {
        return customName;
      }
      const companyFallback = (company || '').trim();
      if (companyFallback.length > 0) {
        return companyFallback;
      }
      return AIProviderDisplayNameResolver.safeFallback(providerId, company);
    }

    // 2. 本地模型
    if (kind === 'local' || isLocalProviderId(providerId) || company.toUpperCase() === 'LOCAL') {
      const localName = AIProviderDisplayNameResolver.resolveResource('ai_provider_company_local', '');
      if (localName.length > 0) {
        return localName;
      }
      return '本地模型';
    }

    // 3. providerId / company 命中系统映射
    const byId = AIProviderNameCatalog.resourceNameForCompany(providerId);
    if (byId) {
      const resolved = AIProviderDisplayNameResolver.resolveResource(byId, '');
      if (resolved.length > 0 && resolved !== byId) {
        return resolved;
      }
      if (resolved.length === 0) {
        AIProviderDisplayNameResolver.logMissing(byId, providerId, company);
      }
    }
    const byCompany = AIProviderNameCatalog.resourceNameForCompany(company);
    if (byCompany) {
      const resolved = AIProviderDisplayNameResolver.resolveResource(byCompany, '');
      if (resolved.length > 0 && resolved !== byCompany) {
        return resolved;
      }
      if (resolved.length === 0) {
        AIProviderDisplayNameResolver.logMissing(byCompany, providerId, company);
      }
    }

    // 4. name / company / 脱敏 fallback
    const displayName = (name || '').trim();
    if (displayName.length > 0 && displayName.toUpperCase() !== company.toUpperCase()) {
      return displayName;
    }
    const companyText = (company || '').trim();
    if (companyText.length > 0 && !AIProviderDisplayNameResolver.looksLikeResourceKey(companyText)) {
      return companyText;
    }
    return AIProviderDisplayNameResolver.safeFallback(providerId, company);
  }

  /** 来源标签：本地模型 / Pro / 试用 / 自定义 / 本地种子 */
  static sourceLabel(provider: LocalProvider): string {
    if (provider.kind === 'local' || isLocalProviderId(provider.id)) {
      return AIProviderDisplayNameResolver.resolveResource('ai_provider_source_local', '本地模型');
    }
    if (provider.source === 'pro' || provider.id.indexOf('pro:') === 0) {
      return AIProviderDisplayNameResolver.resolveResource('ai_provider_source_pro', 'Pro');
    }
    if (provider.source === 'trial') {
      return AIProviderDisplayNameResolver.resolveResource('ai_provider_source_trial', '试用');
    }
    if (provider.source === 'custom' || provider.id.indexOf('custom:') === 0) {
      return AIProviderDisplayNameResolver.resolveResource('ai_provider_source_custom', '自定义');
    }
    if (provider.source === 'localSeed' || provider.source === 'system' || provider.id.indexOf('seed:') === 0) {
      return AIProviderDisplayNameResolver.resolveResource('ai_provider_source_seed', '本地种子');
    }
    return provider.source.length > 0 ? provider.source : 'local';
  }

  static modelSourceLabel(modelSource: string, providerId?: string): string {
    if (providerId && isLocalProviderId(providerId)) {
      return AIProviderDisplayNameResolver.resolveResource('ai_provider_source_local', '本地模型');
    }
    if (modelSource === 'pro') {
      return AIProviderDisplayNameResolver.resolveResource('ai_provider_source_pro', 'Pro');
    }
    if (modelSource === 'trial') {
      return AIProviderDisplayNameResolver.resolveResource('ai_provider_source_trial', '试用');
    }
    if (modelSource === 'localUser' || modelSource === 'localSeed' || modelSource === 'local' || modelSource === 'system') {
      return AIProviderDisplayNameResolver.resolveResource('ai_provider_source_local', '本地模型');
    }
    return modelSource.length > 0 ? modelSource : 'local';
  }

  private static resolveResource(resourceName: string, fallback: string): string {
    try {
      const ctx = AIProviderDisplayNameResolver.context;
      if (!ctx) {
        return AIProviderDisplayNameResolver.builtinFallback(resourceName, fallback);
      }
      const value = ctx.resourceManager.getStringByNameSync(resourceName);
      if (value && value.length > 0 && value !== resourceName) {
        return value;
      }
      return AIProviderDisplayNameResolver.builtinFallback(resourceName, fallback);
    } catch (_e) {
      return AIProviderDisplayNameResolver.builtinFallback(resourceName, fallback);
    }
  }

  /** 无 Context / 资源缺失时的内置中文兜底（对齐 iOS zh-Hans 常用厂商） */
  private static builtinFallback(resourceName: string, fallback: string): string {
    if (fallback.length > 0) {
      return fallback;
    }
    switch (resourceName) {
      case 'ai_provider_company_local':
        return '本地模型';
      case 'ai_provider_company_openai':
        return 'OpenAI';
      case 'ai_provider_company_google':
        return '谷歌Gemini';
      case 'ai_provider_company_anthropic':
        return 'Anthropic';
      case 'ai_provider_company_deepseek':
        return '深度求索';
      case 'ai_provider_company_zhipu':
        return '智谱华章';
      case 'ai_provider_company_bytedance':
        return '字节豆包';
      case 'ai_provider_company_302ai':
        return '302.AI';
      case 'ai_provider_company_spark':
        return '小鲸';
      case 'ai_provider_company_qwen':
        return '阿里通义';
      case 'ai_provider_company_kimi':
        return '月之暗面';
      case 'ai_provider_source_local':
        return '本地模型';
      case 'ai_provider_source_pro':
        return 'Pro';
      case 'ai_provider_source_trial':
        return '试用';
      case 'ai_provider_source_custom':
        return '自定义';
      case 'ai_provider_source_seed':
        return '本地种子';
      default:
        return '';
    }
  }

  private static safeFallback(providerId: string, company: string): string {
    const companyNorm = normalizeProviderId(company);
    if (companyNorm.length > 0 && companyNorm !== 'UNKNOWN' &&
      !AIProviderDisplayNameResolver.looksLikeResourceKey(companyNorm)) {
      return companyNorm;
    }
    if (isLocalProviderId(providerId)) {
      return LOCAL_PROVIDER_ID;
    }
    const idNorm = normalizeProviderId(providerId.indexOf(':') >= 0
      ? providerId.substring(providerId.lastIndexOf(':') + 1)
      : providerId);
    if (idNorm.length > 0 && idNorm !== 'UNKNOWN') {
      return idNorm;
    }
    return 'Provider';
  }

  private static looksLikeResourceKey(text: string): boolean {
    return text.indexOf('company_') === 0 || text.indexOf('ai_provider_company_') === 0;
  }

  private static logMissing(resourceName: string, providerId: string, company: string): void {
    AIConfigFlowLog.warn(
      'provider_display_name_missing',
      `resource=${resourceName} providerId=${providerId} company=${company}`
    );
  }
}

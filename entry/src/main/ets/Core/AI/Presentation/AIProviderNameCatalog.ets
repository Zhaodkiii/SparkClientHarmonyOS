import { normalizeProviderId } from '../Domain/AIConfigModels';

/**
 * Provider ID / company → 资源名映射。
 * 资源 key 形态：ai_provider_company_<slug>，slug 为 normalizeProviderId 的小写形式。
 * 不修改 LocalProvider.company/name，只提供查找。
 */
export class AIProviderNameCatalog {
  /** 已知系统厂商 company 码（大写） */
  private static readonly KNOWN: string[] = [
    'AI302',
    'AIHUBMIX',
    'ANTHROPIC',
    'BYTEDANCE',
    'CHERRY_IN',
    'DEEPSEEK',
    'DOUBAO',
    'GITEE',
    'GOOGLE',
    'HUNYUAN',
    'IFLOW',
    'KIMI',
    'LAN',
    'LOCAL',
    'LONGCAT',
    'MIMO',
    'MINIMAX',
    'MODELSCOPE',
    'N1N',
    'OPENAI',
    'OPENROUTER',
    'PERPLEXITY',
    'POE',
    'QWEN',
    'SILICONCLOUD',
    'SPARK',
    'STEP',
    'WENXIN',
    'XAI',
    'YI',
    'ZHIPU',
    'ZHIPUAI',
    '302AI'
  ];

  /** company/providerId → 资源名；未知返回 undefined */
  static resourceNameForCompany(companyOrId: string): string | undefined {
    const slug = AIProviderNameCatalog.canonicalSlug(companyOrId);
    if (slug.length === 0) {
      return undefined;
    }
    if (!AIProviderNameCatalog.isKnownSlug(slug)) {
      return undefined;
    }
    return `ai_provider_company_${slug}`;
  }

  /** 将别名收敛到资源 slug（小写） */
  static canonicalSlug(companyOrId: string): string {
    let raw = (companyOrId || '').trim();
    if (raw.length === 0) {
      return '';
    }
    // 去掉 seed:/pro:/custom: 前缀，只取公司段
    const colon = raw.lastIndexOf(':');
    if (colon >= 0 && colon < raw.length - 1) {
      raw = raw.substring(colon + 1);
    }
    const upper = normalizeProviderId(raw);
    if (upper === 'ZHIPUAI' || upper === 'ZHIPU') {
      return 'zhipu';
    }
    if (upper === 'AI302' || upper === '302AI') {
      return '302ai';
    }
    if (upper === 'BYTEDANCE' || upper === 'DOUBAO') {
      return 'bytedance';
    }
    if (upper === 'LOCAL') {
      return 'local';
    }
    return upper.toLowerCase();
  }

  static isKnownSlug(slug: string): boolean {
    const upper = slug.toUpperCase().replace(/-/g, '_');
    // 别名 slug 也视为已知
    if (slug === 'zhipu' || slug === '302ai' || slug === 'bytedance' || slug === 'local' || slug === 'spark') {
      return true;
    }
    for (let i = 0; i < AIProviderNameCatalog.KNOWN.length; i++) {
      if (normalizeProviderId(AIProviderNameCatalog.KNOWN[i]).toLowerCase() === slug ||
        AIProviderNameCatalog.KNOWN[i] === upper) {
        return true;
      }
    }
    return false;
  }

  static isKnownCompany(companyOrId: string): boolean {
    return AIProviderNameCatalog.resourceNameForCompany(companyOrId) !== undefined;
  }
}

import { normalizeProviderId } from '../Domain/AIConfigModels';

/**
 * Provider/company → HarmonyOS media 资源名。
 * 资源名与 iOS `CompanyIconNameMapper` 对齐，统一使用小写 snake_case。
 */
export class AIProviderIconCatalog {
  static resourceNameForCompany(companyOrId: string): string {
    const slug = AIProviderIconCatalog.canonicalSlug(companyOrId);
    if (slug.length === 0) {
      return 'default_icon';
    }
    switch (slug) {
      case 'hanlin':
        return 'hanlin';
      case 'zhipuai':
        return 'zhipuai';
      case 'qwen':
        return 'qwen';
      case 'deepseek':
        return 'deepseek';
      case 'siliconcloud':
        return 'siliconflow';
      case 'github':
        return 'github';
      case 'doubao':
      case 'bytedance':
        return 'doubao';
      case 'kimi':
        return 'kimi';
      case 'openai':
        return 'openai';
      case 'google':
        return 'google';
      case 'google_search':
        return 'google_search';
      case 'xai':
        return 'xai';
      case 'anthropic':
        return 'claude';
      case 'local':
        return 'assistant';
      case 'modelscope':
        return 'modelscope';
      case 'lan':
        return 'lm_studio';
      case 'wenxin':
        return 'wenxin';
      case 'yi':
        return 'yi';
      case 'hunyuan':
        return 'hunyuan';
      case 'step':
        return 'step';
      case 'bochaai':
        return 'bochaai';
      case 'bing':
        return 'bing';
      case 'exa':
        return 'exa';
      case 'tavily':
        return 'tavily';
      case 'langsearch':
        return 'langsearch';
      case 'tiangong':
        return 'tiangong';
      case 'spark':
        return 'spark';
      case 'perplexity':
        return 'perplexity';
      case 'openrouter':
        return 'openrouter';
      case 'hanlinweb':
        return 'webreader';
      case 'hanlinbag':
        return 'knowledge_bag';
      case 'brave':
        return 'brave';
      case 'siri':
        return 'siri';
      case 'gitee':
        return 'gitee';
      case 'applemap':
        return 'applemap';
      case 'amap':
        return 'amap';
      case 'baidumap':
        return 'baidumap';
      case 'googlemap':
        return 'googlemap';
      case 'arxiv':
        return 'arxiv';
      case 'qweather':
        return 'qweather';
      case 'openweather':
        return 'openweather';
      case 'minimax':
        return 'minimax';
      case 'cherry_in':
        return 'cherry';
      case 'mimo':
        return 'mimo';
      case 'longcat':
        return 'longcat';
      case 'ai302':
      case '302ai':
        return 'ai302';
      case 'poe':
        return 'poe';
      case 'aihubmix':
        return 'aihubmix';
      case 'iflow':
        return 'iflow';
      case 'n1n':
        return 'n1n';
      case 'meta':
        return 'meta';
      case 'huggingface':
        return 'huggingface';
      case 'prompt':
        return 'prompt';
      case 'translate':
        return 'translate';
      case 'translate_circle':
        return 'translate_circle';
      case 'default_icon':
        return 'default_icon';
      default:
        return 'default_icon';
    }
  }

  static canonicalSlug(companyOrId: string): string {
    let raw = (companyOrId || '').trim();
    if (raw.length === 0) {
      return '';
    }
    const colon = raw.lastIndexOf(':');
    if (colon >= 0 && colon < raw.length - 1) {
      raw = raw.substring(colon + 1);
    }
    const upper = normalizeProviderId(raw);
    switch (upper) {
      case 'HANLIN_OPEN':
        return 'hanlin';
      case 'HANLINWEB':
        return 'hanlinweb';
      case 'HANLINBAG':
        return 'hanlinbag';
      case 'ZHIPU':
        return 'zhipuai';
      case 'ZHIPUAI':
        return 'zhipuai';
      case '302AI':
        return 'ai302';
      case 'BYTEDANCE':
        return 'bytedance';
      default:
        return upper.toLowerCase();
    }
  }
}

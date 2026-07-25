import { AIProviderIconCatalog } from '../../../../../Core/AI/Presentation/AIProviderIconCatalog';

@Component
export struct AISettingsBrandIcon {
  company: string = '';
  iconSize: number = 24;

  private resource(): Resource {
    switch (AIProviderIconCatalog.resourceNameForCompany(this.company)) {
      case 'hanlin':
        return $r('app.media.hanlin');
      case 'zhipuai':
        return $r('app.media.zhipuai');
      case 'qwen':
        return $r('app.media.qwen');
      case 'deepseek':
        return $r('app.media.deepseek');
      case 'siliconflow':
        return $r('app.media.siliconflow');
      case 'github':
        return $r('app.media.github');
      case 'doubao':
        return $r('app.media.doubao');
      case 'kimi':
        return $r('app.media.kimi');
      case 'openai':
        return $r('app.media.openai');
      case 'google':
        return $r('app.media.google');
      case 'google_search':
        return $r('app.media.google_search');
      case 'xai':
        return $r('app.media.xai');
      case 'claude':
        return $r('app.media.claude');
      case 'assistant':
        return $r('app.media.assistant');
      case 'modelscope':
        return $r('app.media.modelscope');
      case 'lm_studio':
        return $r('app.media.lm_studio');
      case 'wenxin':
        return $r('app.media.wenxin');
      case 'yi':
        return $r('app.media.yi');
      case 'hunyuan':
        return $r('app.media.hunyuan');
      case 'step':
        return $r('app.media.step');
      case 'bochaai':
        return $r('app.media.bochaai');
      case 'bing':
        return $r('app.media.bing');
      case 'exa':
        return $r('app.media.exa');
      case 'tavily':
        return $r('app.media.tavily');
      case 'langsearch':
        return $r('app.media.langsearch');
      case 'tiangong':
        return $r('app.media.tiangong');
      case 'spark':
        return $r('app.media.spark');
      case 'perplexity':
        return $r('app.media.perplexity');
      case 'openrouter':
        return $r('app.media.openrouter');
      case 'webreader':
        return $r('app.media.webreader');
      case 'knowledge_bag':
        return $r('app.media.knowledge_bag');
      case 'brave':
        return $r('app.media.brave');
      case 'siri':
        return $r('app.media.siri');
      case 'gitee':
        return $r('app.media.gitee');
      case 'applemap':
        return $r('app.media.applemap');
      case 'amap':
        return $r('app.media.amap');
      case 'baidumap':
        return $r('app.media.baidumap');
      case 'googlemap':
        return $r('app.media.googlemap');
      case 'arxiv':
        return $r('app.media.arxiv');
      case 'qweather':
        return $r('app.media.qweather');
      case 'openweather':
        return $r('app.media.openweather');
      case 'minimax':
        return $r('app.media.minimax');
      case 'cherry':
        return $r('app.media.cherry');
      case 'mimo':
        return $r('app.media.mimo');
      case 'longcat':
        return $r('app.media.longcat');
      case 'ai302':
        return $r('app.media.ai302');
      case 'poe':
        return $r('app.media.poe');
      case 'aihubmix':
        return $r('app.media.aihubmix');
      case 'iflow':
        return $r('app.media.iflow');
      case 'n1n':
        return $r('app.media.n1n');
      case 'meta':
        return $r('app.media.meta');
      case 'huggingface':
        return $r('app.media.huggingface');
      case 'prompt':
        return $r('app.media.prompt');
      case 'translate':
        return $r('app.media.translate');
      case 'translate_circle':
        return $r('app.media.translate_circle');
      case 'default_icon':
        return $r('app.media.default_icon');
      default:
        return $r('app.media.default_icon');
    }
  }

  build() {
    Image(this.resource())
      .width(this.iconSize)
      .height(this.iconSize)
      .objectFit(ImageFit.Contain)
  }
}

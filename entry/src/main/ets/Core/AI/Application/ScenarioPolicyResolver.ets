import { AIResolvedConfig } from '../Domain/AIConfigModels';

/**
 * 对齐 iOS ScenarioPolicyResolver：精确 preferred，禁止 indexOf 模糊命中。
 */
export class ScenarioPolicyResolver {
  static pickExact(
    list: AIResolvedConfig[],
    preferredModelName?: string
  ): AIResolvedConfig | undefined {
    if (!preferredModelName || preferredModelName.length === 0) {
      return list.length > 0 ? list[0] : undefined;
    }
    for (let i = 0; i < list.length; i++) {
      if (list[i].modelName === preferredModelName || list[i].modelId === preferredModelName) {
        return list[i];
      }
    }
    return undefined;
  }

  static pickBySource(list: AIResolvedConfig[], preferredSource?: string): AIResolvedConfig | undefined {
    if (preferredSource === 'local') {
      for (let i = 0; i < list.length; i++) {
        if (list[i].source === 'local' || list[i].modelType === 'gguf') {
          return list[i];
        }
      }
    }
    if (preferredSource === 'pro') {
      for (let i = 0; i < list.length; i++) {
        if (list[i].source === 'pro' || list[i].source === 'trial') {
          return list[i];
        }
      }
    }
    return list.length > 0 ? list[0] : undefined;
  }
}

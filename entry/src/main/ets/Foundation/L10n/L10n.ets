import { common } from '@kit.AbilityKit';

/**
 * 非 UI 场景本地化读取；UI 优先使用 $r('app.string.xxx')。
 * 失败时返回 fallback，不抛异常。
 */
export class L10n {
  private static context?: common.UIAbilityContext;

  static bindContext(context: common.UIAbilityContext): void {
    L10n.context = context;
  }

  static clearContextForTests(): void {
    L10n.context = undefined;
  }

  /**
   * 通过 Resource 对象读取字符串（推荐：$r('app.string.xxx')）。
   */
  static getString(resource: Resource, fallback: string): string {
    try {
      const ctx = L10n.context;
      if (!ctx) {
        return fallback;
      }
      const value = ctx.resourceManager.getStringSync(resource.id);
      if (value && value.length > 0) {
        return value;
      }
      return fallback;
    } catch (_e) {
      return fallback;
    }
  }

  /**
   * 简单命名参数替换：文案中的 {name} 替换为 params['name']。
   */
  static format(template: string, params: Record<string, string>): string {
    let result = template;
    const keys = Object.keys(params);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      result = result.replace(new RegExp(`\\{${key}\\}`, 'g'), params[key]);
    }
    return result;
  }
}

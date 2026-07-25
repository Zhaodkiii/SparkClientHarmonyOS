import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { AISettingsRoutes } from './AISettingsRoutes';

/**
 * AI 设置唯一栈所有者：集中 push/pop，子页不得自建 Navigation。
 */
export class AISettingsNavigationController {
  private readonly stack: NavPathStack;
  private readonly onRootBack: () => void;

  constructor(stack: NavPathStack, onRootBack: () => void) {
    this.stack = stack;
    this.onRootBack = onRootBack;
  }

  get pathStack(): NavPathStack {
    return this.stack;
  }

  depth(): number {
    return this.stack.size();
  }

  push(route: string, param?: string): void {
    const depth = this.stack.size();
    const fields = new LogFields();
    fields.detail = `导航压栈 to=${route} paramId=${param ?? ''} depth=${depth}->${depth + 1}`;
    Logger.info('ai.nav.push', LogModule.AI_CONFIG, fields);
    if (param !== undefined && param !== null) {
      this.stack.pushPath({ name: route, param: param });
    } else {
      this.stack.pushPath({ name: route });
    }
  }

  pop(): void {
    const depth = this.stack.size();
    const from = AISettingsNavigationController.topRouteName(this.stack);
    const fields = new LogFields();
    fields.detail =
      depth > 0
        ? `导航回退 from=${from} depth=${depth}->${depth - 1}`
        : `导航回退到 AI 根页 from=${from || 'root'} depth=0`;
    Logger.info('ai.nav.pop', LogModule.AI_CONFIG, fields);
    if (depth > 0) {
      this.stack.pop();
    } else {
      this.onRootBack();
    }
  }

  private static topRouteName(stack: NavPathStack): string {
    try {
      const names = stack.getAllPathName();
      if (names && names.length > 0) {
        return names[names.length - 1];
      }
    } catch (_e) {
      // ignore
    }
    return '';
  }

  /** 系统返回：子栈非空只弹一层，否则关闭 AI 根页 */
  handleBackPressed(): boolean {
    if (this.stack.size() > 0) {
      this.stack.pop();
      return true;
    }
    this.onRootBack();
    return true;
  }

  pushProviders(): void {
    this.push(AISettingsRoutes.PROVIDERS);
  }

  pushModels(): void {
    this.push(AISettingsRoutes.MODELS);
  }

  pushPreferences(): void {
    this.push(AISettingsRoutes.PREFERENCES);
  }

  pushSmallTasks(): void {
    this.push(AISettingsRoutes.SMALL_TASKS);
  }

  pushRuntimePlayground(): void {
    this.push(AISettingsRoutes.RUNTIME_PLAYGROUND);
  }

  paramOf(route: string): string {
    try {
      const raw = this.stack.getParamByName(route) as Array<Object>;
      if (!raw || raw.length === 0) {
        return '';
      }
      return `${raw[0]}`;
    } catch (_e) {
      return '';
    }
  }
}

/**
 * 根 Navigation 路由（对齐 Recycling phoneRouterControl）。
 * 二级页经 jumpPage 压入 Index.rootStack，覆盖 MainTabsPage，从而统一隐藏底部 Tab。
 */
export class AppRouter {
  private stack?: NavPathStack;

  bind(stack: NavPathStack): void {
    this.stack = stack;
  }

  isBound(): boolean {
    return this.stack !== undefined;
  }

  /**
   * 跳转二级页。pageName 必须由 Index.navDestination 识别。
   */
  jumpPage(pageName: string, param?: Object | string): void {
    const stack = this.stack;
    if (!stack) {
      return;
    }
    if (param === undefined) {
      stack.pushPath({ name: pageName });
      return;
    }
    stack.pushPath({ name: pageName, param: param });
  }

  replacePage(pageName: string, param?: Object | string): void {
    const stack = this.stack;
    if (!stack) {
      return;
    }
    if (param === undefined) {
      stack.replacePath({ name: pageName });
      return;
    }
    stack.replacePath({ name: pageName, param: param });
  }

  popPage(): void {
    this.stack?.pop();
  }

  clear(): void {
    this.stack?.clear();
  }

  /** 取栈上某路由最近一次入参（HarmonyOS getParamByName 返回数组）。 */
  latestParam(pageName: string): Object | string | undefined {
    const stack = this.stack;
    if (!stack) {
      return undefined;
    }
    try {
      const params = stack.getParamByName(pageName) as Array<Object | string>;
      if (params.length === 0) {
        return undefined;
      }
      return params[params.length - 1];
    } catch (_e) {
      return undefined;
    }
  }
}

export const appRouter: AppRouter = new AppRouter();

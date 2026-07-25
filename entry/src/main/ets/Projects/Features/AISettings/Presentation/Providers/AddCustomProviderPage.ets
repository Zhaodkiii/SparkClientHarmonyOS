import { AddCustomProviderSheet } from './AddCustomProviderSheet';

/**
 * 全页入口（路由 ai.provider.add）。主体对标 iOS AddCustomProviderSheet，
 * 列表页优先通过 bindSheet 打开同一组件。
 */
@Component
export struct AddCustomProviderPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };

  private doBack(): void {
    if (this.onBack) {
      this.onBack();
    } else {
      this.stack.pop();
    }
  }

  build() {
    AddCustomProviderSheet({
      onClose: () => {
        this.doBack();
      },
      onSaved: () => {
      }
    })
  }
}

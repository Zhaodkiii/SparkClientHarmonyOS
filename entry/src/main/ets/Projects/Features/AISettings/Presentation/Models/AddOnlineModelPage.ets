import { AddOnlineModelSheet } from './AddOnlineModelSheet';
import { AddOnlineModelDraft } from '../../Application/AddOnlineModelModels';

/**
 * 全页入口：复用通用 AddOnlineModelSheet（对标 iOS 从模型列表打开同一表单）。
 */
@Component
export struct AddOnlineModelPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  /** 可选：从路由/调用方锁定厂商 */
  initialProviderId: string = '';
  initialDraft?: AddOnlineModelDraft;

  private doBack(): void {
    if (this.onBack) {
      this.onBack();
    } else {
      this.stack.pop();
    }
  }

  build() {
    AddOnlineModelSheet({
      initialProviderId: this.initialProviderId,
      initialDraft: this.initialDraft,
      showAsPage: true,
      onClose: () => {
        this.doBack();
      },
      onSaved: () => {
      }
    })
  }
}

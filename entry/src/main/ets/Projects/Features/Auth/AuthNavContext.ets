import { LoginViewModel } from './LoginViewModel';

/**
 * 登录局部导航共享上下文（同一次登录栈内共享 ViewModel）。
 */
export class AuthNavContext {
  static viewModel?: LoginViewModel;
  static pathStack?: NavPathStack;

  static ensureViewModel(): LoginViewModel {
    if (!AuthNavContext.viewModel) {
      AuthNavContext.viewModel = new LoginViewModel();
    }
    return AuthNavContext.viewModel;
  }

  static reset(): void {
    if (AuthNavContext.viewModel) {
      AuthNavContext.viewModel.dispose();
    }
    AuthNavContext.viewModel = undefined;
    AuthNavContext.pathStack = undefined;
  }
}

import { UserSession } from '../../Core/Domain/Entities/UserSession';
import { SessionState } from '../../../App/AppSessionStore';

export type SettingsAccountAction = 'none' | 'openAccount' | 'upgrade' | 'disabled';

/**
 * 设置页账户行分流：纯函数便于单测。
 */
export class SettingsAccountRouting {
  static resolveAction(sessionState: SessionState, session: UserSession | undefined): SettingsAccountAction {
    if (sessionState === 'loading') {
      return 'disabled';
    }
    if (sessionState !== 'signedIn' || session === undefined) {
      return 'none';
    }
    if (session.isDeviceAccount) {
      return 'upgrade';
    }
    return 'openAccount';
  }

  static summaryText(sessionState: SessionState, session: UserSession | undefined): string {
    if (sessionState === 'loading') {
      return '恢复中…';
    }
    if (sessionState !== 'signedIn' || session === undefined) {
      return '';
    }
    if (session.isDeviceAccount) {
      return '游客模式';
    }
    if (session.displayName.length > 0) {
      return session.displayName;
    }
    if (session.email.length > 0) {
      return session.email;
    }
    return '已登录';
  }
}

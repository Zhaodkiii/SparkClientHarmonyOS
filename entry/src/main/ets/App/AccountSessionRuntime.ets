import { UserSession } from '../Projects/Core/Domain/Entities/UserSession';
import { SessionSnapshotStore } from '../Projects/Features/Auth/Infrastructure/SessionSnapshotStore';
import { Logger } from '../Foundation/Logging/Logger';
import { LogModule } from '../Foundation/Logging/LogModule';
import { CURRENT_ACCOUNT_ID_KEY, publishCurrentAccountId, publishPreparedAccountId } from './AppStartupKeys';

/**
 * 账号级会话运行时：切换标记、快照清理、currentAccountId 发布。
 */
export class AccountSessionRuntime {
  private readonly snapshotStore: SessionSnapshotStore;
  private accountSwitchInProgress: boolean = false;
  private currentAccountId?: number;
  private onAccountDataCleared?: (reason: string) => Promise<void>;

  constructor(snapshotStore: SessionSnapshotStore) {
    this.snapshotStore = snapshotStore;
  }

  /** 登出 / 鉴权失效 / 账号切换时清理账号级本地数据（如通知 inbox）。reason: switch | signOut */
  setOnAccountDataCleared(cb: (reason: string) => Promise<void>): void {
    this.onAccountDataCleared = cb;
  }

  get isAccountSwitchInProgress(): boolean {
    return this.accountSwitchInProgress;
  }

  get activeAccountId(): number | undefined {
    return this.currentAccountId;
  }

  beginAccountSwitch(): void {
    this.accountSwitchInProgress = true;
  }

  async activateUser(accountId: number): Promise<void> {
    if (this.currentAccountId !== undefined && this.currentAccountId !== accountId) {
      Logger.info('account.switch_activate', LogModule.AUTH);
      publishPreparedAccountId(-1);
      await this.notifyAccountDataCleared('switch');
    }
    this.currentAccountId = accountId;
    this.accountSwitchInProgress = false;
    publishCurrentAccountId(accountId);
  }

  async onSignedIn(session: UserSession): Promise<void> {
    if (this.currentAccountId !== undefined && this.currentAccountId !== session.accountId) {
      Logger.info('account.switch_completed', LogModule.AUTH);
      await this.notifyAccountDataCleared('switch');
    }
    this.currentAccountId = session.accountId;
    this.accountSwitchInProgress = false;
    publishCurrentAccountId(session.accountId);
  }

  async onSignedOut(): Promise<void> {
    await this.notifyAccountDataCleared('signOut');
    this.clearPublishedAccountIds();
    this.accountSwitchInProgress = false;
  }

  clearPublishedAccountIds(): void {
    this.currentAccountId = undefined;
    publishCurrentAccountId(-1);
    publishPreparedAccountId(-1);
    try {
      AppStorage.setOrCreate(CURRENT_ACCOUNT_ID_KEY, -1);
    } catch (_e) {
      // ignore
    }
  }

  /** 鉴权失效时确保快照清除（Token 由网络层已清）。 */
  async onAuthInvalidated(): Promise<void> {
    await this.snapshotStore.clear();
    await this.onSignedOut();
  }

  private async notifyAccountDataCleared(reason: string = 'switch'): Promise<void> {
    if (!this.onAccountDataCleared) {
      return;
    }
    try {
      await this.onAccountDataCleared(reason);
    } catch (_e) {
      // 清理失败不阻断登出/切换
    }
  }
}

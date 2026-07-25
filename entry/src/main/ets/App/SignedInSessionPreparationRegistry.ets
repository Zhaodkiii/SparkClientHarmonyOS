import { PREPARED_ACCOUNT_ID_KEY, publishPreparedAccountId } from './AppStartupKeys';

export type PreparationState = 'idle' | 'preparing' | 'prepared';

/**
 * 已登录账号准备串行化：同账号单飞，成功后标记 prepared。
 */
export class SignedInSessionPreparationRegistry {
  private state: PreparationState = 'idle';
  private preparingAccountId?: number;
  private preparedId?: number;
  private inFlight?: Promise<void>;

  get preparationState(): PreparationState {
    return this.state;
  }

  get preparedAccountId(): number | undefined {
    return this.preparedId;
  }

  async runIfNeeded(accountId: number, operation: () => Promise<void>): Promise<void> {
    if (this.preparedId === accountId) {
      return;
    }
    if (this.inFlight && this.preparingAccountId === accountId) {
      await this.inFlight;
      return;
    }
    this.state = 'preparing';
    this.preparingAccountId = accountId;
    this.inFlight = operation()
      .catch(() => {
        // 失败由 operation 内 rollback；此处吞掉避免未处理 rejection
      })
      .finally(() => {
        this.inFlight = undefined;
        this.preparingAccountId = undefined;
        if (this.state === 'preparing') {
          this.state = 'idle';
        }
      });
    await this.inFlight;
  }

  markPrepared(accountId: number): void {
    this.preparedId = accountId;
    this.state = 'prepared';
    publishPreparedAccountId(accountId);
  }

  rollbackPreparingIfNeeded(accountId: number): void {
    if (this.state === 'preparing' && this.preparingAccountId === accountId) {
      this.state = 'idle';
      this.preparingAccountId = undefined;
    }
  }

  reset(): void {
    this.inFlight = undefined;
    this.preparingAccountId = undefined;
    this.preparedId = undefined;
    this.state = 'idle';
    publishPreparedAccountId(-1);
    try {
      AppStorage.setOrCreate(PREPARED_ACCOUNT_ID_KEY, -1);
    } catch (_e) {
      // ignore
    }
  }

  /** 测试用 */
  setPreparedForTests(accountId: number | undefined): void {
    this.preparedId = accountId;
    this.state = accountId !== undefined ? 'prepared' : 'idle';
    publishPreparedAccountId(accountId ?? -1);
  }
}

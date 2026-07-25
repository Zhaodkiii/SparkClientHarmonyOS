import { RuntimeSnapshot } from '../Domain/AIConfigModels';
import { publishAiRuntimeReady } from '../../../App/AppStartupKeys';

/**
 * 内存运行时快照：不可变替换；账号切换清空。
 */
export class AIRuntimeSnapshotStore {
  private readonly byAccount: Map<number, RuntimeSnapshot> = new Map();

  publish(snapshot: RuntimeSnapshot): void {
    const prev = this.byAccount.get(snapshot.accountId);
    if (snapshot.generation <= 0) {
      snapshot.generation = (prev?.generation ?? 0) + 1;
    }
    this.byAccount.set(snapshot.accountId, snapshot);
  }

  get(accountId: number): RuntimeSnapshot | undefined {
    return this.byAccount.get(accountId);
  }

  clear(accountId?: number): void {
    if (accountId === undefined) {
      this.byAccount.clear();
      publishAiRuntimeReady(false, -1);
      return;
    }
    this.byAccount.delete(accountId);
    publishAiRuntimeReady(false, accountId);
  }

  invalidate(accountId: number): void {
    const cur = this.byAccount.get(accountId);
    const next = new RuntimeSnapshot();
    next.accountId = accountId;
    next.state = 'invalidated';
    next.createdAt = new Date().toISOString();
    next.degradeReason = 'sessionInvalidated';
    next.generation = (cur?.generation ?? 0) + 1;
    this.byAccount.set(accountId, next);
    publishAiRuntimeReady(false, accountId);
  }
}

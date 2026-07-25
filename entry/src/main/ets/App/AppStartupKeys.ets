/**
 * 启动链路 AppStorage 键与网络门禁状态。
 */
export const NETWORK_GATE_KEY: string = 'app.networkGate';
export const PREPARED_ACCOUNT_ID_KEY: string = 'app.preparedAccountId';
export const CURRENT_ACCOUNT_ID_KEY: string = 'app.currentAccountId';
/** AI Runtime 是否已对本账号发布可用快照（localReady/remoteReady/degraded） */
export const AI_RUNTIME_READY_KEY: string = 'app.aiRuntimeReady';
export const AI_RUNTIME_ACCOUNT_ID_KEY: string = 'app.aiRuntimeAccountId';

/** none | evaluating | offline */
export type NetworkGateState = 'none' | 'evaluating' | 'offline';

export function publishNetworkGate(state: NetworkGateState): void {
  try {
    AppStorage.setOrCreate(NETWORK_GATE_KEY, state);
  } catch (_e) {
    // 单测环境可能无 AppStorage
  }
}

export function publishPreparedAccountId(accountId: number): void {
  try {
    AppStorage.setOrCreate(PREPARED_ACCOUNT_ID_KEY, accountId);
  } catch (_e) {
    // ignore
  }
}

export function publishCurrentAccountId(accountId: number): void {
  try {
    AppStorage.setOrCreate(CURRENT_ACCOUNT_ID_KEY, accountId);
  } catch (_e) {
    // ignore
  }
}

export function publishAiRuntimeReady(ready: boolean, accountId: number = -1): void {
  try {
    AppStorage.setOrCreate(AI_RUNTIME_READY_KEY, ready);
    AppStorage.setOrCreate(AI_RUNTIME_ACCOUNT_ID_KEY, accountId);
  } catch (_e) {
    // ignore
  }
}

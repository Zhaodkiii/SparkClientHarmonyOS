import { ProBootstrapSnapshot } from '../Domain/AIConfigModels';

/**
 * Pro Overlay 内存缓存（对标 iOS AIRuntimeConfigStore.proBundles）。
 * 不进入本地 ai_provider / ai_model 密钥目录。
 */
export class ProOverlayEntry {
  accountId: number = 0;
  remote: ProBootstrapSnapshot = new ProBootstrapSnapshot();
  secretRefs: Map<string, string> = new Map();
  etag?: string;
  updatedAt: string = '';
}

export class ProOverlayStore {
  private readonly byAccount: Map<number, ProOverlayEntry> = new Map();

  set(
    accountId: number,
    remote: ProBootstrapSnapshot,
    secretRefs: Map<string, string>,
    etag?: string
  ): void {
    const entry = new ProOverlayEntry();
    entry.accountId = accountId;
    entry.remote = remote;
    entry.secretRefs = new Map(secretRefs);
    entry.etag = etag;
    entry.updatedAt = new Date().toISOString();
    this.byAccount.set(accountId, entry);
  }

  get(accountId: number): ProOverlayEntry | undefined {
    return this.byAccount.get(accountId);
  }

  clear(accountId?: number): void {
    if (accountId === undefined) {
      this.byAccount.clear();
      return;
    }
    this.byAccount.delete(accountId);
  }

  has(accountId: number): boolean {
    return this.byAccount.has(accountId);
  }
}

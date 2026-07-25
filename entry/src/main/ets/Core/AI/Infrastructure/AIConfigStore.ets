import {
  AIConfigSnapshot,
  AIUserPreferences,
  nowIso,
  ProBootstrapSnapshot,
  hydrateSnapshot
} from '../Domain/AIConfigModels';
import { ProOverlayMaterializer } from '../Application/ProOverlayMaterializer';

/** AI 配置持久化抽象：RDB 与单测内存实现共用。 */
export abstract class AIConfigStore {
  abstract load(accountId: number): Promise<AIConfigSnapshot | undefined>;

  abstract saveLocal(accountId: number, snapshot: AIConfigSnapshot): Promise<void>;

  /**
   * Pro bootstrap 成功后：清理本地目录中遗留的 Pro 行，并更新 revision/etag。
   * 不再把 Pro Provider/Model 写入本地密钥目录。
   */
  abstract publishProOverlayMeta(
    accountId: number,
    remote: ProBootstrapSnapshot,
    etag?: string
  ): Promise<void>;

  /** @deprecated 使用 publishProOverlayMeta；保留别名兼容旧调用 */
  async replaceRemotePro(
    accountId: number,
    remote: ProBootstrapSnapshot,
    _providerSecretRefs: Map<string, string>,
    etag?: string
  ): Promise<void> {
    await this.publishProOverlayMeta(accountId, remote, etag);
  }

  abstract deleteAccount(accountId: number): Promise<void>;

  abstract updateSyncState(accountId: number, state: string, extra?: Record<string, string>): Promise<void>;
}

/**
 * 内存实现：单测与无 RDB 环境；账号隔离。
 * Pro overlay 不进入 providers/models，仅更新 revision 元数据。
 */
export class MemoryAIConfigStore extends AIConfigStore {
  private readonly byAccount: Map<number, AIConfigSnapshot> = new Map();

  async load(accountId: number): Promise<AIConfigSnapshot | undefined> {
    const snap = this.byAccount.get(accountId);
    if (!snap) {
      return undefined;
    }
    return MemoryAIConfigStore.cloneLocalOnly(snap);
  }

  async saveLocal(accountId: number, snapshot: AIConfigSnapshot): Promise<void> {
    snapshot.accountId = accountId;
    snapshot.updatedAt = nowIso();
    const localOnly = MemoryAIConfigStore.stripRemoteOverlay(snapshot);
    this.byAccount.set(accountId, MemoryAIConfigStore.clone(localOnly));
  }

  async publishProOverlayMeta(
    accountId: number,
    remote: ProBootstrapSnapshot,
    etag?: string
  ): Promise<void> {
    let snap = this.byAccount.get(accountId);
    if (!snap) {
      snap = new AIConfigSnapshot();
      snap.accountId = accountId;
      snap.schemaVersion = 1;
      snap.source = 'local';
      snap.preferences = new AIUserPreferences();
    }
    const cleaned = MemoryAIConfigStore.stripRemoteOverlay(snap);
    cleaned.revision = remote.revision;
    cleaned.remoteEtag = etag;
    cleaned.syncState = 'remoteReady';
    cleaned.source = 'local';
    cleaned.updatedAt = nowIso();
    this.byAccount.set(accountId, MemoryAIConfigStore.clone(cleaned));
  }

  async deleteAccount(accountId: number): Promise<void> {
    this.byAccount.delete(accountId);
  }

  async updateSyncState(accountId: number, state: string, extra?: Record<string, string>): Promise<void> {
    const snap = this.byAccount.get(accountId);
    if (!snap) {
      return;
    }
    if (state === 'localReady' || state === 'remoteReady' || state === 'degraded' || state === 'refreshing' ||
      state === 'empty' || state === 'invalidated' || state === 'draft' || state === 'seeding' ||
      state === 'uninitialized') {
      snap.syncState = state;
    }
    if (extra) {
      if (extra['remote_revision']) {
        snap.revision = extra['remote_revision'];
      }
      if (extra['remote_etag']) {
        snap.remoteEtag = extra['remote_etag'];
      }
    }
    snap.updatedAt = nowIso();
  }

  private static stripRemoteOverlay(src: AIConfigSnapshot): AIConfigSnapshot {
    const out = MemoryAIConfigStore.clone(src);
    out.providers = out.providers.filter(
      (p) => ProOverlayMaterializer.isLocalCatalogSource(p.source, p.id)
    );
    out.models = out.models.filter(
      (m) => ProOverlayMaterializer.isLocalCatalogSource(m.source, m.id)
    );
    out.scenarioBindings = out.scenarioBindings.filter(
      (b) => !ProOverlayMaterializer.isRemoteOverlaySource(b.source)
    );
    out.smallTasks = out.smallTasks.filter(
      (t) => t.source !== 'pro' && t.source !== 'Service' && t.source !== 'trial'
    );
    return out;
  }

  private static cloneLocalOnly(src: AIConfigSnapshot): AIConfigSnapshot {
    return MemoryAIConfigStore.stripRemoteOverlay(src);
  }

  private static clone(src: AIConfigSnapshot): AIConfigSnapshot {
    return hydrateSnapshot(JSON.parse(JSON.stringify(src)) as AIConfigSnapshot);
  }
}

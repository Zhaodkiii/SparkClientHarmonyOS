import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { AIConfigAPI } from '../../../Projects/Core/Networking/API/AI/AIConfigAPI';
import {
  AIConfigSnapshot,
  RefreshResult,
  RuntimeSnapshot,
  SeedResult,
  nowIso,
  normalizeProviderId,
  ProBootstrapSnapshot
} from '../Domain/AIConfigModels';
import { AIConfigResolver, ResolveOptions } from './AIConfigResolver';
import { ProOverlayMaterializer } from './ProOverlayMaterializer';
import { AIConfigStore } from '../Infrastructure/AIConfigStore';
import { AIKeyStore } from '../Infrastructure/AIKeyStore';
import { AIConfigSeedLoader, AISeedValidationError } from '../Infrastructure/AIConfigSeedLoader';
import { AIConfigSchema } from '../Infrastructure/AIConfigSchema';
import { AISettingsKVAdapter } from '../Infrastructure/AISettingsKVAdapter';
import { AIConfigFlowLog } from '../Infrastructure/AIConfigFlowLog';
import { ProOverlayStore } from '../Infrastructure/ProOverlayStore';
import { AIRuntimeSnapshotStore } from '../Runtime/AIRuntimeSnapshotStore';
import { AccountSessionRuntime } from '../../../App/AccountSessionRuntime';
import { SupportNetworkError } from '../../../Projects/Core/Networking/SupportNetworkModels';
import { ErrorLogger } from '../../../Foundation/Logging/ErrorLogger';
import { publishAiRuntimeReady } from '../../../App/AppStartupKeys';
import { LogModule } from '../../../Foundation/Logging/LogModule';

export class AISeedLoadError extends Error {
  code: string = '';

  constructor(code: string, message?: string) {
    super(message ?? `seed:${code}`);
    this.code = code;
    this.name = 'AISeedLoadError';
  }
}

/** 单测注入：覆盖 api.bootstrap，避免真实网络 */
export interface AIBootstrapTestOverride {
  bootstrap(clientVersion: string): Promise<ProBootstrapSnapshot>;
}

export class AIConfigRepository {
  private readonly store: AIConfigStore;
  private readonly keys: AIKeyStore;
  private readonly api: AIConfigAPI;
  private readonly resolver: AIConfigResolver;
  private readonly runtimeStore: AIRuntimeSnapshotStore;
  private readonly proOverlayStore: ProOverlayStore;
  private readonly session: AccountSessionRuntime;
  private readonly kv: AISettingsKVAdapter;
  private readonly context?: common.Context;
  private seedCache?: SeedJsonCache;
  private readonly seedInFlight: Map<number, Promise<SeedResult>> = new Map();
  private runtimeGeneration: number = 0;
  private bootstrapOverride?: AIBootstrapTestOverride;

  constructor(
    store: AIConfigStore,
    keys: AIKeyStore,
    api: AIConfigAPI,
    resolver: AIConfigResolver,
    runtimeStore: AIRuntimeSnapshotStore,
    session: AccountSessionRuntime,
    kv?: AISettingsKVAdapter,
    context?: common.Context,
    proOverlayStore?: ProOverlayStore
  ) {
    this.store = store;
    this.keys = keys;
    this.api = api;
    this.resolver = resolver;
    this.runtimeStore = runtimeStore;
    this.proOverlayStore = proOverlayStore ?? new ProOverlayStore();
    this.session = session;
    this.kv = kv ?? new AISettingsKVAdapter();
    this.context = context;
  }

  /** 测试注入种子 JSON，避免依赖 rawfile。 */
  setSeedJsonCache(cache: SeedJsonCache): void {
    this.seedCache = cache;
  }

  /** 测试注入 bootstrap 结果。 */
  setBootstrapOverride(override: AIBootstrapTestOverride): void {
    this.bootstrapOverride = override;
  }

  private assertAccount(accountId: number): void {
    const active = this.session.activeAccountId;
    // 启动准备阶段允许 active 尚未发布时写入当前账号
    if (active !== undefined && active > 0 && active !== accountId) {
      throw new Error(`AIConfigRepository: account mismatch active=${active} requested=${accountId}`);
    }
  }

  async loadSnapshot(accountId: number): Promise<AIConfigSnapshot> {
    this.assertAccount(accountId);
    // 步骤：从 RDB 读取账号级本地密钥目录（不含 Pro overlay）
    AIConfigFlowLog.info('ai.db.load.begin', `开始从数据库读取 AI 配置 accountId=${accountId}`);
    const loaded = await this.loadSnapshotQuiet(accountId);
    if (loaded.syncState === 'empty' && (loaded.seedVersion === undefined || loaded.seedVersion === 0) &&
      loaded.providers.length === 0) {
      AIConfigFlowLog.warn('ai.db.load.empty', `数据库无该账号 AI 元数据 accountId=${accountId}`);
    } else {
      AIConfigFlowLog.info(
        'ai.db.load.ok',
        `数据库读取成功 ${AIConfigFlowLog.catalogReadSummary(
          accountId,
          loaded.providers.length,
          loaded.models.length,
          loaded.scenarioBindings.length,
          loaded.smallTasks.length,
          loaded.modelFiles.length,
          `seed=${loaded.seedVersion ?? 0} sync=${loaded.syncState} revision=${loaded.revision ?? '-'}`
        )}`
      );
      AIConfigFlowLog.info(
        'ai.provider_catalog.local.ok',
        `本地密钥目录 seed/custom count=${loaded.providers.length} models=${loaded.models.length} ` +
          `厂商=${AIConfigFlowLog.providersBrief(loaded.providers, 8)}`
      );
    }
    return loaded;
  }

  /** 无日志的内部读取，供 Runtime 构建复用，避免重复刷屏 */
  private async loadSnapshotQuiet(accountId: number): Promise<AIConfigSnapshot> {
    const loaded = await this.store.load(accountId);
    if (loaded) {
      return loaded;
    }
    const empty = new AIConfigSnapshot();
    empty.accountId = accountId;
    empty.syncState = 'empty';
    empty.updatedAt = nowIso();
    return empty;
  }

  async ensureSeeded(accountId: number): Promise<SeedResult> {
    this.assertAccount(accountId);
    const inflight = this.seedInFlight.get(accountId);
    if (inflight) {
      AIConfigFlowLog.info('ai.seed.inflight', `种子灌库进行中，复用同一任务 accountId=${accountId}`);
      return inflight;
    }
    const task = this.ensureSeededInternal(accountId).finally(() => {
      this.seedInFlight.delete(accountId);
    });
    this.seedInFlight.set(accountId, task);
    return task;
  }

  private async ensureSeededInternal(accountId: number): Promise<SeedResult> {
    AIConfigFlowLog.info('ai.seed.begin', `首次登录种子流程开始 accountId=${accountId}`);
    const existing = await this.store.load(accountId);
    const result = new SeedResult();
    if (existing && existing.seedVersion !== undefined && existing.seedVersion > 0) {
      result.status = 'alreadySeeded';
      result.seedVersion = existing.seedVersion;
      AIConfigFlowLog.info(
        'ai.seed.skip',
        `非首次启动，跳过 JSON 导入 ${AIConfigFlowLog.snapshotSummary(existing)}`
      );
      return result;
    }

    await this.store.updateSyncState(accountId, 'seeding').catch(() => {
      // meta 可能尚不存在；忽略
    });

    const seedJson = await this.loadSeedJson();
    let snap: AIConfigSnapshot;
    if (seedJson.iosSource) {
      AIConfigFlowLog.info('ai.seed.parse.begin', '开始解析 iOS APIKeys.json / AllModels.json');
      snap = AIConfigSeedLoader.parseIOSSourceBundle(
        seedJson.apiKeysJson,
        seedJson.allModelsJson,
        accountId
      );
      const tasksPrefs = AIConfigSeedLoader.parseSeedBundle(
        '[]', '[]', '[]', seedJson.tasks, seedJson.prefs, accountId
      );
      snap.smallTasks = tasksPrefs.smallTasks;
      snap.preferences = tasksPrefs.preferences;
      AIConfigFlowLog.info(
        'ai.seed.parse.ok',
        `JSON 解析完成 ${AIConfigFlowLog.snapshotSummary(snap)} ` +
          `厂商=${AIConfigFlowLog.providersBrief(snap.providers)} ` +
          `模型=${AIConfigFlowLog.modelsBrief(snap.models)}`
      );
    } else {
      AIConfigFlowLog.info('ai.seed.parse.fixture', '使用测试注入的规范化种子 JSON');
      snap = AIConfigSeedLoader.parseSeedBundle(
        seedJson.providers,
        seedJson.models,
        seedJson.bindings,
        seedJson.tasks,
        seedJson.prefs,
        accountId
      );
    }
    snap.seedVersion = AIConfigSchema.SEED_VERSION;
    snap.syncState = 'localReady';
    snap.accountId = accountId;

    AIConfigFlowLog.info('ai.seed.db_write.begin', `开始写入数据库 accountId=${accountId}`);
    await this.store.saveLocal(accountId, snap);
    result.status = 'seeded';
    result.seedVersion = AIConfigSchema.SEED_VERSION;
    AIConfigFlowLog.info(
      'ai.seed.ok',
      `首次登录 JSON→数据库完成 ${AIConfigFlowLog.snapshotSummary(snap)}`
    );
    return result;
  }

  async save(accountId: number, snapshot: AIConfigSnapshot): Promise<void> {
    this.assertAccount(accountId);
    snapshot.accountId = accountId;
    snapshot.updatedAt = nowIso();
    snapshot.syncState = 'localReady';
    // 对标 iOS DefaultAISettingsRepository.save「写链路」
    AIConfigFlowLog.infoParts('ai.save.begin', [
      `AI save 写链路开始 ${AIConfigFlowLog.catalogWriteSummary(
        accountId,
        snapshot.providers.length,
        snapshot.models.length,
        snapshot.scenarioBindings.length,
        snapshot.smallTasks.length,
        snapshot.modelFiles.length,
        `sync=${snapshot.syncState} revision=${snapshot.revision ?? '-'}`
      )}`,
      snapshot.providers.length > 0
        ? `厂商摘要=${AIConfigFlowLog.providersBrief(snapshot.providers, 8)}`
        : ''
    ]);
    await this.store.saveLocal(accountId, snapshot);
    let kvMirrored = true;
    try {
      await this.kv.mirrorPreferences(
        accountId,
        JSON.stringify({
          'defaultSource': snapshot.preferences.defaultSource,
          'allowNetwork': snapshot.preferences.allowNetwork,
          'allowLocalModel': snapshot.preferences.allowLocalModel
        })
      );
    } catch (_e) {
      this.kv.kvMirrorPending = true;
      kvMirrored = false;
    }
    AIConfigFlowLog.info(
      'ai.save.ok',
      `AI save 写链路完成 accountId=${accountId} ` +
        `厂商行=${snapshot.providers.length} 模型行=${snapshot.models.length} ` +
        `绑定行=${snapshot.scenarioBindings.length} 小任务行=${snapshot.smallTasks.length} ` +
        `文件行=${snapshot.modelFiles.length}；偏好KV=${kvMirrored ? '已镜像' : 'pending'}；即将重建 Runtime`
    );
    await this.buildRuntime(accountId);
  }

  async saveDraft(accountId: number, draft: AIConfigSnapshot): Promise<void> {
    this.assertAccount(accountId);
    const merged = this.mergeWithProOverlay(accountId, draft);
    const runtime = this.resolver.buildRuntime(merged);
    runtime.runtimeSource = 'draft';
    runtime.state = 'draft';
    this.runtimeGeneration += 1;
    runtime.generation = this.runtimeGeneration;
    this.runtimeStore.publish(runtime);
    // 对标 iOS AIConfigCenter.applyDraftSnapshot
    AIConfigFlowLog.debug(
      'ai.draft.apply',
      `AI 运行时草稿快照已应用 accountId=${accountId} gen=${runtime.generation} ` +
        `providers=${merged.providers.length} models=${merged.models.length} ` +
        `bindings=${merged.scenarioBindings.length} tasks=${merged.smallTasks.length}`
    );
  }

  async deleteAccountData(accountId: number): Promise<void> {
    AIConfigFlowLog.info('ai.account.clear.begin', `清理账号 AI 数据 accountId=${accountId}`);
    await this.runtimeStore.clear(accountId);
    this.proOverlayStore.clear(accountId);
    await this.keys.deleteAccount(accountId);
    await this.store.deleteAccount(accountId);
    publishAiRuntimeReady(false, accountId);
    AIConfigFlowLog.info('ai.account.clear.ok', `账号 AI 数据已清理 accountId=${accountId}`);
  }

  /** 返回物化后的 Pro overlay 片段（仅 Pro 行），供模型页只读展示 */
  async loadProOverlay(accountId: number): Promise<AIConfigSnapshot | undefined> {
    this.assertAccount(accountId);
    const entry = this.proOverlayStore.get(accountId);
    if (!entry) {
      return undefined;
    }
    return ProOverlayMaterializer.materialize(accountId, entry.remote, entry.secretRefs);
  }

  currentProOverlayRevision(accountId: number): string | undefined {
    return this.proOverlayStore.get(accountId)?.remote.revision;
  }

  async refreshRemote(accountId: number, clientVersion: string = '1.0.0'): Promise<RefreshResult> {
    this.assertAccount(accountId);
    const result = new RefreshResult();
    const local = await this.store.load(accountId);
    AIConfigFlowLog.info(
      'ai.pro_overlay.refresh.begin',
      `开始 Pro bootstrap 刷新 accountId=${accountId} clientVersion=${clientVersion} ` +
        `localRev=${local?.revision ?? '-'}`
    );
    if (local && local.preferences.allowNetwork === false) {
      result.state = 'localReady';
      result.reason = 'network_disabled';
      AIConfigFlowLog.info('ai.pro.refresh.skip', '用户关闭网络，跳过 Pro 刷新');
      await this.buildRuntime(accountId);
      return result;
    }
    try {
      await this.store.updateSyncState(accountId, 'refreshing');
      const remote = this.bootstrapOverride
        ? await this.bootstrapOverride.bootstrap(clientVersion)
        : await this.api.bootstrap(clientVersion);

      if (AIConfigRepository.isEmptyRemotePayload(remote)) {
        AIConfigFlowLog.warn('ai.pro.refresh.empty', `远端 payload 为空，保留本地配置 accountId=${accountId}`);
        await this.store.updateSyncState(accountId, 'degraded');
        result.state = 'degraded';
        result.reason = 'empty_remote_payload';
        await this.buildRuntime(accountId);
        return result;
      }

      if (local && local.revision && local.revision.length > 0) {
        const cmp = AIConfigRepository.compareRevision(remote.revision, local.revision);
        if (cmp < 0) {
          AIConfigFlowLog.warn(
            'ai.pro.refresh.older',
            `拒绝更旧 revision remote=${remote.revision} local=${local.revision}`
          );
          result.state = 'degraded';
          result.reason = 'older_revision';
          result.revision = local.revision;
          await this.store.updateSyncState(accountId, 'degraded');
          await this.buildRuntime(accountId);
          return result;
        }
        if (cmp === 0) {
          const secretRefs = await this.collectProSecretRefs(accountId, remote);
          this.proOverlayStore.set(accountId, remote, secretRefs, remote.etag);
          AIConfigFlowLog.info(
            'ai.pro_overlay.refresh.ok',
            `revision 未变，已刷新内存 overlay revision=${remote.revision} scenarios=${remote.scenarios.length}`
          );
          result.state = 'remoteReady';
          result.reason = 'revision_unchanged';
          result.revision = remote.revision;
          await this.buildRuntime(accountId, remote.trialStatus?.isActive === true);
          return result;
        }
      }

      const secretRefs = new Map<string, string>();
      try {
        for (let si = 0; si < remote.scenarios.length; si++) {
          const bundle = remote.scenarios[si];
          for (let mi = 0; mi < bundle.models.length; mi++) {
            const row = bundle.models[mi];
            const company = row.company || 'PRO';
            const providerId = `pro:${normalizeProviderId(company)}`;
            if (row.apiKey && row.apiKey.length > 0) {
              const ref = await this.keys.putPro(accountId, providerId, row.apiKey);
              secretRefs.set(providerId, ref);
              row.apiKey = undefined;
            } else if (!secretRefs.has(providerId)) {
              secretRefs.set(providerId, this.keys.makeProSecretRef(accountId, providerId));
            }
          }
        }
        this.proOverlayStore.set(accountId, remote, secretRefs, remote.etag);
        await this.store.publishProOverlayMeta(accountId, remote, remote.etag);
        result.state = 'remoteReady';
        result.revision = remote.revision;
        result.snapshot = remote;
        await this.buildRuntime(accountId, remote.trialStatus?.isActive === true);
        let modelCount = 0;
        for (let i = 0; i < remote.scenarios.length; i++) {
          modelCount += remote.scenarios[i].models.length;
        }
        AIConfigFlowLog.info(
          'ai.pro_overlay.refresh.ok',
          `Pro overlay 刷新成功 accountId=${accountId} revision=${remote.revision} ` +
            `scenarios=${remote.scenarios.length} models=${modelCount}`
        );
        AIConfigFlowLog.info(
          'ai.pro_overlay.not_persisted_to_local_catalog',
          `Pro providers=${secretRefs.size} destination=memory_overlay`
        );
        return result;
      } finally {
        AIConfigRepository.clearRemoteApiKeys(remote);
      }
    } catch (err) {
      if (err instanceof SupportNetworkError) {
        if (err.statusCode === 401 || (err.backend && err.backend.code >= 40100 && err.backend.code <= 40199)) {
          result.state = 'invalidated';
          result.reason = 'auth_invalidated';
          this.runtimeStore.invalidate(accountId);
          this.proOverlayStore.clear(accountId);
          publishAiRuntimeReady(false, accountId);
          AIConfigFlowLog.warn('ai.pro.refresh.auth', `Pro 刷新鉴权失效 accountId=${accountId}`);
          return result;
        }
      }
      ErrorLogger.log('ai.refresh_degraded', LogModule.AI_CONFIG, err as Object);
      await this.store.updateSyncState(accountId, 'degraded');
      result.state = 'degraded';
      result.reason = `${err}`;
      AIConfigFlowLog.warn('ai.pro.refresh.degraded', `Pro 刷新降级，保留本地 Runtime accountId=${accountId} err=${err}`);
      await this.buildRuntime(accountId);
      return result;
    }
  }

  private async collectProSecretRefs(
    accountId: number,
    remote: ProBootstrapSnapshot
  ): Promise<Map<string, string>> {
    const secretRefs = new Map<string, string>();
    const existing = this.proOverlayStore.get(accountId);
    for (let si = 0; si < remote.scenarios.length; si++) {
      const bundle = remote.scenarios[si];
      for (let mi = 0; mi < bundle.models.length; mi++) {
        const row = bundle.models[mi];
        const company = row.company || 'PRO';
        const providerId = `pro:${normalizeProviderId(company)}`;
        if (row.apiKey && row.apiKey.length > 0) {
          const ref = await this.keys.putPro(accountId, providerId, row.apiKey);
          secretRefs.set(providerId, ref);
          row.apiKey = undefined;
        } else if (existing?.secretRefs.has(providerId)) {
          secretRefs.set(providerId, existing.secretRefs.get(providerId)!);
        } else {
          secretRefs.set(providerId, this.keys.makeProSecretRef(accountId, providerId));
        }
      }
    }
    return secretRefs;
  }

  private mergeWithProOverlay(accountId: number, local: AIConfigSnapshot): AIConfigSnapshot {
    const entry = this.proOverlayStore.get(accountId);
    if (!entry) {
      return local;
    }
    const fragment = ProOverlayMaterializer.materialize(accountId, entry.remote, entry.secretRefs);
    return ProOverlayMaterializer.merge(local, fragment);
  }

  async buildRuntime(accountId: number, trialActive: boolean = false): Promise<RuntimeSnapshot> {
    this.assertAccount(accountId);
    AIConfigFlowLog.info(
      'ai.runtime.build.begin',
      `开始从数据库加载并构建 Runtime 缓存 accountId=${accountId} trial=${trialActive}`
    );
    const local = await this.loadSnapshotQuiet(accountId);
    const hasOverlay = this.proOverlayStore.has(accountId);
    const merged = this.mergeWithProOverlay(accountId, local);
    // 对标 iOS prewarm / reloadLocalSnapshot：分段输出，避免单行被 200 字截断
    AIConfigFlowLog.infoParts('ai.runtime.db_snapshot', [
      `已读取库内快照 ${AIConfigFlowLog.snapshotSummary(local)}`,
      `合并后 mergedProviders=${merged.providers.length} mergedModels=${merged.models.length} ` +
        `mergedBindings=${merged.scenarioBindings.length} mergedTasks=${merged.smallTasks.length} ` +
        `overlay=${hasOverlay ? 'yes' : 'no'}`,
      local.providers.length > 0
        ? `本地厂商=${AIConfigFlowLog.providersBrief(local.providers, 8)}`
        : ''
    ]);
    const opts = new ResolveOptions();
    opts.trialActive = trialActive;
    const runtime = this.resolver.buildRuntime(merged, opts);
    this.runtimeGeneration += 1;
    runtime.generation = this.runtimeGeneration;
    this.runtimeStore.publish(runtime);
    const ready = local.seedVersion !== undefined && local.seedVersion > 0 &&
      (runtime.state === 'localReady' || runtime.state === 'remoteReady' || runtime.state === 'degraded');
    publishAiRuntimeReady(ready, accountId);
    let defaultsNote = '';
    if (runtime.effectiveDefaults.size === 0 && runtime.state === 'localReady') {
      defaultsNote = ' note=defaults0_expected_seed_providers_disabled';
    }
    AIConfigFlowLog.infoParts('ai.runtime.build.ok', [
      `Runtime 已写入内存缓存 ready=${ready} ${AIConfigFlowLog.runtimeSummary(runtime)}${defaultsNote}`,
      `来源 localProviders=${local.providers.length} localModels=${local.models.length} ` +
        `overlay=${hasOverlay ? 'yes' : 'no'} trial=${trialActive}`
    ]);
    return runtime;
  }

  currentRuntime(accountId: number): RuntimeSnapshot | undefined {
    return this.runtimeStore.get(accountId);
  }

  private async loadSeedJson(): Promise<SeedJsonCache> {
    if (this.seedCache) {
      AIConfigFlowLog.debug('ai.seed.rawfile.cache', '使用内存中的种子 JSON 缓存');
      return this.seedCache;
    }
    if (!this.context) {
      throw new AISeedLoadError('missing_context', '生产环境缺少 Context，无法读取 seed rawfile');
    }
    const cache = new SeedJsonCache();
    const apiKeysPath = 'ai/source/AISettings/APIKeys.json';
    const allModelsPath = 'ai/source/AISettings/AllModels.json';
    try {
      AIConfigFlowLog.info('ai.seed.rawfile.begin', `读取 rawfile: ${apiKeysPath} , ${allModelsPath}`);
      cache.apiKeysJson = await this.readRawfileUtf8(apiKeysPath);
      cache.allModelsJson = await this.readRawfileUtf8(allModelsPath);
      cache.iosSource = true;
      AIConfigFlowLog.info(
        'ai.seed.rawfile.ok',
        `rawfile 读取成功 APIKeys=${cache.apiKeysJson.length}B AllModels=${cache.allModelsJson.length}B`
      );
    } catch (err) {
      if (err instanceof AISeedLoadError) {
        throw new AISeedLoadError(err.code, err.message);
      }
      if (err instanceof AISeedValidationError) {
        throw new AISeedValidationError(err.code, err.detail);
      }
      throw new AISeedLoadError('rawfile_read_failed', `path=${apiKeysPath}|${allModelsPath} err=${err}`);
    }
    try {
      cache.tasks = await this.readRawfileUtf8('ai/small_tasks.json');
    } catch (_e) {
      cache.tasks = '[]';
      AIConfigFlowLog.debug('ai.seed.rawfile.tasks_default', 'small_tasks.json 缺失，使用空列表');
    }
    try {
      cache.prefs = await this.readRawfileUtf8('ai/preferences.json');
    } catch (_e) {
      cache.prefs = '{"defaultSource":"auto","allowNetwork":true,"allowLocalModel":true}';
      AIConfigFlowLog.debug('ai.seed.rawfile.prefs_default', 'preferences.json 缺失，使用默认偏好');
    }
    this.seedCache = cache;
    return cache;
  }

  private async readRawfileUtf8(path: string): Promise<string> {
    const rm = this.context!.resourceManager;
    const data = await rm.getRawFileContent(path);
    const bytes = data as Uint8Array;
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    const text = decoder.decodeWithStream(bytes);
    if (!text || text.length === 0) {
      throw new AISeedLoadError('rawfile_empty', path);
    }
    return text;
  }

  static compareRevision(incoming: string, current: string): number {
    const a = Number(incoming);
    const b = Number(current);
    if (!Number.isNaN(a) && !Number.isNaN(b)) {
      if (a === b) {
        return 0;
      }
      return a > b ? 1 : -1;
    }
    if (incoming === current) {
      return 0;
    }
    return incoming > current ? 1 : -1;
  }

  static isEmptyRemotePayload(remote: ProBootstrapSnapshot): boolean {
    if (!remote) {
      return true;
    }
    if (remote.scenarios.length === 0) {
      return true;
    }
    let modelCount = 0;
    for (let i = 0; i < remote.scenarios.length; i++) {
      modelCount += remote.scenarios[i].models.length;
    }
    return modelCount === 0;
  }

  static clearRemoteApiKeys(remote: ProBootstrapSnapshot): void {
    for (let si = 0; si < remote.scenarios.length; si++) {
      const models = remote.scenarios[si].models;
      for (let mi = 0; mi < models.length; mi++) {
        models[mi].apiKey = undefined;
      }
    }
  }
}

/**
 * 种子缓存。生产走 iOS 源文件；测试可注入规范化 providers/models/bindings。
 */
export class SeedJsonCache {
  iosSource: boolean = false;
  apiKeysJson: string = '[]';
  allModelsJson: string = '[]';
  providers: string = '[]';
  models: string = '[]';
  bindings: string = '[]';
  tasks: string = '[]';
  prefs: string = '{"defaultSource":"auto","allowNetwork":true,"allowLocalModel":true}';

  static fromIOSSource(apiKeys: string, allModels: string, tasks: string = '[]', prefs?: string): SeedJsonCache {
    const c = new SeedJsonCache();
    c.iosSource = true;
    c.apiKeysJson = apiKeys;
    c.allModelsJson = allModels;
    c.tasks = tasks;
    if (prefs) {
      c.prefs = prefs;
    }
    return c;
  }
}

import { relationalStore } from '@kit.ArkData';
import { AppRelationalDatabase } from '../../Storage/AppRelationalDatabase';
import {
  AIConfigSnapshot,
  AIUserPreferences,
  AIDefaultSource,
  LocalModel,
  LocalModelFile,
  LocalProvider,
  LocalScenarioBinding,
  LocalSmallTask,
  ModelCapabilities,
  AISyncState,
  AIModelFileState,
  nowIso,
  ProBootstrapSnapshot
} from '../Domain/AIConfigModels';
import { AIConfigStore } from './AIConfigStore';
import { AIConfigFlowLog } from './AIConfigFlowLog';
import { ProOverlayMaterializer } from '../Application/ProOverlayMaterializer';

class AIConfigPreferencesExtras {
  scenarioSources: Record<string, AIDefaultSource> = {};
}

/**
 * 基于 spark_client.db 的 AI 表 CRUD；写操作走 AppRdbWriteQueue。
 * 负责：首次 seed 落库、日常读库（仅本地密钥目录）、Pro overlay 元数据与遗留 Pro 行清理。
 */
export class AIConfigRdbStore extends AIConfigStore {
  private readonly database: AppRelationalDatabase;

  constructor(database: AppRelationalDatabase) {
    super();
    this.database = database;
  }

  async load(accountId: number): Promise<AIConfigSnapshot | undefined> {
    // 按账号读取 meta + 本地 provider/model/binding/task/prefs（排除 Pro overlay 行）
    const db = await this.database.open();
    const metaRs = await db.querySql(
      'SELECT * FROM ai_account_meta WHERE account_id = ?',
      [accountId]
    );
    try {
      if (!metaRs.goToFirstRow()) {
        AIConfigFlowLog.debug('ai.rdb.meta_miss', `ai_account_meta 无行 accountId=${accountId}`);
        return undefined;
      }
      const snap = new AIConfigSnapshot();
      snap.accountId = accountId;
      snap.schemaVersion = metaRs.getLong(metaRs.getColumnIndex('schema_version'));
      snap.seedVersion = AIConfigRdbStore.optLong(metaRs, 'seed_version');
      snap.revision = AIConfigRdbStore.optStr(metaRs, 'remote_revision');
      snap.remoteEtag = AIConfigRdbStore.optStr(metaRs, 'remote_etag');
      snap.syncState = AIConfigRdbStore.syncState(AIConfigRdbStore.str(metaRs, 'sync_state'));
      snap.updatedAt = AIConfigRdbStore.str(metaRs, 'updated_at');
      snap.source = 'local';
      const allProviders = await this.loadProviders(db, accountId);
      const allModels = await this.loadModels(db, accountId);
      const allBindings = await this.loadBindings(db, accountId);
      const allTasks = await this.loadTasks(db, accountId);
      const legacyPro = allProviders.filter(
        (p) => ProOverlayMaterializer.isRemoteOverlaySource(p.source, p.id)
      ).length;
      snap.providers = allProviders.filter(
        (p) => ProOverlayMaterializer.isLocalCatalogSource(p.source, p.id)
      );
      snap.models = allModels.filter(
        (m) => ProOverlayMaterializer.isLocalCatalogSource(m.source, m.id)
      );
      snap.scenarioBindings = allBindings.filter(
        (b) => !ProOverlayMaterializer.isRemoteOverlaySource(b.source)
      );
      snap.smallTasks = allTasks.filter(
        (t) => t.source !== 'pro' && t.source !== 'Service' && t.source !== 'trial'
      );
      snap.modelFiles = await this.loadFiles(db, accountId);
      snap.preferences = await this.loadPrefs(db, accountId);
      if (legacyPro > 0) {
        AIConfigFlowLog.warn(
          'ai.provider_catalog.source_mismatch',
          `load 发现遗留 Pro 行 count=${legacyPro}，已从本地目录视图过滤 accountId=${accountId}`
        );
      }
      // 对标 iOS loadSnapshot 读链路完成：厂商/模型/绑定/小任务 + 偏好来源提示
      AIConfigFlowLog.debug(
        'ai.rdb.load.rows',
        `RDB 读链路完成 ${AIConfigFlowLog.catalogReadSummary(
          accountId,
          snap.providers.length,
          snap.models.length,
          snap.scenarioBindings.length,
          snap.smallTasks.length,
          snap.modelFiles.length,
          `seed=${snap.seedVersion ?? 0} sync=${snap.syncState} revision=${snap.revision ?? '-'} ` +
            `legacyProFiltered=${legacyPro} prefs=RDB`
        )}`
      );
      return snap;
    } finally {
      metaRs.close();
    }
  }

  async saveLocal(accountId: number, snapshot: AIConfigSnapshot): Promise<void> {
    const localProviders = snapshot.providers.filter(
      (p) => ProOverlayMaterializer.isLocalCatalogSource(p.source, p.id)
    );
    const localModels = snapshot.models.filter(
      (m) => ProOverlayMaterializer.isLocalCatalogSource(m.source, m.id)
    );
    const localBindings = snapshot.scenarioBindings.filter(
      (b) => !ProOverlayMaterializer.isRemoteOverlaySource(b.source)
    );
    const localTasks = snapshot.smallTasks.filter(
      (t) => t.source !== 'pro' && t.source !== 'Service' && t.source !== 'trial'
    );
    const filteredOutProviders = snapshot.providers.length - localProviders.length;
    const filteredOutModels = snapshot.models.length - localModels.length;
    const metaExtras =
      `sync=${snapshot.syncState || 'localReady'} seed=${snapshot.seedVersion ?? 0} ` +
      `revision=${snapshot.revision ?? '-'} ` +
      `filteredProProviders=${filteredOutProviders} filteredProModels=${filteredOutModels}`;
    // 对标 iOS「AI save 写链路」：完整目录计数，不只 providers/models
    AIConfigFlowLog.info(
      'ai.rdb.save.begin',
      `RDB 写链路开始 ${AIConfigFlowLog.catalogWriteSummary(
        accountId,
        localProviders.length,
        localModels.length,
        localBindings.length,
        localTasks.length,
        snapshot.modelFiles.length,
        metaExtras
      )}`
    );
    const saveStartedAt = Date.now();
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      const ts = nowIso();
      db.beginTransaction();
      try {
        await db.executeSql(
          `INSERT OR REPLACE INTO ai_account_meta
           (account_id, schema_version, seed_version, seeded_at, remote_revision, remote_etag,
            last_remote_sync_at, sync_state, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, COALESCE((SELECT created_at FROM ai_account_meta WHERE account_id=?), ?), ?)`,
          [
            accountId,
            snapshot.schemaVersion,
            snapshot.seedVersion ?? null,
            snapshot.seedVersion ? ts : null,
            snapshot.revision ?? null,
            snapshot.remoteEtag ?? null,
            null,
            snapshot.syncState || 'localReady',
            accountId,
            ts,
            ts
          ]
        );
        // 全量替换本地目录；同时清掉遗留 Pro/trial/Service 行
        await db.executeSql('DELETE FROM ai_scenario_binding WHERE account_id = ?', [accountId]);
        await db.executeSql('DELETE FROM ai_model WHERE account_id = ?', [accountId]);
        await db.executeSql('DELETE FROM ai_provider WHERE account_id = ?', [accountId]);
        await db.executeSql('DELETE FROM ai_small_task WHERE account_id = ?', [accountId]);
        await this.insertProviders(db, accountId, localProviders);
        await this.insertModels(db, accountId, localModels);
        await this.insertBindings(db, accountId, localBindings);
        await this.insertTasks(db, accountId, localTasks);
        await this.insertFiles(db, accountId, snapshot.modelFiles);
        await this.insertPrefs(db, accountId, snapshot.preferences);
        db.commit();
        const elapsedMs = Date.now() - saveStartedAt;
        AIConfigFlowLog.infoParts('ai.rdb.save.ok', [
          `RDB 写链路完成 ${AIConfigFlowLog.catalogWriteSummary(
            accountId,
            localProviders.length,
            localModels.length,
            localBindings.length,
            localTasks.length,
            snapshot.modelFiles.length,
            `耗时=${elapsedMs}ms 偏好已写入RDB`
          )}`,
          localProviders.length > 0
            ? `厂商摘要=${AIConfigFlowLog.providersBrief(localProviders, 8)}`
            : '',
          localTasks.length > 0
            ? `小任务=${AIConfigFlowLog.tasksBrief(AIConfigRdbStore.taskCodes(localTasks), 10)}`
            : ''
        ]);
      } catch (err) {
        try {
          db.rollBack();
        } catch (_e) {
          // ignore
        }
        AIConfigFlowLog.warn(
          'ai.rdb.save.fail',
          `RDB 写链路回滚 accountId=${accountId} ` +
            `厂商行=${localProviders.length} 模型行=${localModels.length} err=${err}`
        );
        throw AIConfigRdbStore.toError(err as Object);
      }
    });
  }

  private static taskCodes(tasks: LocalSmallTask[]): string[] {
    const codes: string[] = [];
    for (let i = 0; i < tasks.length; i++) {
      codes.push(tasks[i].code);
    }
    return codes;
  }

  /**
   * 清理本地目录中的遗留 Pro 行，并写入 Pro revision/etag。
   * 不插入 Pro Provider/Model（对标 iOS：Pro 仅进内存 overlay）。
   */
  async publishProOverlayMeta(
    accountId: number,
    remote: ProBootstrapSnapshot,
    etag?: string
  ): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      const ts = nowIso();
      db.beginTransaction();
      try {
        const deleted = await this.purgeLegacyRemoteOverlayRows(db, accountId);
        await db.executeSql(
          `UPDATE ai_account_meta SET remote_revision = ?, remote_etag = ?, last_remote_sync_at = ?,
           sync_state = ?, updated_at = ? WHERE account_id = ?`,
          [remote.revision, etag ?? '', ts, 'remoteReady', ts, accountId]
        );
        db.commit();
        AIConfigFlowLog.info(
          'ai.pro_overlay.not_persisted_to_local_catalog',
          `Pro 仅更新 meta，不写本地目录 accountId=${accountId} revision=${remote.revision} ` +
            `scenarios=${remote.scenarios.length} purgedLegacy=${deleted}`
        );
      } catch (err) {
        try {
          db.rollBack();
        } catch (_e) {
          // ignore
        }
        throw AIConfigRdbStore.toError(err as Object);
      }
    });
  }

  /** 删除 source=pro/trial/Service 及 id 以 pro: 开头的遗留行 */
  private async purgeLegacyRemoteOverlayRows(
    db: relationalStore.RdbStore,
    accountId: number
  ): Promise<number> {
    const before = await db.querySql(
      `SELECT COUNT(1) AS c FROM ai_provider WHERE account_id = ?
       AND (source IN ('pro','trial','Service') OR id LIKE 'pro:%')`,
      [accountId]
    );
    let count = 0;
    try {
      if (before.goToFirstRow()) {
        count = before.getLong(before.getColumnIndex('c'));
      }
    } finally {
      before.close();
    }
    await db.executeSql(
      `DELETE FROM ai_scenario_binding WHERE account_id = ? AND source IN ('pro','trial','Service')`,
      [accountId]
    );
    await db.executeSql(
      `DELETE FROM ai_model WHERE account_id = ?
       AND (source IN ('pro','trial','Service') OR id LIKE 'pro:%')`,
      [accountId]
    );
    await db.executeSql(
      `DELETE FROM ai_provider WHERE account_id = ?
       AND (source IN ('pro','trial','Service') OR id LIKE 'pro:%')`,
      [accountId]
    );
    await db.executeSql(
      `DELETE FROM ai_small_task WHERE account_id = ? AND source IN ('pro','Service','trial')`,
      [accountId]
    );
    if (count > 0) {
      AIConfigFlowLog.info(
        'ai.provider_catalog.migration.ok',
        `已清理遗留 Pro 本地目录行 accountId=${accountId} deletedProviders=${count}`
      );
    }
    return count;
  }

  async deleteAccount(accountId: number): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql('DELETE FROM ai_account_meta WHERE account_id = ?', [accountId]);
    });
  }

  async updateSyncState(accountId: number, state: string, extra?: Record<string, string>): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      const ts = nowIso();
      await db.executeSql(
        'UPDATE ai_account_meta SET sync_state = ?, updated_at = ? WHERE account_id = ?',
        [state, ts, accountId]
      );
      if (extra && extra['remote_revision']) {
        await db.executeSql(
          'UPDATE ai_account_meta SET remote_revision = ? WHERE account_id = ?',
          [extra['remote_revision'], accountId]
        );
      }
      if (extra && extra['remote_etag']) {
        await db.executeSql(
          'UPDATE ai_account_meta SET remote_etag = ? WHERE account_id = ?',
          [extra['remote_etag'], accountId]
        );
      }
    });
  }

  private async loadProviders(db: relationalStore.RdbStore, accountId: number): Promise<LocalProvider[]> {
    const rs = await db.querySql('SELECT * FROM ai_provider WHERE account_id = ? ORDER BY position', [accountId]);
    const out: LocalProvider[] = [];
    try {
      let has = rs.goToFirstRow();
      while (has) {
        const p = new LocalProvider();
        p.id = AIConfigRdbStore.str(rs, 'id');
        p.name = AIConfigRdbStore.str(rs, 'name');
        p.company = AIConfigRdbStore.str(rs, 'company');
        p.kind = AIConfigRdbStore.str(rs, 'kind') === 'local' ? 'local' : 'api';
        p.requestUrl = AIConfigRdbStore.optStr(rs, 'request_url');
        p.secretRef = AIConfigRdbStore.optStr(rs, 'secret_ref');
        p.isEnabled = AIConfigRdbStore.str(rs, 'is_enabled') !== '0' && rs.getLong(rs.getColumnIndex('is_enabled')) !== 0;
        p.position = rs.getLong(rs.getColumnIndex('position'));
        p.source = AIConfigRdbStore.str(rs, 'source');
        p.updatedAt = AIConfigRdbStore.str(rs, 'updated_at');
        out.push(p);
        has = rs.goToNextRow();
      }
    } finally {
      rs.close();
    }
    return out;
  }

  private async loadModels(db: relationalStore.RdbStore, accountId: number): Promise<LocalModel[]> {
    const rs = await db.querySql('SELECT * FROM ai_model WHERE account_id = ?', [accountId]);
    const out: LocalModel[] = [];
    try {
      let has = rs.goToFirstRow();
      while (has) {
        const m = new LocalModel();
        m.id = AIConfigRdbStore.str(rs, 'id');
        m.providerId = AIConfigRdbStore.str(rs, 'provider_id');
        m.name = AIConfigRdbStore.str(rs, 'name');
        m.displayName = AIConfigRdbStore.str(rs, 'display_name');
        m.baseModelName = AIConfigRdbStore.optStr(rs, 'base_model_name');
        m.modelType = AIConfigRdbStore.str(rs, 'model_type') === 'gguf' ? 'gguf' : 'remote';
        m.capabilities = ModelCapabilities.fromJson(AIConfigRdbStore.str(rs, 'capabilities_json'));
        const cw = AIConfigRdbStore.optLong(rs, 'context_window');
        if (cw !== undefined) {
          m.contextWindow = cw;
        }
        m.priceTier = AIConfigRdbStore.optStr(rs, 'price_tier');
        m.isDefault = rs.getLong(rs.getColumnIndex('is_default')) === 1;
        m.isEnabled = rs.getLong(rs.getColumnIndex('is_enabled')) === 1;
        m.source = AIConfigRdbStore.str(rs, 'source');
        m.identity = AIConfigRdbStore.optStr(rs, 'identity') ?? 'model';
        m.systemProvision = AIConfigRdbStore.optStr(rs, 'system_provision');
        m.icon = AIConfigRdbStore.optStr(rs, 'icon');
        m.briefDescription = AIConfigRdbStore.optStr(rs, 'brief_description');
        m.updatedAt = AIConfigRdbStore.str(rs, 'updated_at');
        out.push(m);
        has = rs.goToNextRow();
      }
    } finally {
      rs.close();
    }
    return out;
  }

  private async loadBindings(db: relationalStore.RdbStore, accountId: number): Promise<LocalScenarioBinding[]> {
    const rs = await db.querySql(
      'SELECT * FROM ai_scenario_binding WHERE account_id = ? ORDER BY scenario, position',
      [accountId]
    );
    const out: LocalScenarioBinding[] = [];
    try {
      let has = rs.goToFirstRow();
      while (has) {
        const b = new LocalScenarioBinding();
        b.scenario = AIConfigRdbStore.str(rs, 'scenario');
        b.modelId = AIConfigRdbStore.str(rs, 'model_id');
        const tempIdx = rs.getColumnIndex('temperature');
        if (!rs.isColumnNull(tempIdx)) {
          b.temperature = rs.getDouble(tempIdx);
        }
        const mt = AIConfigRdbStore.optLong(rs, 'max_tokens');
        if (mt !== undefined) {
          b.maxTokens = mt;
        }
        b.systemProvision = AIConfigRdbStore.optStr(rs, 'system_provision');
        b.isDefault = rs.getLong(rs.getColumnIndex('is_default')) === 1;
        b.position = rs.getLong(rs.getColumnIndex('position'));
        b.enabled = rs.getLong(rs.getColumnIndex('enabled')) === 1;
        b.source = AIConfigRdbStore.str(rs, 'source');
        b.updatedAt = AIConfigRdbStore.str(rs, 'updated_at');
        b.relatedTaskCodes = AIConfigRdbStore.parseStringArray(AIConfigRdbStore.optStr(rs, 'related_task_codes'));
        b.aiToolScenarios = AIConfigRdbStore.parseStringArray(AIConfigRdbStore.optStr(rs, 'ai_tool_scenarios'));
        out.push(b);
        has = rs.goToNextRow();
      }
    } finally {
      rs.close();
    }
    return out;
  }

  private async loadTasks(db: relationalStore.RdbStore, accountId: number): Promise<LocalSmallTask[]> {
    const rs = await db.querySql('SELECT * FROM ai_small_task WHERE account_id = ?', [accountId]);
    const out: LocalSmallTask[] = [];
    try {
      let has = rs.goToFirstRow();
      while (has) {
        const t = new LocalSmallTask();
        t.code = AIConfigRdbStore.str(rs, 'code');
        t.name = AIConfigRdbStore.str(rs, 'name');
        t.brief = AIConfigRdbStore.optStr(rs, 'brief');
        t.prompt = AIConfigRdbStore.str(rs, 'prompt');
        t.icon = AIConfigRdbStore.optStr(rs, 'icon');
        try {
          const tools = JSON.parse(AIConfigRdbStore.str(rs, 'tool_list_json') || '[]') as Object[];
          if (Array.isArray(tools)) {
            for (let i = 0; i < tools.length; i++) {
              t.toolList.push(`${tools[i]}`);
            }
          }
        } catch (_e) {
          t.toolList = [];
        }
        t.source = AIConfigRdbStore.str(rs, 'source');
        t.isEnabled = rs.getLong(rs.getColumnIndex('enabled')) === 1;
        t.updatedAt = AIConfigRdbStore.str(rs, 'updated_at');
        out.push(t);
        has = rs.goToNextRow();
      }
    } finally {
      rs.close();
    }
    return out;
  }

  private async loadFiles(db: relationalStore.RdbStore, accountId: number): Promise<LocalModelFile[]> {
    const rs = await db.querySql('SELECT * FROM ai_model_file WHERE account_id = ?', [accountId]);
    const out: LocalModelFile[] = [];
    try {
      let has = rs.goToFirstRow();
      while (has) {
        const f = new LocalModelFile();
        f.modelId = AIConfigRdbStore.str(rs, 'model_id');
        f.path = AIConfigRdbStore.str(rs, 'path');
        f.sizeBytes = rs.getLong(rs.getColumnIndex('size_bytes'));
        f.sha256 = AIConfigRdbStore.str(rs, 'sha256');
        f.downloadState = AIConfigRdbStore.fileState(AIConfigRdbStore.str(rs, 'download_state'));
        f.downloadedAt = AIConfigRdbStore.optStr(rs, 'downloaded_at');
        f.errorCode = AIConfigRdbStore.optStr(rs, 'error_code');
        f.updatedAt = AIConfigRdbStore.str(rs, 'updated_at');
        out.push(f);
        has = rs.goToNextRow();
      }
    } finally {
      rs.close();
    }
    return out;
  }

  private async loadPrefs(db: relationalStore.RdbStore, accountId: number): Promise<AIUserPreferences> {
    const rs = await db.querySql('SELECT * FROM ai_preferences WHERE account_id = ?', [accountId]);
    const p = new AIUserPreferences();
    try {
      if (!rs.goToFirstRow()) {
        return p;
      }
      const ds = AIConfigRdbStore.str(rs, 'default_source');
      if (ds === 'local' || ds === 'pro' || ds === 'auto') {
        p.defaultSource = ds;
      }
      p.allowNetwork = rs.getLong(rs.getColumnIndex('allow_network')) === 1;
      p.allowLocalModel = rs.getLong(rs.getColumnIndex('allow_local_model')) === 1;
      p.selectedProviderId = AIConfigRdbStore.optStr(rs, 'selected_provider_id');
      p.selectedModelId = AIConfigRdbStore.optStr(rs, 'selected_model_id');
      p.updatedAt = AIConfigRdbStore.str(rs, 'updated_at');
      p.scenarioSources = AIConfigRdbStore.parseScenarioSources(AIConfigRdbStore.optStr(rs, 'extras_json'));
      return p;
    } finally {
      rs.close();
    }
  }

  private async insertProviders(db: relationalStore.RdbStore, accountId: number, rows: LocalProvider[]): Promise<void> {
    for (let i = 0; i < rows.length; i++) {
      const p = rows[i];
      await db.executeSql(
        `INSERT OR REPLACE INTO ai_provider
         (id, account_id, name, company, kind, request_url, secret_ref, is_enabled, position, source, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          p.id, accountId, p.name, p.company, p.kind, p.requestUrl ?? null, p.secretRef ?? null,
          p.isEnabled ? 1 : 0, p.position, p.source, p.updatedAt || nowIso()
        ]
      );
    }
  }

  private async insertModels(db: relationalStore.RdbStore, accountId: number, rows: LocalModel[]): Promise<void> {
    for (let i = 0; i < rows.length; i++) {
      const m = rows[i];
      await db.executeSql(
        `INSERT OR REPLACE INTO ai_model
         (id, account_id, provider_id, name, display_name, base_model_name, model_type, capabilities_json,
          context_window, price_tier, is_default, is_enabled, source, identity, system_provision, icon,
          brief_description, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          m.id, accountId, m.providerId, m.name, m.displayName, m.baseModelName ?? null, m.modelType,
          m.capabilities.toJson(), m.contextWindow ?? null, m.priceTier ?? null,
          m.isDefault ? 1 : 0, m.isEnabled ? 1 : 0, m.source, m.identity,
          m.systemProvision ?? null, m.icon ?? null, m.briefDescription ?? null, m.updatedAt || nowIso()
        ]
      );
    }
  }

  private async insertBindings(
    db: relationalStore.RdbStore,
    accountId: number,
    rows: LocalScenarioBinding[]
  ): Promise<void> {
    for (let i = 0; i < rows.length; i++) {
      const b = rows[i];
      await db.executeSql(
        `INSERT OR REPLACE INTO ai_scenario_binding
         (account_id, scenario, model_id, temperature, max_tokens, system_provision, is_default, position, enabled, source, related_task_codes, ai_tool_scenarios, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          accountId, b.scenario, b.modelId, b.temperature ?? null, b.maxTokens ?? null,
          b.systemProvision ?? null, b.isDefault ? 1 : 0, b.position, b.enabled ? 1 : 0,
          b.source,
          JSON.stringify(b.relatedTaskCodes ?? []),
          JSON.stringify(b.aiToolScenarios ?? []),
          b.updatedAt || nowIso()
        ]
      );
    }
  }

  private async insertTasks(db: relationalStore.RdbStore, accountId: number, rows: LocalSmallTask[]): Promise<void> {
    for (let i = 0; i < rows.length; i++) {
      const t = rows[i];
      await db.executeSql(
        `INSERT OR REPLACE INTO ai_small_task
         (account_id, code, name, brief, prompt, icon, tool_list_json, source, enabled, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          accountId, t.code, t.name, t.brief ?? null, t.prompt, t.icon ?? null,
          JSON.stringify(t.toolList), t.source, t.isEnabled ? 1 : 0, t.updatedAt || nowIso()
        ]
      );
    }
  }

  private async insertFiles(db: relationalStore.RdbStore, accountId: number, rows: LocalModelFile[]): Promise<void> {
    await db.executeSql('DELETE FROM ai_model_file WHERE account_id = ?', [accountId]);
    for (let i = 0; i < rows.length; i++) {
      const f = rows[i];
      await db.executeSql(
        `INSERT OR REPLACE INTO ai_model_file
         (account_id, model_id, path, size_bytes, sha256, download_state, downloaded_at, error_code, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          accountId, f.modelId, f.path, f.sizeBytes, f.sha256, f.downloadState,
          f.downloadedAt ?? null, f.errorCode ?? null, f.updatedAt || nowIso()
        ]
      );
    }
  }

  private async insertPrefs(db: relationalStore.RdbStore, accountId: number, prefs: AIUserPreferences): Promise<void> {
    const extras = new AIConfigPreferencesExtras();
    extras.scenarioSources = prefs.scenarioSources;
    await db.executeSql(
      `INSERT OR REPLACE INTO ai_preferences
       (account_id, default_source, allow_network, allow_local_model, selected_provider_id, selected_model_id, extras_json, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        accountId, prefs.defaultSource, prefs.allowNetwork ? 1 : 0, prefs.allowLocalModel ? 1 : 0,
        prefs.selectedProviderId ?? null, prefs.selectedModelId ?? null,
        JSON.stringify(extras), prefs.updatedAt || nowIso()
      ]
    );
  }

  private static toError(value: Object): Error {
    if (value instanceof Error) {
      return value;
    }
    return new Error(`${value}`);
  }

  private static parseStringArray(raw?: string): string[] {
    if (!raw || raw.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as Object;
      if (!Array.isArray(parsed)) {
        return [];
      }
      const out: string[] = [];
      const arr = parsed as Object[];
      for (let i = 0; i < arr.length; i++) {
        out.push(`${arr[i]}`);
      }
      return out;
    } catch (_e) {
      return [];
    }
  }

  private static parseScenarioSources(raw?: string): Record<string, AIDefaultSource> {
    const out: Record<string, AIDefaultSource> = {};
    if (!raw || raw.length === 0) {
      return out;
    }
    try {
      const parsed = JSON.parse(raw) as Record<string, Object>;
      const sources = parsed['scenarioSources'] as Record<string, string> | undefined;
      if (!sources) {
        return out;
      }
      const keys = Object.keys(sources);
      for (let i = 0; i < keys.length; i++) {
        const v = sources[keys[i]];
        if (v === 'local' || v === 'pro' || v === 'auto') {
          out[keys[i]] = v;
        }
      }
    } catch (_e) {
      // ignore
    }
    return out;
  }

  private static str(rs: relationalStore.ResultSet, col: string): string {
    try {
      return rs.getString(rs.getColumnIndex(col)) ?? '';
    } catch (_e) {
      return '';
    }
  }

  private static optStr(rs: relationalStore.ResultSet, col: string): string | undefined {
    try {
      const idx = rs.getColumnIndex(col);
      if (rs.isColumnNull(idx)) {
        return undefined;
      }
      return rs.getString(idx);
    } catch (_e) {
      return undefined;
    }
  }

  private static optLong(rs: relationalStore.ResultSet, col: string): number | undefined {
    try {
      const idx = rs.getColumnIndex(col);
      if (rs.isColumnNull(idx)) {
        return undefined;
      }
      return rs.getLong(idx);
    } catch (_e) {
      return undefined;
    }
  }

  private static syncState(value: string): AISyncState {
    if (value === 'uninitialized' || value === 'empty' || value === 'seeding' ||
      value === 'localReady' || value === 'draft' || value === 'refreshing' ||
      value === 'remoteReady' || value === 'degraded' || value === 'invalidated') {
      return value;
    }
    return 'empty';
  }

  private static fileState(value: string): AIModelFileState {
    if (value === 'missing' || value === 'downloading' || value === 'ready' || value === 'failed') {
      return value;
    }
    return 'missing';
  }
}

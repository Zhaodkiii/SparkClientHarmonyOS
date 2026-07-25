import {
  AIConfigSnapshot,
  LocalModel,
  LocalProvider,
  LocalScenarioBinding,
  LocalSmallTask,
  ProBootstrapSnapshot,
  normalizeProviderId,
  nowIso
} from '../Domain/AIConfigModels';

/**
 * 将 Pro bootstrap DTO 物化为 Resolver 可消费的临时行（不落本地密钥目录）。
 */
export class ProOverlayMaterializer {
  /** 仅 Pro 行的片段快照（providers/models/bindings/tasks） */
  static materialize(
    accountId: number,
    remote: ProBootstrapSnapshot,
    secretRefs: Map<string, string>
  ): AIConfigSnapshot {
    const snap = new AIConfigSnapshot();
    snap.accountId = accountId;
    snap.source = 'pro';
    snap.revision = remote.revision;
    snap.remoteEtag = remote.etag;
    snap.syncState = 'remoteReady';
    snap.updatedAt = nowIso();

    const ts = snap.updatedAt;
    const providerSeen: Set<string> = new Set();
    const modelSeen: Set<string> = new Set();

    for (let si = 0; si < remote.scenarios.length; si++) {
      const bundle = remote.scenarios[si];
      for (let mi = 0; mi < bundle.models.length; mi++) {
        const row = bundle.models[mi];
        const company = row.company || 'PRO';
        const providerId = `pro:${normalizeProviderId(company)}`;
        if (!providerSeen.has(providerId)) {
          providerSeen.add(providerId);
          const p = new LocalProvider();
          p.id = providerId;
          p.name = company;
          p.company = company;
          p.kind = 'api';
          p.requestUrl = row.endpoint;
          p.secretRef = secretRefs.get(providerId);
          p.isEnabled = true;
          p.position = snap.providers.length;
          p.source = 'pro';
          p.updatedAt = ts;
          snap.providers.push(p);
        }
        const modelId = `pro:${providerId}:${row.name}`;
        if (!modelSeen.has(modelId)) {
          modelSeen.add(modelId);
          const m = new LocalModel();
          m.id = modelId;
          m.name = row.name;
          m.displayName = row.displayName;
          m.providerId = providerId;
          m.baseModelName = row.baseModelName;
          m.modelType = 'remote';
          m.capabilities = row.capabilities;
          m.priceTier = row.priceTier;
          m.isEnabled = true;
          m.source = 'pro';
          m.identity = row.identity;
          m.systemProvision = row.systemProvision;
          m.updatedAt = ts;
          snap.models.push(m);
        }
        const b = new LocalScenarioBinding();
        b.scenario = bundle.scenario;
        b.modelId = modelId;
        b.temperature = row.temperature;
        b.maxTokens = row.maxTokens;
        b.systemProvision = row.systemProvision;
        b.isDefault = row.isDefault || row.name === bundle.defaultModel;
        b.position = mi;
        b.enabled = true;
        b.source = 'pro';
        b.relatedTaskCodes = row.relatedTaskCodes ? row.relatedTaskCodes.slice() : [];
        b.aiToolScenarios = row.aiToolScenarios ? row.aiToolScenarios.slice() : [];
        b.updatedAt = ts;
        snap.scenarioBindings.push(b);
      }
    }

    for (let ti = 0; ti < remote.smallTasks.length; ti++) {
      const task = remote.smallTasks[ti];
      if (task.isDeleted) {
        continue;
      }
      const t = new LocalSmallTask();
      t.code = task.code;
      t.name = task.name;
      t.brief = task.brief;
      t.prompt = task.prompt;
      t.icon = task.icon;
      t.toolList = task.toolList.slice();
      t.source = 'pro';
      t.isEnabled = true;
      t.updatedAt = ts;
      snap.smallTasks.push(t);
    }
    return snap;
  }

  /**
   * 合并本地目录 + Pro overlay 供 Resolver / Runtime / 模型页消费。
   * 不修改入参；返回新快照。
   */
  static merge(local: AIConfigSnapshot, proFragment?: AIConfigSnapshot): AIConfigSnapshot {
    const out = new AIConfigSnapshot();
    out.accountId = local.accountId;
    out.schemaVersion = local.schemaVersion;
    out.seedVersion = local.seedVersion;
    out.revision = proFragment?.revision ?? local.revision;
    out.remoteEtag = proFragment?.remoteEtag ?? local.remoteEtag;
    out.syncState = local.syncState;
    out.source = proFragment ? 'merged' : local.source;
    out.updatedAt = local.updatedAt;
    out.preferences = local.preferences;
    out.modelFiles = local.modelFiles.slice();

    out.providers = local.providers.filter((p) => !ProOverlayMaterializer.isRemoteOverlaySource(p.source, p.id));
    out.models = local.models.filter((m) => !ProOverlayMaterializer.isRemoteOverlaySource(m.source, m.id));
    out.scenarioBindings = local.scenarioBindings.filter(
      (b) => !ProOverlayMaterializer.isRemoteOverlaySource(b.source)
    );
    out.smallTasks = local.smallTasks.filter(
      (t) => t.source !== 'pro' && t.source !== 'Service' && t.source !== 'trial'
    );

    if (proFragment) {
      for (let i = 0; i < proFragment.providers.length; i++) {
        out.providers.push(proFragment.providers[i]);
      }
      for (let i = 0; i < proFragment.models.length; i++) {
        out.models.push(proFragment.models[i]);
      }
      for (let i = 0; i < proFragment.scenarioBindings.length; i++) {
        out.scenarioBindings.push(proFragment.scenarioBindings[i]);
      }
      for (let i = 0; i < proFragment.smallTasks.length; i++) {
        const task = proFragment.smallTasks[i];
        if (out.smallTasks.some((t) => t.code === task.code)) {
          continue;
        }
        out.smallTasks.push(task);
      }
      if (proFragment.revision && proFragment.revision.length > 0) {
        out.revision = proFragment.revision;
      }
      if (local.syncState === 'localReady' || local.syncState === 'remoteReady' || local.syncState === 'degraded') {
        out.syncState = 'remoteReady';
      }
    }
    return out;
  }

  static isRemoteOverlaySource(source: string, id?: string): boolean {
    if (source === 'pro' || source === 'trial' || source === 'Service') {
      return true;
    }
    if (id && id.indexOf('pro:') === 0) {
      return true;
    }
    return false;
  }

  /** 本地密钥目录允许的 source */
  static isLocalCatalogSource(source: string, id: string): boolean {
    if (ProOverlayMaterializer.isRemoteOverlaySource(source, id)) {
      return false;
    }
    return true;
  }
}

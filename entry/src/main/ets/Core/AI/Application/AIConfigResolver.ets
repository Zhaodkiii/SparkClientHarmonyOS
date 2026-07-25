import { ScenarioPolicyResolver } from './ScenarioPolicyResolver';
import {
  AIConfigSnapshot,
  AIResolvedConfig,
  AIScenario,
  LocalModel,
  LocalProvider,
  LocalScenarioBinding,
  ResolvedSmallTask,
  RuntimeProviderRef,
  RuntimeSnapshot,
  makeLocalRevision,
  nowIso,
  AIDefaultSource
} from '../Domain/AIConfigModels';
import { isLocalProviderId } from '../Domain/AILocalProviderIds';

export class ResolveError extends Error {
  code: string = 'missingModelForScenario';
  scenario: string = '';
  message: string = '';

  constructor(code: string, scenario: string, message: string) {
    super(message);
    this.name = 'ResolveError';
    this.code = code;
    this.scenario = scenario;
    this.message = message;
  }
}

/**
 * 本地 / Pro / 试用合并解析。不修改源快照。
 * 优先级：用户显式 > 本地默认 > 试用 Pro > Pro 默认 > 本地首项。
 */
export class AIConfigResolver {
  buildRuntime(snapshot: AIConfigSnapshot, options?: ResolveOptions): RuntimeSnapshot {
    const opts = options ?? new ResolveOptions();
    const repaired = this.repairView(snapshot);
    const runtime = new RuntimeSnapshot();
    runtime.accountId = snapshot.accountId;
    runtime.state = snapshot.syncState || 'localReady';
    runtime.localRevision = makeLocalRevision(snapshot.updatedAt || nowIso(), `${snapshot.providers.length}-${snapshot.models.length}`);
    runtime.remoteRevision = snapshot.revision;
    runtime.createdAt = nowIso();
    runtime.degradeReason = repaired.degradeReason;
    if (repaired.degradeReason && runtime.state !== 'remoteReady') {
      runtime.state = 'degraded';
    }

    for (let i = 0; i < snapshot.providers.length; i++) {
      const p = snapshot.providers[i];
      const ref = new RuntimeProviderRef();
      ref.providerId = p.id;
      ref.company = p.company;
      ref.kind = p.kind;
      ref.requestUrl = p.requestUrl;
      ref.secretRef = p.secretRef;
      ref.isEnabled = p.isEnabled;
      ref.source = p.source;
      runtime.providers.set(p.id, ref);
    }

    const scenarios = AIScenario.allKnown();
    for (let si = 0; si < scenarios.length; si++) {
      const scenario = scenarios[si];
      const candidates = this.candidatesForScenario(snapshot, scenario, opts);
      runtime.scenarios.set(scenario, candidates);
      if (candidates.length > 0) {
        runtime.effectiveDefaults.set(scenario, candidates[0].modelId);
      }
    }

    // 小任务：本地用户优先；Pro 只补缺失 code
    const taskMap: Map<string, ResolvedSmallTask> = new Map();
    for (let i = 0; i < snapshot.smallTasks.length; i++) {
      const t = snapshot.smallTasks[i];
      if (!t.isEnabled) {
        continue;
      }
      const isLocalUser = t.source === 'Local' || t.source === 'localUser' || t.source === 'localSeed';
      const existing = taskMap.get(t.code);
      if (existing && isLocalUser) {
        // keep / overwrite with local
      }
      if (existing && !isLocalUser) {
        continue;
      }
      const r = new ResolvedSmallTask();
      r.code = t.code;
      r.name = t.name;
      r.brief = t.brief;
      r.prompt = t.prompt;
      r.toolList = t.toolList.slice();
      r.source = t.source;
      r.isEnabled = t.isEnabled;
      taskMap.set(t.code, r);
    }
    runtime.smallTasks = taskMap;
    return runtime;
  }

  resolve(
    snapshot: AIConfigSnapshot,
    scenario: string,
    preferredModelName?: string,
    options?: ResolveOptions
  ): AIResolvedConfig {
    const runtime = this.buildRuntime(snapshot, options);
    const list = runtime.scenarios.get(scenario) ?? [];
    if (preferredModelName && preferredModelName.length > 0) {
      const hit = ScenarioPolicyResolver.pickExact(list, preferredModelName);
      if (!hit) {
        throw new ResolveError('missingModelForScenario', scenario, `preferred model not found: ${preferredModelName}`);
      }
      return hit;
    }
    if (list.length === 0) {
      throw new ResolveError('missingModelForScenario', scenario, 'no available model');
    }
    return list[0];
  }

  private candidatesForScenario(
    snapshot: AIConfigSnapshot,
    scenario: string,
    opts: ResolveOptions
  ): AIResolvedConfig[] {
    const ordered: AIResolvedConfig[] = [];
    const seen: Set<string> = new Set();
    const preferredSource = AIConfigResolver.preferredSourceForScenario(snapshot, scenario);

    const pushUnique = (cfg: AIResolvedConfig | undefined): void => {
      if (!cfg || !cfg.isReady) {
        return;
      }
      if (seen.has(cfg.modelId)) {
        return;
      }
      if (!AIConfigResolver.matchesPreferredSource(preferredSource, cfg.source)) {
        return;
      }
      seen.add(cfg.modelId);
      ordered.push(cfg);
    };

    // 1. 用户显式选择
    if (opts.userSelectedModelIdByScenario.has(scenario)) {
      pushUnique(this.configFromModelId(snapshot, scenario, opts.userSelectedModelIdByScenario.get(scenario)!, 'local', undefined, opts));
    } else if (snapshot.preferences.selectedModelId && preferredSource !== 'pro') {
      // 全局选中仅在匹配场景绑定时使用
      const mid = snapshot.preferences.selectedModelId;
      if (this.bindingExists(snapshot, scenario, mid)) {
        pushUnique(this.configFromModelId(snapshot, scenario, mid, 'local', undefined, opts));
      }
    }

    // 2. 本地默认（preferred=pro 时跳过）
    if (preferredSource !== 'pro') {
      pushUnique(this.defaultFromSource(snapshot, scenario, opts, 'localSeed', 'localUser', 'local', 'system'));
    }

    // 3. 试用 Pro
    if (preferredSource !== 'local' && opts.trialActive) {
      pushUnique(this.defaultFromSource(snapshot, scenario, opts, 'trial'));
    }

    // 4. Pro 默认
    if (preferredSource !== 'local' &&
      snapshot.preferences.allowNetwork !== false &&
      snapshot.preferences.defaultSource !== 'local') {
      pushUnique(this.defaultFromSource(snapshot, scenario, opts, 'pro'));
    }

    // 5. 本地可用列表其余项 + Pro 其余项
    const bindings: LocalScenarioBinding[] = [];
    for (let i = 0; i < snapshot.scenarioBindings.length; i++) {
      const b = snapshot.scenarioBindings[i];
      if (b.scenario === scenario && b.enabled) {
        bindings.push(b);
      }
    }
    for (let i = 0; i < bindings.length; i++) {
      for (let j = i + 1; j < bindings.length; j++) {
        if (bindings[j].position < bindings[i].position) {
          const tmp = bindings[i];
          bindings[i] = bindings[j];
          bindings[j] = tmp;
        }
      }
    }
    for (let i = 0; i < bindings.length; i++) {
      const src = bindings[i].source === 'pro' || bindings[i].source === 'trial' ? bindings[i].source : 'local';
      if (src !== 'local' && snapshot.preferences.allowNetwork === false) {
        continue;
      }
      if (src !== 'local' && preferredSource === 'local') {
        continue;
      }
      if (src === 'local' && preferredSource === 'pro') {
        continue;
      }
      pushUnique(this.configFromModelId(snapshot, scenario, bindings[i].modelId, src, bindings[i], opts));
    }

    return ordered;
  }

  private static preferredSourceForScenario(snapshot: AIConfigSnapshot, scenario: string): AIDefaultSource {
    const fromScenario = snapshot.preferences.scenarioSources
      ? snapshot.preferences.scenarioSources[scenario]
      : undefined;
    if (fromScenario === 'local' || fromScenario === 'pro' || fromScenario === 'auto') {
      return fromScenario;
    }
    const global = snapshot.preferences.defaultSource;
    if (global === 'local' || global === 'pro' || global === 'auto') {
      return global;
    }
    return 'auto';
  }

  private static matchesPreferredSource(preferred: AIDefaultSource, candidateSource: string): boolean {
    if (preferred === 'auto') {
      return true;
    }
    if (preferred === 'local') {
      return candidateSource === 'local' || candidateSource.indexOf('local') === 0;
    }
    // pro：允许 pro / trial
    return candidateSource === 'pro' || candidateSource === 'trial';
  }

  private defaultFromSource(
    snapshot: AIConfigSnapshot,
    scenario: string,
    opts: ResolveOptions,
    ...sources: string[]
  ): AIResolvedConfig | undefined {
    let best: LocalScenarioBinding | undefined;
    for (let i = 0; i < snapshot.scenarioBindings.length; i++) {
      const b = snapshot.scenarioBindings[i];
      if (b.scenario !== scenario || !b.enabled || !b.isDefault) {
        continue;
      }
      if (sources.indexOf(b.source) < 0 && !(sources.indexOf('local') >= 0 && b.source.indexOf('local') >= 0)) {
        // allow local* if 'local' requested
        let ok = false;
        for (let s = 0; s < sources.length; s++) {
          if (b.source === sources[s] || (sources[s] === 'local' && b.source.indexOf('local') === 0)) {
            ok = true;
          }
          if (sources[s] === 'system' && (b.source === 'system' || b.source === 'localSeed')) {
            ok = true;
          }
        }
        if (!ok) {
          continue;
        }
      } else {
        // matched via indexOf sources
      }
      let matched = false;
      for (let s = 0; s < sources.length; s++) {
        if (b.source === sources[s]) {
          matched = true;
        }
        if (sources[s] === 'local' && (b.source.indexOf('local') === 0 || b.source === 'system' || b.source === 'localSeed')) {
          matched = true;
        }
      }
      if (!matched) {
        continue;
      }
      if (!best || b.position < best.position) {
        best = b;
      }
    }
    if (!best) {
      return undefined;
    }
    const srcLabel = best.source === 'pro' || best.source === 'trial' ? best.source : 'local';
    return this.configFromModelId(snapshot, scenario, best.modelId, srcLabel, best, opts);
  }

  private bindingExists(snapshot: AIConfigSnapshot, scenario: string, modelId: string): boolean {
    for (let i = 0; i < snapshot.scenarioBindings.length; i++) {
      const b = snapshot.scenarioBindings[i];
      if (b.scenario === scenario && b.modelId === modelId && b.enabled) {
        return true;
      }
    }
    return false;
  }

  private configFromModelId(
    snapshot: AIConfigSnapshot,
    scenario: string,
    modelId: string,
    source: string,
    binding?: LocalScenarioBinding,
    opts?: ResolveOptions
  ): AIResolvedConfig | undefined {
    let model: LocalModel | undefined;
    for (let i = 0; i < snapshot.models.length; i++) {
      if (snapshot.models[i].id === modelId) {
        model = snapshot.models[i];
        break;
      }
    }
    if (!model || !model.isEnabled) {
      return undefined;
    }
    let provider: LocalProvider | undefined;
    for (let i = 0; i < snapshot.providers.length; i++) {
      if (snapshot.providers[i].id === model.providerId) {
        provider = snapshot.providers[i];
        break;
      }
    }
    if (!provider || !provider.isEnabled) {
      return undefined;
    }
    if (provider.kind === 'local' || isLocalProviderId(provider.id) || model.modelType === 'gguf') {
      let fileReady = false;
      for (let i = 0; i < snapshot.modelFiles.length; i++) {
        if (snapshot.modelFiles[i].modelId === model.id && snapshot.modelFiles[i].downloadState === 'ready') {
          fileReady = true;
        }
      }
      // 本地模型：必须 installState=ready（文件 ready）且允许本地
      if (!fileReady || snapshot.preferences.allowLocalModel === false) {
        return undefined;
      }
    } else {
      if (!provider.requestUrl || provider.requestUrl.length === 0) {
        return undefined;
      }
      // Pro/API：必须有 secretRef（HUKS 引用存在）；无 Key 不可消费
      if (!provider.secretRef || provider.secretRef.length === 0) {
        return undefined;
      }
      if (opts && opts.enforceCredentialCheck && opts.providersWithCredential.size > 0) {
        if (!opts.providersWithCredential.has(provider.id)) {
          return undefined;
        }
      }
    }
    const cfg = new AIResolvedConfig();
    cfg.scenario = scenario;
    cfg.source = source;
    cfg.providerId = provider.id;
    cfg.modelId = model.id;
    cfg.modelName = model.baseModelName && model.identity === 'agent' ? model.baseModelName : model.name;
    cfg.endpoint = provider.requestUrl;
    cfg.secretRef = provider.secretRef;
    cfg.capabilities = model.capabilities;
    cfg.temperature = binding?.temperature;
    cfg.maxTokens = binding?.maxTokens;
    cfg.systemProvision = binding?.systemProvision ?? model.systemProvision;
    cfg.relatedTaskCodes = binding?.relatedTaskCodes ? binding.relatedTaskCodes.slice() : [];
    cfg.revision = snapshot.revision;
    cfg.isTrial = source === 'trial';
    cfg.isReady = true;
    cfg.modelType = model.modelType;
    cfg.company = provider.company;
    return cfg;
  }

  private repairView(snapshot: AIConfigSnapshot): RepairResult {
    const result = new RepairResult();
    const modelIds: Set<string> = new Set();
    for (let i = 0; i < snapshot.models.length; i++) {
      modelIds.add(snapshot.models[i].id);
    }
    const providerIds: Set<string> = new Set();
    for (let i = 0; i < snapshot.providers.length; i++) {
      providerIds.add(snapshot.providers[i].id);
    }
    let orphanBindings = 0;
    for (let i = 0; i < snapshot.scenarioBindings.length; i++) {
      if (!modelIds.has(snapshot.scenarioBindings[i].modelId)) {
        orphanBindings++;
      }
    }
    let disabledModels = 0;
    for (let i = 0; i < snapshot.models.length; i++) {
      if (!providerIds.has(snapshot.models[i].providerId)) {
        snapshot.models[i].isEnabled = false;
        disabledModels++;
      }
    }
    if (orphanBindings > 0 || disabledModels > 0) {
      result.degradeReason = `orphanBindings=${orphanBindings};disabledModels=${disabledModels}`;
    }
    return result;
  }
}

export class ResolveOptions {
  trialActive: boolean = false;
  userSelectedModelIdByScenario: Map<string, string> = new Map();
  /** 已确认 HUKS 中存在密钥的 providerId；若提供则 API Provider 必须命中 */
  providersWithCredential: Set<string> = new Set();
  /** 为 true 且 providersWithCredential 非空时强制校验 */
  enforceCredentialCheck: boolean = false;
}

class RepairResult {
  degradeReason?: string;
}

import {
  AIConfigSnapshot,
  AIModelFileState,
  LocalModel,
  LocalProvider,
  ModelCapabilities
} from '../../../../Core/AI/Domain/AIConfigModels';
import {
  isLocalCompany,
  isLocalProviderId,
  LOCAL_PROVIDER_ID
} from '../../../../Core/AI/Domain/AILocalProviderIds';
import { AIProviderDisplayNameResolver } from '../../../../Core/AI/Presentation/AIProviderDisplayNameResolver';

export type ProCredentialState = 'ready' | 'missingKey' | 'disabled' | 'unavailable';
export type LocalInstallState = 'notInstalled' | 'downloading' | 'verified' | 'ready' | 'failed';
export type ModelAvailability = 'ready' | 'configureKey' | 'install' | 'expired' | 'unavailable';
export type ModelCatalogFilter = 'all' | 'models' | 'agents' | 'local' | 'pro';

/** 模型密钥页展示行：仅 API/Pro/custom Provider */
export class ProProviderCredentialPresentation {
  providerId: string = '';
  localizedName: string = '';
  company: string = '';
  endpoint?: string;
  secretRef?: string;
  enabled: boolean = true;
  source: string = 'localSeed';
  sourceLabel: string = '';
  credentialState: ProCredentialState = 'missingKey';
  modelCount: number = 0;
}

/** 本地模型页展示行 */
export class LocalModelPresentation {
  modelId: string = '';
  displayName: string = '';
  providerId: string = LOCAL_PROVIDER_ID;
  localizedProviderName: string = '';
  installState: LocalInstallState = 'notInstalled';
  enabled: boolean = true;
  source: string = 'localSeed';
  sourceLabel: string = '';
  capabilities: ModelCapabilities = ModelCapabilities.empty();
  filePathRef?: string;
}

/** 模型列表统一行 */
export class AIModelPresentation {
  id: string = '';
  name: string = '';
  displayName: string = '';
  localizedProviderName: string = '';
  providerId: string = '';
  company: string = '';
  sourceLabel: string = '';
  availability: ModelAvailability = 'unavailable';
  capabilities: ModelCapabilities = ModelCapabilities.empty();
  isEnabled: boolean = true;
  identity: string = 'model';
  modelType: string = 'remote';
  source: string = 'localSeed';
  /** 0 免费 / 1 经济 / 2 标准 / 3 高级 */
  priceTier: number = 2;
  isLocal: boolean = false;
  baseModelName: string = '';
  icon: string = '';
}

/**
 * 本地 / Pro / 可见模型查询服务。
 * 页面禁止直接按 source 字符串过滤混合快照行。
 */
export class ProviderModelCatalogService {
  static modelsForProvider(snapshot: AIConfigSnapshot, providerId: string): LocalModel[] {
    const out: LocalModel[] = [];
    for (let i = 0; i < snapshot.models.length; i++) {
      const m = snapshot.models[i];
      if (m.providerId === providerId) {
        out.push(m);
      }
    }
    return out;
  }

  static enabledTextModels(snapshot: AIConfigSnapshot, providerId?: string): LocalModel[] {
    const out: LocalModel[] = [];
    for (let i = 0; i < snapshot.models.length; i++) {
      const m = snapshot.models[i];
      if (!m.isEnabled || !m.capabilities.supportsText) {
        continue;
      }
      if (providerId && m.providerId !== providerId) {
        continue;
      }
      out.push(m);
    }
    return out;
  }

  static enabledProviders(snapshot: AIConfigSnapshot): LocalProvider[] {
    return snapshot.providers.filter((p: LocalProvider) => p.isEnabled);
  }

  /**
   * 是否为可编辑的本地 API 凭证 Provider（对标 iOS 模型密钥列表）。
   * 排除：本地 GGUF、Pro/trial/Service overlay。
   */
  static isEditableApiCredentialProvider(provider: LocalProvider): boolean {
    if (provider.kind !== 'api') {
      return false;
    }
    if (isLocalProviderId(provider.id) || isLocalCompany(provider.company)) {
      return false;
    }
    if (provider.source === 'pro' || provider.source === 'trial' || provider.source === 'Service') {
      return false;
    }
    if (provider.id.indexOf('pro:') === 0) {
      return false;
    }
    return true;
  }

  /** @deprecated 使用 isEditableApiCredentialProvider；旧名易误解为“仅 Pro” */
  static isProCredentialProvider(provider: LocalProvider): boolean {
    return ProviderModelCatalogService.isEditableApiCredentialProvider(provider);
  }

  static isLocalModelProvider(provider: LocalProvider): boolean {
    return provider.kind === 'local' || isLocalProviderId(provider.id) || isLocalCompany(provider.company);
  }

  static isLocalModelRow(model: LocalModel, snapshot?: AIConfigSnapshot): boolean {
    if (model.modelType === 'gguf') {
      return true;
    }
    if (isLocalProviderId(model.providerId)) {
      return true;
    }
    if (!snapshot) {
      return false;
    }
    for (let i = 0; i < snapshot.providers.length; i++) {
      const p = snapshot.providers[i];
      if (p.id === model.providerId) {
        return ProviderModelCatalogService.isLocalModelProvider(p);
      }
    }
    return false;
  }

  /**
   * 模型密钥页：仅本地持久化的 seed/custom/system API Provider。
   * 不含 Pro overlay、trial、本地 GGUF。
   */
  static localCredentialProviders(
    snapshot: AIConfigSnapshot,
    keyConfiguredByProvider?: Map<string, boolean>
  ): ProProviderCredentialPresentation[] {
    const out: ProProviderCredentialPresentation[] = [];
    let filteredPro = 0;
    for (let i = 0; i < snapshot.providers.length; i++) {
      const p = snapshot.providers[i];
      if (p.source === 'pro' || p.source === 'trial' || p.id.indexOf('pro:') === 0) {
        filteredPro += 1;
        continue;
      }
      if (!ProviderModelCatalogService.isEditableApiCredentialProvider(p)) {
        continue;
      }
      const row = new ProProviderCredentialPresentation();
      row.providerId = p.id;
      row.localizedName = AIProviderDisplayNameResolver.display(p);
      row.company = p.company;
      row.endpoint = p.requestUrl;
      row.secretRef = p.secretRef;
      row.enabled = p.isEnabled;
      row.source = p.source;
      row.sourceLabel = AIProviderDisplayNameResolver.sourceLabel(p);
      row.modelCount = ProviderModelCatalogService.modelsForProvider(snapshot, p.id).length;
      const hasKey = keyConfiguredByProvider
        ? keyConfiguredByProvider.get(p.id) === true
        : (p.secretRef !== undefined && p.secretRef.length > 0);
      if (!p.isEnabled) {
        row.credentialState = 'disabled';
      } else if (hasKey) {
        row.credentialState = 'ready';
      } else {
        row.credentialState = 'missingKey';
      }
      out.push(row);
    }
    if (filteredPro > 0) {
      // 防御：本地快照不应含 Pro；若含则过滤并留给调用方日志
    }
    return out;
  }

  /** @deprecated 使用 localCredentialProviders */
  static proCredentials(
    snapshot: AIConfigSnapshot,
    keyConfiguredByProvider?: Map<string, boolean>
  ): ProProviderCredentialPresentation[] {
    return ProviderModelCatalogService.localCredentialProviders(snapshot, keyConfiguredByProvider);
  }

  /**
   * 模型页：合并本地目录 + Pro overlay 片段后查询可见模型。
   * Pro 行仅用于展示，不进入密钥列表。
   */
  static visibleModelsMerged(
    localSnapshot: AIConfigSnapshot,
    proOverlayFragment: AIConfigSnapshot | undefined,
    filter: ModelCatalogFilter,
    query: string,
    keyConfiguredByProvider?: Map<string, boolean>
  ): AIModelPresentation[] {
    if (!proOverlayFragment) {
      return ProviderModelCatalogService.visibleModels(localSnapshot, filter, query, keyConfiguredByProvider);
    }
    const merged = new AIConfigSnapshot();
    merged.accountId = localSnapshot.accountId;
    merged.providers = localSnapshot.providers.concat(proOverlayFragment.providers);
    merged.models = localSnapshot.models.concat(proOverlayFragment.models);
    merged.scenarioBindings = localSnapshot.scenarioBindings.concat(proOverlayFragment.scenarioBindings);
    merged.smallTasks = localSnapshot.smallTasks;
    merged.modelFiles = localSnapshot.modelFiles;
    merged.preferences = localSnapshot.preferences;
    return ProviderModelCatalogService.visibleModels(merged, filter, query, keyConfiguredByProvider);
  }

  /** 本地模型页 */
  static localModels(snapshot: AIConfigSnapshot): LocalModelPresentation[] {
    const out: LocalModelPresentation[] = [];
    for (let i = 0; i < snapshot.models.length; i++) {
      const m = snapshot.models[i];
      if (!ProviderModelCatalogService.isLocalModelRow(m, snapshot)) {
        continue;
      }
      const row = new LocalModelPresentation();
      row.modelId = m.id;
      row.displayName = m.displayName || m.name;
      row.providerId = m.providerId;
      row.localizedProviderName = AIProviderDisplayNameResolver.displayByIds(
        row.providerId,
        LOCAL_PROVIDER_ID,
        '',
        m.source
      );
      row.enabled = m.isEnabled;
      row.source = m.source;
      row.sourceLabel = AIProviderDisplayNameResolver.modelSourceLabel(m.source, m.providerId);
      row.capabilities = m.capabilities;
      row.installState = ProviderModelCatalogService.resolveInstallState(snapshot, m);
      for (let f = 0; f < snapshot.modelFiles.length; f++) {
        if (snapshot.modelFiles[f].modelId === m.id) {
          row.filePathRef = snapshot.modelFiles[f].path;
        }
      }
      out.push(row);
    }
    return out;
  }

  static visibleModels(
    snapshot: AIConfigSnapshot,
    filter: ModelCatalogFilter,
    query: string,
    keyConfiguredByProvider?: Map<string, boolean>
  ): AIModelPresentation[] {
    const q = query.trim().toLowerCase();
    const out: AIModelPresentation[] = [];
    for (let i = 0; i < snapshot.models.length; i++) {
      const m = snapshot.models[i];
      const isLocal = ProviderModelCatalogService.isLocalModelRow(m, snapshot);
      const isAgent = m.identity === 'agent';
      if (filter === 'models' && isAgent) {
        continue;
      }
      if (filter === 'agents' && !isAgent) {
        continue;
      }
      if (filter === 'local' && !isLocal) {
        continue;
      }
      if (filter === 'pro') {
        const isPro = m.source === 'pro' || m.id.indexOf('pro:') === 0 ||
          (m.providerId !== undefined && m.providerId.indexOf('pro:') === 0);
        if (!isPro) {
          continue;
        }
      }
      const provider = ProviderModelCatalogService.findProvider(snapshot, m.providerId);
      // 对标 iOS matchesApiKeyVisibility：非本地行须厂商已配置密钥且未隐藏
      if (!isLocal) {
        if (!provider || !provider.isEnabled) {
          continue;
        }
        const hasKey = keyConfiguredByProvider
          ? keyConfiguredByProvider.get(provider.id) === true
          : (provider.secretRef !== undefined && provider.secretRef.length > 0);
        const isPro = m.source === 'pro' || m.id.indexOf('pro:') === 0 ||
          provider.source === 'pro' || provider.id.indexOf('pro:') === 0;
        if (!hasKey && !isPro) {
          continue;
        }
      }
      const localizedProvider = provider
        ? AIProviderDisplayNameResolver.display(provider)
        : AIProviderDisplayNameResolver.displayByIds(m.providerId, '', '', m.source);
      // 对标 iOS：搜索仅匹配 displayName
      if (q.length > 0) {
        const dn = (m.displayName || m.name).trim().toLowerCase();
        if (dn.length === 0 || dn.indexOf(q) < 0) {
          continue;
        }
      }
      const row = new AIModelPresentation();
      row.id = m.id;
      row.name = m.name;
      row.displayName = m.displayName || m.name;
      row.localizedProviderName = localizedProvider;
      row.providerId = m.providerId;
      row.company = provider?.company ?? '';
      row.sourceLabel = AIProviderDisplayNameResolver.modelSourceLabel(m.source, m.providerId);
      row.capabilities = m.capabilities;
      row.isEnabled = m.isEnabled;
      row.identity = m.identity;
      row.modelType = m.modelType;
      row.source = m.source;
      row.priceTier = ProviderModelCatalogService.parsePriceTier(m.priceTier);
      row.isLocal = isLocal;
      row.baseModelName = m.baseModelName ?? '';
      row.icon = m.icon ?? '';
      row.availability = ProviderModelCatalogService.resolveAvailability(
        snapshot,
        m,
        provider,
        isLocal,
        keyConfiguredByProvider
      );
      out.push(row);
    }
    return out;
  }

  static parsePriceTier(raw?: string): number {
    if (!raw || raw.length === 0) {
      return 2;
    }
    const n = Number.parseInt(raw, 10);
    if (Number.isNaN(n)) {
      return 2;
    }
    return Math.min(Math.max(n, 0), 3);
  }

  /** 按筛选条件返回底层 LocalModel（供仍依赖领域模型的编辑页） */
  static filterModels(
    snapshot: AIConfigSnapshot,
    filter: string,
    query: string
  ): LocalModel[] {
    const catalogFilter: ModelCatalogFilter =
      filter === 'models' || filter === 'agents' || filter === 'local' || filter === 'pro'
        ? filter
        : 'all';
    const rows = ProviderModelCatalogService.visibleModels(snapshot, catalogFilter, query);
    const out: LocalModel[] = [];
    for (let i = 0; i < rows.length; i++) {
      const found = ProviderModelCatalogService.findModel(snapshot, rows[i].id);
      if (found) {
        out.push(found);
      }
    }
    return out;
  }

  private static findProvider(snapshot: AIConfigSnapshot, providerId: string): LocalProvider | undefined {
    for (let i = 0; i < snapshot.providers.length; i++) {
      if (snapshot.providers[i].id === providerId) {
        return snapshot.providers[i];
      }
    }
    return undefined;
  }

  private static findModel(snapshot: AIConfigSnapshot, modelId: string): LocalModel | undefined {
    for (let i = 0; i < snapshot.models.length; i++) {
      if (snapshot.models[i].id === modelId) {
        return snapshot.models[i];
      }
    }
    return undefined;
  }

  private static resolveInstallState(snapshot: AIConfigSnapshot, model: LocalModel): LocalInstallState {
    let state: AIModelFileState | undefined;
    for (let i = 0; i < snapshot.modelFiles.length; i++) {
      if (snapshot.modelFiles[i].modelId === model.id) {
        state = snapshot.modelFiles[i].downloadState;
      }
    }
    if (state === 'ready') {
      return 'ready';
    }
    if (state === 'downloading') {
      return 'downloading';
    }
    if (state === 'failed') {
      return 'failed';
    }
    if (model.modelType === 'gguf') {
      return 'notInstalled';
    }
    // 非 gguf 但挂在 local provider：视为已就绪目录项
    return 'ready';
  }

  private static resolveAvailability(
    snapshot: AIConfigSnapshot,
    model: LocalModel,
    provider: LocalProvider | undefined,
    isLocal: boolean,
    keyConfiguredByProvider?: Map<string, boolean>
  ): ModelAvailability {
    if (!model.isEnabled) {
      return 'unavailable';
    }
    if (isLocal) {
      const install = ProviderModelCatalogService.resolveInstallState(snapshot, model);
      if (install === 'ready') {
        return 'ready';
      }
      if (install === 'notInstalled' || install === 'failed') {
        return 'install';
      }
      return 'unavailable';
    }
    if (!provider || !provider.isEnabled) {
      return 'unavailable';
    }
    const hasKey = keyConfiguredByProvider
      ? keyConfiguredByProvider.get(provider.id) === true
      : (provider.secretRef !== undefined && provider.secretRef.length > 0);
    if (!hasKey) {
      return 'configureKey';
    }
    if (model.source === 'trial') {
      // 试用过期由上层 trialStatus 判定；此处仅标记可用
      return 'ready';
    }
    return 'ready';
  }
}

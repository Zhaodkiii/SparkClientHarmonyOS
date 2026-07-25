import {
  AIConfigSnapshot,
  LocalModel,
  LocalProvider,
  ModelCapabilities,
  nowIso
} from '../../../../Core/AI/Domain/AIConfigModels';

export class ModelCatalogUseCases {
  /** 云模型无 Key 时不可启用 */
  static canEnable(snapshot: AIConfigSnapshot, model: LocalModel, hasSecret: boolean): boolean {
    if (model.modelType === 'gguf') {
      return true;
    }
    const provider = ModelCatalogUseCases.findProvider(snapshot, model.providerId);
    if (!provider) {
      return false;
    }
    if (provider.source === 'pro') {
      return true;
    }
    return hasSecret || (provider.secretRef !== undefined && provider.secretRef.length > 0);
  }

  static setEnabled(
    snapshot: AIConfigSnapshot,
    modelId: string,
    enabled: boolean,
    hasSecret: boolean
  ): void {
    for (let i = 0; i < snapshot.models.length; i++) {
      const m = snapshot.models[i];
      if (m.id !== modelId) {
        continue;
      }
      if (enabled && !ModelCatalogUseCases.canEnable(snapshot, m, hasSecret)) {
        throw new Error('请先配置该厂商的 API Key 再启用模型');
      }
      m.isEnabled = enabled;
      m.updatedAt = nowIso();
    }
  }

  static upsert(snapshot: AIConfigSnapshot, model: LocalModel): void {
    if (!model.id || model.id.length === 0) {
      model.id = `${model.providerId}:${model.name}`;
    }
    if (!model.displayName || model.displayName.length === 0) {
      model.displayName = model.name;
    }
    model.updatedAt = nowIso();
    if (!model.source || model.source.length === 0) {
      model.source = 'localUser';
    }
    let found = false;
    for (let i = 0; i < snapshot.models.length; i++) {
      if (snapshot.models[i].id === model.id) {
        snapshot.models[i] = model;
        found = true;
        break;
      }
    }
    if (!found) {
      snapshot.models.push(model);
    }
  }

  static upsertAgent(
    snapshot: AIConfigSnapshot,
    displayName: string,
    baseModelId: string,
    systemProvision: string,
    existingId?: string
  ): LocalModel {
    const base = ModelCatalogUseCases.findModel(snapshot, baseModelId);
    if (!base) {
      throw new Error('请选择基座模型');
    }
    if (!displayName || displayName.trim().length === 0) {
      throw new Error('请填写智能体名称');
    }
    if (!systemProvision || systemProvision.trim().length === 0) {
      throw new Error('请填写系统提示词');
    }
    const agent = existingId ? (ModelCatalogUseCases.findModel(snapshot, existingId) ?? new LocalModel()) : new LocalModel();
    if (!existingId) {
      agent.id = `agent:${base.providerId}:${Date.now()}`;
      agent.source = 'localUser';
    }
    agent.name = agent.id;
    agent.displayName = displayName.trim();
    agent.providerId = base.providerId;
    agent.baseModelName = base.name;
    agent.modelType = base.modelType;
    agent.capabilities = base.capabilities;
    agent.identity = 'agent';
    agent.systemProvision = systemProvision.trim();
    agent.isEnabled = true;
    ModelCatalogUseCases.upsert(snapshot, agent);
    return agent;
  }

  static delete(snapshot: AIConfigSnapshot, modelId: string): void {
    const m = ModelCatalogUseCases.findModel(snapshot, modelId);
    if (m && m.source === 'pro') {
      throw new Error('不能删除 Pro 模型');
    }
    snapshot.models = snapshot.models.filter((x: LocalModel) => x.id !== modelId);
    snapshot.scenarioBindings = snapshot.scenarioBindings.filter((b) => b.modelId !== modelId);
  }

  static createOnline(
    providerId: string,
    name: string,
    displayName: string,
    capabilities: ModelCapabilities,
    priceTier: number = 2,
    isHidden: boolean = false
  ): LocalModel {
    if (!providerId || !name.trim()) {
      throw new Error('请选择厂商并填写模型名');
    }
    const m = new LocalModel();
    m.id = `${providerId}:${name.trim()}`;
    m.name = name.trim();
    m.displayName = displayName.trim() || name.trim();
    m.providerId = providerId;
    m.modelType = 'remote';
    m.capabilities = capabilities;
    m.identity = 'model';
    m.isEnabled = !isHidden;
    m.priceTier = `${Math.min(Math.max(priceTier, 0), 3)}`;
    m.source = 'localUser';
    m.updatedAt = nowIso();
    return m;
  }

  static findModel(snapshot: AIConfigSnapshot, modelId: string): LocalModel | undefined {
    for (let i = 0; i < snapshot.models.length; i++) {
      if (snapshot.models[i].id === modelId) {
        return snapshot.models[i];
      }
    }
    return undefined;
  }

  static findProvider(snapshot: AIConfigSnapshot, providerId: string): LocalProvider | undefined {
    for (let i = 0; i < snapshot.providers.length; i++) {
      if (snapshot.providers[i].id === providerId) {
        return snapshot.providers[i];
      }
    }
    return undefined;
  }
}

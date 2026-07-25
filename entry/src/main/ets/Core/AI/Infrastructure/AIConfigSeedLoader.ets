import {
  AIConfigSnapshot,
  AIUserPreferences,
  LocalModel,
  LocalProvider,
  LocalScenarioBinding,
  LocalSmallTask,
  ModelCapabilities,
  normalizeProviderId,
  nowIso,
  AIScenario
} from '../Domain/AIConfigModels';
import { LOCAL_COMPANY, LOCAL_PROVIDER_ID } from '../Domain/AILocalProviderIds';
import { AIConfigSchema } from './AIConfigSchema';

export class AISeedValidationError extends Error {
  code: string = '';
  detail: string = '';

  constructor(code: string, detail: string) {
    super(`seed:${code}:${detail}`);
    this.code = code;
    this.detail = detail;
    this.name = 'AISeedValidationError';
  }
}

type JsonRec = Record<string, Object | string | number | boolean | null>;

/**
 * 种子解析：以 iOS rawfile/ai/source/AISettings/{APIKeys,AllModels}.json 为唯一输入源。
 */
export class AIConfigSeedLoader {
  static parseIOSSourceBundle(apiKeysJson: string, allModelsJson: string, accountId: number): AIConfigSnapshot {
    const providers = AIConfigSeedLoader.parseIOSProviders(apiKeysJson);
    const iosModelRows = AIConfigSeedLoader.requireArray(allModelsJson, 'AllModels.json');
    const models = AIConfigSeedLoader.parseIOSModels(iosModelRows, providers);
    const bindings = AIConfigSeedLoader.buildBindings(models, iosModelRows);
    const snap = new AIConfigSnapshot();
    snap.schemaVersion = 1;
    snap.accountId = accountId;
    snap.source = 'local';
    snap.syncState = 'localReady';
    snap.seedVersion = AIConfigSchema.SEED_VERSION;
    snap.updatedAt = nowIso();
    snap.providers = providers;
    snap.models = models;
    snap.scenarioBindings = bindings;
    snap.smallTasks = [];
    snap.preferences = new AIUserPreferences();
    snap.preferences.defaultSource = 'auto';
    snap.preferences.allowNetwork = true;
    snap.preferences.allowLocalModel = true;
    snap.preferences.updatedAt = nowIso();
    snap.modelFiles = [];
    return snap;
  }

  /** 测试注入：规范化 providers/models/bindings JSON。 */
  static parseSeedBundle(
    providersJson: string,
    modelsJson: string,
    bindingsJson: string,
    tasksJson: string,
    prefsJson: string,
    accountId: number
  ): AIConfigSnapshot {
    const snap = new AIConfigSnapshot();
    snap.schemaVersion = 1;
    snap.accountId = accountId;
    snap.source = 'local';
    snap.syncState = 'localReady';
    snap.seedVersion = AIConfigSchema.SEED_VERSION;
    snap.updatedAt = nowIso();
    snap.providers = AIConfigSeedLoader.parseNormalizedProviders(providersJson);
    snap.models = AIConfigSeedLoader.parseNormalizedModels(modelsJson);
    snap.scenarioBindings = AIConfigSeedLoader.parseBindings(bindingsJson);
    snap.smallTasks = AIConfigSeedLoader.parseTasks(tasksJson);
    snap.preferences = AIConfigSeedLoader.parsePrefs(prefsJson);
    snap.modelFiles = [];
    return snap;
  }

  static parseIOSProviders(json: string): LocalProvider[] {
    const rows = AIConfigSeedLoader.requireArray(json, 'APIKeys.json');
    const result: LocalProvider[] = [];
    const seen: Set<string> = new Set();
    const ts = nowIso();

    for (let i = 0; i < rows.length; i++) {
      const row = AIConfigSeedLoader.asRecord(rows[i], `APIKeys[${i}]`);
      const company = AIConfigSeedLoader.requiredText(row, 'company', `APIKeys[${i}]`);
      const rawUrl = AIConfigSeedLoader.optionalText(row, 'requestURL')
        || AIConfigSeedLoader.optionalText(row, 'requestUrl');
      const isLocal = company.toUpperCase() === LOCAL_COMPANY
        || (rawUrl !== undefined && rawUrl.toUpperCase() === LOCAL_COMPANY);
      // 本地模型使用稳定 ID local:device；远端种子仍用 seed:<COMPANY>
      const id = isLocal ? LOCAL_PROVIDER_ID : `seed:${normalizeProviderId(company)}`;
      if (seen.has(id)) {
        throw new AISeedValidationError('duplicate_provider', id);
      }
      seen.add(id);

      const p = new LocalProvider();
      p.id = id;
      p.name = AIConfigSeedLoader.optionalText(row, 'name') || company;
      p.company = company;
      // iOS 种子含 LOCAL 占位供应商：非 HTTP URL，映射为 local，不写 requestUrl / secretRef
      if (isLocal) {
        p.kind = 'local';
        p.requestUrl = undefined;
        p.secretRef = undefined;
      } else {
        p.kind = 'api';
        if (rawUrl && rawUrl.length > 0) {
          if (rawUrl.indexOf('https://') === 0 || rawUrl.indexOf('http://') === 0) {
            p.requestUrl = rawUrl;
          } else {
            // 非法 URL 不阻断整库灌种：保留 Provider，清空 endpoint
            p.requestUrl = undefined;
          }
        }
      }
      // Key 为空或占位：不写 HUKS，仅创建未配置密钥的 Provider。
      // iOS APIKeys.json 默认 isEnabled=false，故 seed 后 Runtime effectiveDefaults 常为 0，属预期。
      p.secretRef = undefined;
      p.isEnabled = AIConfigSeedLoader.bool(row, 'isEnabled', false);
      p.position = i;
      p.source = 'localSeed';
      p.updatedAt = ts;
      result.push(p);
    }
    return result;
  }

  static parseIOSModels(rows: Object[], providers: LocalProvider[]): LocalModel[] {
    const providerCompanies: Set<string> = new Set();
    for (let i = 0; i < providers.length; i++) {
      providerCompanies.add(providers[i].company.toUpperCase());
    }
    const result: LocalModel[] = [];
    const seen: Set<string> = new Set();
    const ts = nowIso();

    for (let i = 0; i < rows.length; i++) {
      const row = AIConfigSeedLoader.asRecord(rows[i], `AllModels[${i}]`);
      const name = AIConfigSeedLoader.requiredText(row, 'name', `AllModels[${i}]`);
      const company = AIConfigSeedLoader.requiredText(row, 'company', `AllModels[${i}]`);
      if (!providerCompanies.has(company.toUpperCase())) {
        throw new AISeedValidationError('model_provider_missing', `${company}:${name}`);
      }
      const providerId = company.toUpperCase() === LOCAL_COMPANY
        ? LOCAL_PROVIDER_ID
        : `seed:${normalizeProviderId(company)}`;
      const modelId = `${providerId}:${name}`;
      if (seen.has(modelId)) {
        throw new AISeedValidationError('duplicate_model', modelId);
      }
      seen.add(modelId);

      const model = new LocalModel();
      model.id = modelId;
      model.name = name;
      model.displayName = AIConfigSeedLoader.optionalText(row, 'displayName') || name;
      model.providerId = providerId;
      model.modelType = 'remote';
      model.identity = AIConfigSeedLoader.optionalText(row, 'identity') || 'model';
      model.isEnabled = AIConfigSeedLoader.bool(row, 'isEnabled', true);
      model.source = 'localSeed';
      // LOCAL 公司下的模型挂在 local:device；文件态由 modelFiles 决定，不在此强制 gguf
      const base = AIConfigSeedLoader.optionalText(row, 'baseModelName');
      if (base) {
        model.baseModelName = base;
      }
      model.capabilities = ModelCapabilities.fromRecord(row);
      model.priceTier = AIConfigSeedLoader.optionalTextAny(row, ['priceTier', 'price']);
      model.systemProvision = AIConfigSeedLoader.optionalText(row, 'systemProvision');
      model.icon = AIConfigSeedLoader.optionalText(row, 'icon');
      model.briefDescription = AIConfigSeedLoader.optionalText(row, 'briefDescription');
      model.updatedAt = ts;
      result.push(model);
    }
    return result;
  }

  static buildBindings(models: LocalModel[], iosRows: Object[]): LocalScenarioBinding[] {
    const result: LocalScenarioBinding[] = [];
    const defaultByScenario: Map<string, string> = new Map();
    const positionByScenario: Map<string, number> = new Map();
    const ts = nowIso();

    for (let i = 0; i < iosRows.length; i++) {
      const row = AIConfigSeedLoader.asRecord(iosRows[i], `AllModels[${i}]`);
      const name = AIConfigSeedLoader.requiredText(row, 'name', `AllModels[${i}]`);
      const company = AIConfigSeedLoader.requiredText(row, 'company', `AllModels[${i}]`);
      const modelId = `seed:${normalizeProviderId(company)}:${name}`;
      const scenarios = AIConfigSeedLoader.stringArray(row, 'aiScenarios');
      const temp = AIConfigSeedLoader.optNum(row, 'temperature');
      const maxTokens = AIConfigSeedLoader.optNum(row, 'maxTokens')
        ?? AIConfigSeedLoader.optNum(row, 'max_tokens');
      const systemProvision = AIConfigSeedLoader.optionalText(row, 'systemProvision');

      for (let j = 0; j < scenarios.length; j++) {
        const scenario = scenarios[j];
        if (!AIScenario.isKnown(scenario)) {
          continue;
        }
        const binding = new LocalScenarioBinding();
        binding.scenario = scenario;
        binding.modelId = modelId;
        const pos = positionByScenario.get(scenario) ?? 0;
        binding.position = pos;
        positionByScenario.set(scenario, pos + 1);
        binding.enabled = true;
        binding.source = 'localSeed';
        binding.isDefault = !defaultByScenario.has(scenario);
        if (binding.isDefault) {
          defaultByScenario.set(scenario, modelId);
        }
        binding.temperature = temp ?? 0.68;
        binding.maxTokens = maxTokens ?? 12800;
        if (systemProvision) {
          binding.systemProvision = systemProvision;
        }
        binding.updatedAt = ts;
        result.push(binding);
      }
    }
    // 引用完整性：binding.modelId 必须存在
    const modelIds: Set<string> = new Set();
    for (let i = 0; i < models.length; i++) {
      modelIds.add(models[i].id);
    }
    for (let i = 0; i < result.length; i++) {
      if (!modelIds.has(result[i].modelId)) {
        throw new AISeedValidationError('binding_model_missing', result[i].modelId);
      }
    }
    return result;
  }

  // --- helpers ---

  static requireArray(json: string, label: string): Object[] {
    let parsed: Object;
    try {
      parsed = JSON.parse(json) as Object;
    } catch (_e) {
      throw new AISeedValidationError('json_parse', label);
    }
    if (!Array.isArray(parsed)) {
      throw new AISeedValidationError('not_array', label);
    }
    return parsed as Object[];
  }

  static asRecord(value: Object, label: string): JsonRec {
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      throw new AISeedValidationError('not_object', label);
    }
    return value as JsonRec;
  }

  static requiredText(row: JsonRec, key: string, label: string): string {
    const v = row[key];
    if (v === null || v === undefined) {
      throw new AISeedValidationError('missing_field', `${label}.${key}`);
    }
    const s = `${v}`.trim();
    if (s.length === 0) {
      throw new AISeedValidationError('empty_field', `${label}.${key}`);
    }
    return s;
  }

  static optionalText(row: JsonRec, key: string): string | undefined {
    const v = row[key];
    if (v === null || v === undefined) {
      return undefined;
    }
    const s = `${v}`.trim();
    return s.length > 0 ? s : undefined;
  }

  static optionalTextAny(row: JsonRec, keys: string[]): string | undefined {
    for (let i = 0; i < keys.length; i++) {
      const s = AIConfigSeedLoader.optionalText(row, keys[i]);
      if (s !== undefined) {
        return s;
      }
    }
    return undefined;
  }

  static bool(row: JsonRec, key: string, fallback: boolean): boolean {
    const v = row[key];
    if (typeof v === 'boolean') {
      return v;
    }
    return fallback;
  }

  static boolAny(row: JsonRec, keys: string[], fallback: boolean): boolean {
    for (let i = 0; i < keys.length; i++) {
      const v = row[keys[i]];
      if (typeof v === 'boolean') {
        return v;
      }
    }
    return fallback;
  }

  static optNum(row: JsonRec, key: string): number | undefined {
    const v = row[key];
    if (typeof v === 'number' && !Number.isNaN(v)) {
      return v;
    }
    if (typeof v === 'string' && v.length > 0) {
      const n = Number(v);
      return Number.isNaN(n) ? undefined : n;
    }
    return undefined;
  }

  static stringArray(row: JsonRec, key: string): string[] {
    const v = row[key];
    if (!Array.isArray(v)) {
      return [];
    }
    const arr = v as Object[];
    const out: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      if (arr[i] !== null && arr[i] !== undefined) {
        const s = `${arr[i]}`.trim();
        if (s.length > 0) {
          out.push(s);
        }
      }
    }
    return out;
  }

  static assertHttpUrl(url: string, label: string): void {
    if (url.indexOf('https://') !== 0 && url.indexOf('http://') !== 0) {
      throw new AISeedValidationError('invalid_url', label);
    }
  }

  private static parseNormalizedProviders(json: string): LocalProvider[] {
    const arr = AIConfigSeedLoader.parseArraySafe(json);
    const out: LocalProvider[] = [];
    const ts = nowIso();
    for (let i = 0; i < arr.length; i++) {
      const o = arr[i] as JsonRec;
      const p = new LocalProvider();
      const company = `${o['company'] ?? ''}`;
      p.id = `${o['id'] ?? `seed:${normalizeProviderId(company)}`}`;
      p.name = `${o['name'] ?? p.id}`;
      p.company = company;
      p.kind = 'api';
      const url = o['requestUrl'] ?? o['requestURL'];
      if (url !== null && url !== undefined) {
        p.requestUrl = `${url}`;
      }
      p.isEnabled = o['isEnabled'] === true;
      p.position = typeof o['position'] === 'number' ? o['position'] as number : i;
      p.source = 'localSeed';
      p.updatedAt = ts;
      out.push(p);
    }
    return out;
  }

  private static parseNormalizedModels(json: string): LocalModel[] {
    const arr = AIConfigSeedLoader.parseArraySafe(json);
    const out: LocalModel[] = [];
    const ts = nowIso();
    for (let i = 0; i < arr.length; i++) {
      const o = arr[i] as JsonRec;
      const m = new LocalModel();
      const company = `${o['company'] ?? ''}`;
      const name = `${o['name'] ?? ''}`;
      const providerId = `${o['providerId'] ?? `seed:${normalizeProviderId(company)}`}`;
      m.id = `${o['id'] ?? `${providerId}:${name}`}`;
      m.name = name;
      m.displayName = `${o['displayName'] ?? name}`;
      m.providerId = providerId;
      m.modelType = 'remote';
      const caps = o['capabilities'];
      if (caps && typeof caps === 'object') {
        m.capabilities = ModelCapabilities.fromRecord(caps as JsonRec);
      } else {
        m.capabilities = ModelCapabilities.fromRecord(o);
      }
      m.isEnabled = o['isEnabled'] !== false;
      m.source = 'localSeed';
      m.identity = `${o['identity'] ?? 'model'}`;
      m.updatedAt = ts;
      out.push(m);
    }
    return out;
  }

  private static parseBindings(json: string): LocalScenarioBinding[] {
    const arr = AIConfigSeedLoader.parseArraySafe(json);
    const out: LocalScenarioBinding[] = [];
    const ts = nowIso();
    for (let i = 0; i < arr.length; i++) {
      const o = arr[i] as JsonRec;
      const scenario = `${o['scenario'] ?? ''}`;
      if (!AIScenario.isKnown(scenario)) {
        continue;
      }
      const b = new LocalScenarioBinding();
      b.scenario = scenario;
      b.modelId = `${o['modelId'] ?? ''}`;
      if (typeof o['temperature'] === 'number') {
        b.temperature = o['temperature'] as number;
      }
      if (typeof o['maxTokens'] === 'number') {
        b.maxTokens = o['maxTokens'] as number;
      }
      b.isDefault = o['isDefault'] === true;
      b.position = typeof o['position'] === 'number' ? o['position'] as number : 0;
      b.enabled = o['enabled'] !== false;
      b.source = 'localSeed';
      b.updatedAt = ts;
      if (b.modelId.length > 0) {
        out.push(b);
      }
    }
    return out;
  }

  private static parseTasks(json: string): LocalSmallTask[] {
    const arr = AIConfigSeedLoader.parseArraySafe(json);
    const out: LocalSmallTask[] = [];
    const ts = nowIso();
    for (let i = 0; i < arr.length; i++) {
      const o = arr[i] as JsonRec;
      const t = new LocalSmallTask();
      t.code = `${o['code'] ?? ''}`;
      t.name = `${o['name'] ?? t.code}`;
      t.prompt = `${o['prompt'] ?? ''}`;
      t.source = 'Local';
      t.isEnabled = o['isEnabled'] !== false && o['enabled'] !== false;
      t.updatedAt = ts;
      if (t.code.length > 0) {
        out.push(t);
      }
    }
    return out;
  }

  private static parsePrefs(json: string): AIUserPreferences {
    const p = new AIUserPreferences();
    p.updatedAt = nowIso();
    try {
      const o = JSON.parse(json) as JsonRec;
      const ds = `${o['defaultSource'] ?? 'auto'}`;
      if (ds === 'local' || ds === 'pro' || ds === 'auto') {
        p.defaultSource = ds;
      }
      p.allowNetwork = o['allowNetwork'] !== false;
      p.allowLocalModel = o['allowLocalModel'] !== false;
    } catch (_e) {
      // defaults
    }
    return p;
  }

  private static parseArraySafe(json: string): Object[] {
    try {
      const parsed = JSON.parse(json) as Object;
      if (Array.isArray(parsed)) {
        return parsed as Object[];
      }
    } catch (_e) {
      // ignore
    }
    return [];
  }
}

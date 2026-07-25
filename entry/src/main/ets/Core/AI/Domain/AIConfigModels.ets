/** AI 配置领域模型：本地 / Pro / 统一消费。场景 wire 值对齐 SparkService ScenarioKey。 */

export type AIConfigSource = 'localSeed' | 'localUser' | 'pro' | 'trial' | 'merged' | 'local' | 'system';
export type AIProviderKind = 'api' | 'local';
export type AIModelType = 'remote' | 'gguf';
export type AIDefaultSource = 'local' | 'pro' | 'auto';
export type AIModelFileState = 'missing' | 'downloading' | 'ready' | 'failed';
export type AISyncState =
  | 'uninitialized'
  | 'empty'
  | 'seeding'
  | 'localReady'
  | 'draft'
  | 'refreshing'
  | 'remoteReady'
  | 'degraded'
  | 'invalidated';

export class AIScenario {
  static readonly CHAT: string = 'chat';
  static readonly EMBEDDING: string = 'embedding';
  static readonly VOICE: string = 'voice';
  static readonly MEDICAL_STRUCTURED_EXTRACTION: string = 'medical_structured_extraction';
  static readonly MEDICAL_DOCUMENT_TYPE_RECOGNITION: string = 'medical_document_type_recognition';
  static readonly MEDICAL_CASE_EXTRACTION: string = 'medical_case_extraction';
  static readonly HEALTH_EXAM_EXTRACTION: string = 'health_exam_extraction';
  static readonly MEDICAL_REPORT_EXTRACTION: string = 'medical_report_extraction';
  static readonly PRESCRIPTION_EXTRACTION: string = 'prescription_extraction';
  static readonly MEDICATION_EXTRACTION: string = 'medication_extraction';
  static readonly MEDICINE_BOX_EXTRACTION: string = 'medicine_box_extraction';
  static readonly OPTIMIZATION_TEXT: string = 'optimization_text';
  static readonly OPTIMIZATION_VISUAL: string = 'optimization_visual';
  static readonly CONTEXT_FOLDING: string = 'context_folding';
  static readonly ROUTER: string = 'router';
  static readonly MODEL_CONFIG: string = 'model_config';
  static readonly REPORT_INTERPRETATION: string = 'report_interpretation';
  static readonly NUTRITION_INTAKE_EXTRACTION: string = 'nutrition_intake_extraction';
  static readonly MEDICAL_EXAM_PLAN_GENERATION: string = 'medical_exam_plan_generation';

  static allKnown(): string[] {
    return [
      AIScenario.CHAT,
      AIScenario.EMBEDDING,
      AIScenario.VOICE,
      AIScenario.MEDICAL_STRUCTURED_EXTRACTION,
      AIScenario.MEDICAL_DOCUMENT_TYPE_RECOGNITION,
      AIScenario.MEDICAL_CASE_EXTRACTION,
      AIScenario.HEALTH_EXAM_EXTRACTION,
      AIScenario.MEDICAL_REPORT_EXTRACTION,
      AIScenario.PRESCRIPTION_EXTRACTION,
      AIScenario.MEDICATION_EXTRACTION,
      AIScenario.MEDICINE_BOX_EXTRACTION,
      AIScenario.OPTIMIZATION_TEXT,
      AIScenario.OPTIMIZATION_VISUAL,
      AIScenario.CONTEXT_FOLDING,
      AIScenario.ROUTER,
      AIScenario.MODEL_CONFIG,
      AIScenario.REPORT_INTERPRETATION,
      AIScenario.NUTRITION_INTAKE_EXTRACTION,
      AIScenario.MEDICAL_EXAM_PLAN_GENERATION
    ];
  }

  static isKnown(raw: string): boolean {
    return AIScenario.allKnown().indexOf(raw) >= 0;
  }
}

export class ModelCapabilities {
  supportsText: boolean = false;
  supportsSearch: boolean = false;
  supportsMultimodal: boolean = false;
  supportsReasoning: boolean = false;
  supportsToolUse: boolean = false;
  supportsVoiceGen: boolean = false;
  supportsImageGen: boolean = false;
  supportsDeepReasoning: boolean = false;
  reasoningControllable: boolean = false;

  static empty(): ModelCapabilities {
    return new ModelCapabilities();
  }

  static fromRecord(obj: Record<string, Object | string | number | boolean | null>): ModelCapabilities {
    const c = new ModelCapabilities();
    c.supportsText = ModelCapabilities.readBool(obj, ['supportsText', 'supports_text', 'supportsTextGen']);
    c.supportsSearch = ModelCapabilities.readBool(obj, ['supportsSearch', 'supports_search']);
    c.supportsMultimodal = ModelCapabilities.readBool(obj, ['supportsMultimodal', 'supports_multimodal']);
    c.supportsReasoning = ModelCapabilities.readBool(obj, ['supportsReasoning', 'supports_reasoning']);
    c.supportsToolUse = ModelCapabilities.readBool(obj, ['supportsToolUse', 'supports_tool_use']);
    c.supportsVoiceGen = ModelCapabilities.readBool(obj, ['supportsVoiceGen', 'supports_voice_gen']);
    c.supportsImageGen = ModelCapabilities.readBool(obj, ['supportsImageGen', 'supports_image_gen']);
    c.supportsDeepReasoning = ModelCapabilities.readBool(obj, [
      'supportsDeepReasoning',
      'supports_deep_reasoning'
    ]);
    c.reasoningControllable = ModelCapabilities.readBool(obj, [
      'reasoningControllable',
      'reasoning_controllable',
      'supportReasoningChange'
    ]);
    return c;
  }

  toJson(): string {
    const o: Record<string, boolean> = {
      'supportsText': this.supportsText,
      'supportsSearch': this.supportsSearch,
      'supportsMultimodal': this.supportsMultimodal,
      'supportsReasoning': this.supportsReasoning,
      'supportsToolUse': this.supportsToolUse,
      'supportsVoiceGen': this.supportsVoiceGen,
      'supportsImageGen': this.supportsImageGen,
      'supportsDeepReasoning': this.supportsDeepReasoning,
      'reasoningControllable': this.reasoningControllable
    };
    return JSON.stringify(o);
  }

  static fromJson(json: string): ModelCapabilities {
    if (!json || json.length === 0) {
      return ModelCapabilities.empty();
    }
    try {
      return ModelCapabilities.fromRecord(JSON.parse(json) as Record<string, Object | string | number | boolean | null>);
    } catch (_e) {
      return ModelCapabilities.empty();
    }
  }

  private static readBool(
    obj: Record<string, Object | string | number | boolean | null>,
    keys: string[]
  ): boolean {
    for (let i = 0; i < keys.length; i++) {
      const v = obj[keys[i]];
      if (typeof v === 'boolean') {
        return v;
      }
    }
    return false;
  }
}

export class LocalProvider {
  id: string = '';
  name: string = '';
  company: string = '';
  kind: AIProviderKind = 'api';
  requestUrl?: string;
  secretRef?: string;
  isEnabled: boolean = true;
  position: number = 0;
  source: string = 'localSeed';
  updatedAt: string = '';
}

export class LocalModel {
  id: string = '';
  name: string = '';
  displayName: string = '';
  providerId: string = '';
  baseModelName?: string;
  modelType: AIModelType = 'remote';
  capabilities: ModelCapabilities = ModelCapabilities.empty();
  contextWindow?: number;
  priceTier?: string;
  isDefault: boolean = false;
  isEnabled: boolean = true;
  source: string = 'localSeed';
  identity: string = 'model';
  systemProvision?: string;
  icon?: string;
  briefDescription?: string;
  /** 对标 iOS AllModels.aiToolScenarios / selectedToolNames */
  aiToolScenarios: string[] = [];
  /** 对标 iOS AllModels.relatedTaskCodes */
  relatedTaskCodes: string[] = [];
  updatedAt: string = '';
}

export class LocalScenarioBinding {
  scenario: string = '';
  modelId: string = '';
  temperature?: number;
  maxTokens?: number;
  systemProvision?: string;
  isDefault: boolean = false;
  position: number = 0;
  enabled: boolean = true;
  source: string = 'localSeed';
  /** 工具场景摘要 */
  aiToolScenarios: string[] = [];
  /** 关联小任务 code */
  relatedTaskCodes: string[] = [];
  updatedAt: string = '';
}

export class LocalSmallTask {
  code: string = '';
  name: string = '';
  brief?: string;
  prompt: string = '';
  icon?: string;
  toolList: string[] = [];
  source: string = 'Local';
  isEnabled: boolean = true;
  updatedAt: string = '';
}

export class AIUserPreferences {
  defaultSource: AIDefaultSource = 'auto';
  allowNetwork: boolean = true;
  allowLocalModel: boolean = true;
  selectedProviderId?: string;
  selectedModelId?: string;
  lastRemoteRevision?: string;
  /**
   * 每场景来源偏好：scenario -> 'local' | 'pro' | 'auto'
   * 序列化进 RDB extras_json，缺省回退 defaultSource。
   */
  scenarioSources: Record<string, AIDefaultSource> = {};
  updatedAt: string = '';
}

export class LocalModelFile {
  modelId: string = '';
  path: string = '';
  sizeBytes: number = 0;
  sha256: string = '';
  downloadState: AIModelFileState = 'missing';
  downloadedAt?: string;
  errorCode?: string;
  updatedAt: string = '';
}

export class AIConfigSnapshot {
  schemaVersion: number = 1;
  accountId: number = 0;
  revision?: string;
  source: string = 'local';
  providers: LocalProvider[] = [];
  models: LocalModel[] = [];
  scenarioBindings: LocalScenarioBinding[] = [];
  smallTasks: LocalSmallTask[] = [];
  preferences: AIUserPreferences = new AIUserPreferences();
  modelFiles: LocalModelFile[] = [];
  syncState: AISyncState = 'empty';
  seedVersion?: number;
  remoteEtag?: string;
  updatedAt: string = '';
}

export class ProScenarioModelRow {
  name: string = '';
  displayName: string = '';
  identity: string = 'model';
  baseModelName?: string;
  company: string = '';
  endpoint?: string;
  /** 仅内存短生命周期；落盘前必须转 secretRef */
  apiKey?: string;
  capabilities: ModelCapabilities = ModelCapabilities.empty();
  priceTier?: string;
  systemProvision?: string;
  icon?: string;
  briefDescription?: string;
  aiScenarios: string[] = [];
  aiToolScenarios: string[] = [];
  relatedTaskCodes: string[] = [];
  source: string = 'pro';
  isDefault: boolean = false;
  temperature?: number;
  maxTokens?: number;
  isTrial: boolean = false;
}

export class ProScenarioBundle {
  scenario: string = '';
  defaultModel: string = '';
  models: ProScenarioModelRow[] = [];
}

export class ProSmallTask {
  code: string = '';
  name: string = '';
  brief?: string;
  prompt: string = '';
  icon?: string;
  toolList: string[] = [];
  source: string = 'Service';
  isDeleted: boolean = false;
}

export class AITrialStatus {
  status?: string;
  isActive?: boolean;
  grantSource?: string;
  startedAt?: string;
  expiresAt?: string;
  remainingSeconds?: number;
  note?: string;
}

export class ProBootstrapSnapshot {
  revision: string = '';
  scenarios: ProScenarioBundle[] = [];
  smallTasks: ProSmallTask[] = [];
  trialStatus?: AITrialStatus;
  trialMessage?: string;
  /** 原始 ETag（若网络层提供） */
  etag?: string;
}

export class AIResolvedConfig {
  scenario: string = '';
  source: string = 'local';
  providerId: string = '';
  modelId: string = '';
  modelName: string = '';
  endpoint?: string;
  secretRef?: string;
  capabilities: ModelCapabilities = ModelCapabilities.empty();
  temperature?: number;
  maxTokens?: number;
  systemProvision?: string;
  relatedTaskCodes: string[] = [];
  revision?: string;
  isTrial: boolean = false;
  isReady: boolean = false;
  modelType: AIModelType = 'remote';
  company: string = '';
}

export class ResolvedSmallTask {
  code: string = '';
  name: string = '';
  brief?: string;
  prompt: string = '';
  toolList: string[] = [];
  source: string = 'Local';
  isEnabled: boolean = true;
}

export class RuntimeProviderRef {
  providerId: string = '';
  company: string = '';
  kind: AIProviderKind = 'api';
  requestUrl?: string;
  secretRef?: string;
  isEnabled: boolean = true;
  source: string = 'local';
}

export class RuntimeSnapshot {
  accountId: number = 0;
  /** 内存发布代际；切号/重建时递增，异步回调需比对 */
  generation: number = 0;
  state: AISyncState = 'empty';
  localRevision: string = '';
  remoteRevision?: string;
  scenarios: Map<string, AIResolvedConfig[]> = new Map();
  effectiveDefaults: Map<string, string> = new Map();
  smallTasks: Map<string, ResolvedSmallTask> = new Map();
  providers: Map<string, RuntimeProviderRef> = new Map();
  degradeReason?: string;
  createdAt: string = '';
  runtimeSource: string = 'persisted';
}

/** 对齐 iOS AIRuntimeReasoningOptions */
export class AIRuntimeReasoningOptions {
  isEnabled: boolean = false;
  effortTier: number = 0;
  usePromptFallback: boolean = false;

  static disabled(): AIRuntimeReasoningOptions {
    return new AIRuntimeReasoningOptions();
  }

  static enabled(tier: number = 0, promptFallback: boolean = false): AIRuntimeReasoningOptions {
    const o = new AIRuntimeReasoningOptions();
    o.isEnabled = true;
    o.effortTier = tier < 0 ? 0 : (tier > 3 ? 3 : tier);
    o.usePromptFallback = promptFallback;
    return o;
  }
}

export class AIRuntimeToolDefinition {
  name: string = '';
  summary: string = '';
  /** OpenAI function parameters JSON object string */
  parametersJson: string = '{"type":"object","properties":{}}';
  required: string[] = [];
}

export class AIRuntimeToolCall {
  id: string = '';
  name: string = '';
  arguments: string = '';
}

export class AIRuntimeToolCallDelta {
  index: number = 0;
  id?: string;
  name?: string;
  argumentsDelta?: string;
}

export class AIRuntimeImageURLPayload {
  url: string = '';
  detail?: string;
}

/** 对齐 iOS AIRuntimeContentPart；内联 JPEG 使用 spark:inline-jpeg-base64: 前缀 */
export class AIRuntimeContentPart {
  type: string = 'text';
  text?: string;
  imageURL?: AIRuntimeImageURLPayload;

  static textPart(text: string): AIRuntimeContentPart {
    const p = new AIRuntimeContentPart();
    p.type = 'text';
    p.text = text;
    return p;
  }

  static imageUrlPart(url: string, detail?: string): AIRuntimeContentPart {
    const p = new AIRuntimeContentPart();
    p.type = 'image_url';
    const img = new AIRuntimeImageURLPayload();
    img.url = url;
    img.detail = detail;
    p.imageURL = img;
    return p;
  }
}

export class AIRuntimeMessage {
  role: string = 'user';
  content?: string;
  contentParts?: AIRuntimeContentPart[];
  toolCalls?: AIRuntimeToolCall[];
  toolCallID?: string;
  name?: string;
  reasoningContent?: string;

  /** 本地/纯文本路径：抽取可拼接文本 */
  normalizedTextContent(): string {
    if (this.contentParts !== undefined && this.contentParts.length > 0) {
      const parts: string[] = [];
      for (let i = 0; i < this.contentParts.length; i++) {
        const part = this.contentParts[i];
        if (part.type === 'text' && part.text !== undefined && part.text.length > 0) {
          parts.push(part.text);
        }
      }
      return parts.join('\n');
    }
    return this.content ?? '';
  }
}

export class AIRuntimeTextRequest {
  requestId: string = '';
  scenario: string = AIScenario.CHAT;
  messages: AIRuntimeMessage[] = [];
  tools: AIRuntimeToolDefinition[] = [];
  toolChoice: string = 'auto';
  reasoning: AIRuntimeReasoningOptions = AIRuntimeReasoningOptions.disabled();
  stream: boolean = false;
  preferredSource?: string;
  preferredModelName?: string;
  providerCompanyUppercased?: string;
  temperature?: number;
  topP?: number;
  maxTokens?: number;
  timeoutMs: number = 60000;
  accountId: number = 0;
  /** 由调用方持有；cancel(requestId) 与令牌双通道 */
  cancellationToken?: Object;
}

export class AIRuntimeUsage {
  promptTokens: number = 0;
  completionTokens: number = 0;
  totalTokens: number = 0;
}

export class AIRuntimeResponse {
  requestId: string = '';
  text: string = '';
  reasoningText?: string;
  finishReason: string = 'stop';
  usage: AIRuntimeUsage = new AIRuntimeUsage();
  source: string = 'local';
  modelId: string = '';
  modelName: string = '';
  toolCalls: AIRuntimeToolCall[] = [];
  isDegraded: boolean = false;
  createdAt: string = '';
  errorCode?: string;
  errorMessage?: string;

  get hasToolCalls(): boolean {
    return this.toolCalls.length > 0;
  }
}

export type AIRuntimeEventKind =
  | 'started'
  | 'textDelta'
  | 'reasoningDelta'
  | 'delta'
  | 'toolCall'
  | 'progress'
  | 'completed'
  | 'failed'
  | 'cancelled';

export class AIRuntimeEvent {
  kind: AIRuntimeEventKind = 'started';
  requestId: string = '';
  deltaText?: string;
  reasoningDelta?: string;
  toolCallDelta?: AIRuntimeToolCallDelta;
  response?: AIRuntimeResponse;
  errorCode?: string;
  errorMessage?: string;
}

/** 流式事件回调（对齐 iOS AsyncThrowingStream 消费者） */
export type AIRuntimeEventHandler = (event: AIRuntimeEvent) => void;

export class SeedResult {
  status: string = 'alreadySeeded';
  seedVersion: number = 0;
}

export class RefreshResult {
  state: AISyncState = 'degraded';
  revision?: string;
  reason?: string;
  snapshot?: ProBootstrapSnapshot;
}

export function normalizeProviderId(company: string): string {
  const upper = (company || '').toUpperCase();
  let out = '';
  for (let i = 0; i < upper.length; i++) {
    const ch = upper.charAt(i);
    const code = upper.charCodeAt(i);
    const isAZ = code >= 65 && code <= 90;
    const is09 = code >= 48 && code <= 57;
    if (isAZ || is09 || ch === '_' || ch === '-') {
      out += ch;
    }
  }
  return out.length > 0 ? out : 'UNKNOWN';
}

export function nowIso(): string {
  return new Date().toISOString();
}

export function makeLocalRevision(updatedAt: string, hashHint: string): string {
  return `local-${updatedAt}-${hashHint}`;
}

export function hydrateSnapshot(raw: AIConfigSnapshot): AIConfigSnapshot {
  const snap = new AIConfigSnapshot();
  snap.schemaVersion = raw.schemaVersion ?? 1;
  snap.accountId = raw.accountId ?? 0;
  snap.revision = raw.revision;
  snap.source = raw.source ?? 'local';
  snap.syncState = raw.syncState ?? 'empty';
  snap.seedVersion = raw.seedVersion;
  snap.remoteEtag = raw.remoteEtag;
  snap.updatedAt = raw.updatedAt ?? nowIso();

  // Provider 深拷贝，避免草稿与持久快照共享引用
  snap.providers = [];
  const providers = raw.providers ?? [];
  for (let i = 0; i < providers.length; i++) {
    const src = providers[i];
    const p = new LocalProvider();
    p.id = src.id;
    p.name = src.name;
    p.company = src.company;
    p.kind = src.kind === 'local' ? 'local' : 'api';
    p.requestUrl = src.requestUrl;
    p.secretRef = src.secretRef;
    p.isEnabled = src.isEnabled;
    p.position = src.position;
    p.source = src.source;
    p.updatedAt = src.updatedAt;
    snap.providers.push(p);
  }

  snap.scenarioBindings = [];
  const bindings = raw.scenarioBindings ?? [];
  for (let i = 0; i < bindings.length; i++) {
    const src = bindings[i];
    const b = new LocalScenarioBinding();
    b.scenario = src.scenario;
    b.modelId = src.modelId;
    b.temperature = src.temperature;
    b.maxTokens = src.maxTokens;
    b.systemProvision = src.systemProvision;
    b.isDefault = src.isDefault;
    b.position = src.position;
    b.enabled = src.enabled;
    b.source = src.source;
    b.relatedTaskCodes = src.relatedTaskCodes ? src.relatedTaskCodes.slice() : [];
    b.aiToolScenarios = src.aiToolScenarios ? src.aiToolScenarios.slice() : [];
    b.updatedAt = src.updatedAt;
    snap.scenarioBindings.push(b);
  }

  snap.smallTasks = [];
  const tasks = raw.smallTasks ?? [];
  for (let i = 0; i < tasks.length; i++) {
    const src = tasks[i];
    const t = new LocalSmallTask();
    t.code = src.code;
    t.name = src.name;
    t.brief = src.brief;
    t.prompt = src.prompt;
    t.icon = src.icon;
    t.toolList = src.toolList ? src.toolList.slice() : [];
    t.source = src.source;
    t.isEnabled = src.isEnabled;
    t.updatedAt = src.updatedAt;
    snap.smallTasks.push(t);
  }

  snap.modelFiles = raw.modelFiles ? raw.modelFiles.slice() : [];

  const prefSrc = raw.preferences ?? new AIUserPreferences();
  const prefs = new AIUserPreferences();
  prefs.defaultSource = prefSrc.defaultSource ?? 'auto';
  prefs.allowNetwork = prefSrc.allowNetwork !== false;
  prefs.allowLocalModel = prefSrc.allowLocalModel !== false;
  prefs.selectedProviderId = prefSrc.selectedProviderId;
  prefs.selectedModelId = prefSrc.selectedModelId;
  prefs.updatedAt = prefSrc.updatedAt ?? nowIso();
  prefs.scenarioSources = {};
  // 按已知场景枚举拷贝，避免 Object.keys（ArkTS 限制）
  const scenarioKeys = AIScenario.allKnown();
  for (let i = 0; i < scenarioKeys.length; i++) {
    const k = scenarioKeys[i];
    const v = prefSrc.scenarioSources ? prefSrc.scenarioSources[k] : undefined;
    if (v === 'local' || v === 'pro' || v === 'auto') {
      prefs.scenarioSources[k] = v;
    }
  }
  snap.preferences = prefs;

  snap.models = [];
  const models = raw.models ?? [];
  for (let i = 0; i < models.length; i++) {
    const m = models[i];
    const model = new LocalModel();
    model.id = m.id;
    model.name = m.name;
    model.displayName = m.displayName;
    model.providerId = m.providerId;
    model.baseModelName = m.baseModelName;
    model.modelType = m.modelType === 'gguf' ? 'gguf' : 'remote';
    // JSON round-trip 后 capabilities 是普通对象，没有 toJson；需兼容两种形态
    model.capabilities = hydrateModelCapabilities(m.capabilities);
    model.contextWindow = m.contextWindow;
    model.priceTier = m.priceTier;
    model.isDefault = m.isDefault;
    model.isEnabled = m.isEnabled;
    model.source = m.source;
    model.identity = m.identity;
    model.systemProvision = m.systemProvision;
    model.icon = m.icon;
    model.briefDescription = m.briefDescription;
    model.aiToolScenarios = m.aiToolScenarios ? m.aiToolScenarios.slice() : [];
    model.relatedTaskCodes = m.relatedTaskCodes ? m.relatedTaskCodes.slice() : [];
    model.updatedAt = m.updatedAt;
    snap.models.push(model);
  }
  return snap;
}

/** 兼容 ModelCapabilities 实例 / JSON 普通对象 / 缺省 */
function hydrateModelCapabilities(raw: ModelCapabilities | Object | undefined | null): ModelCapabilities {
  if (raw === undefined || raw === null) {
    return ModelCapabilities.empty();
  }
  const maybe = raw as ModelCapabilities;
  // JSON round-trip 后是普通对象，没有 toJson；直接 fromRecord
  if (typeof maybe.toJson === 'function') {
    try {
      return ModelCapabilities.fromJson(maybe.toJson());
    } catch (_e) {
      return ModelCapabilities.empty();
    }
  }
  return ModelCapabilities.fromRecord(raw as Record<string, Object | string | number | boolean | null>);
}

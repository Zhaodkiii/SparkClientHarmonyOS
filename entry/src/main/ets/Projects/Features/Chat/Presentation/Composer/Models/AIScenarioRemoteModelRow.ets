import {
  AIResolvedConfig,
  AIScenario,
  ProScenarioModelRow,
  RuntimeSnapshot
} from '../../../../../../Core/AI/Domain/AIConfigModels';

export interface AIScenarioConfig {
  endpoint: string;
  model: string;
  apiKey?: string;
  temperature: number;
  maxTokens: number;
}

export enum AIConfigSource {
  PRO_OVERLAY = 'proOverlay',
  LOCAL_CATALOG = 'localCatalog',
  LOCAL_DEFAULT = 'localDefault'
}

export enum AIModelIdentity {
  MODEL = 'model',
  AGENT = 'agent'
}

/** ArkTS 禁止匿名对象作类型声明，构造参数用显式 interface。 */
export interface AIScenarioRemoteModelRowParams {
  name: string;
  displayName: string;
  identity: string;
  providerID?: string;
  company: string;
  endpoint: string;
  apiKey?: string;
  supportsSearch: boolean;
  supportsMultimodal: boolean;
  supportsReasoning: boolean;
  supportsToolUse: boolean;
  supportsVoiceGen: boolean;
  supportsImageGen: boolean;
  supportsText: boolean;
  supportsDeepReasoning: boolean;
  reasoningControllable: boolean;
  priceTier: number;
  systemProvision?: string;
  icon?: string;
  briefDescription?: string;
  source: string;
  aiScenarios: string[];
  aiToolScenarios: string[];
  relatedTaskCodes?: string[];
  isDefault?: boolean;
  temperature?: number;
  maxTokens: number;
  baseModelName?: string;
  localFilename?: string;
}

/** 对标 iOS AIScenarioRemoteModelRow，供模型横滑行使用。 */
export class AIScenarioRemoteModelRow {
  name: string;
  displayName: string;
  identity: string;
  providerID: string;
  company: string;
  endpoint: string;
  apiKey?: string;
  supportsSearch: boolean;
  supportsMultimodal: boolean;
  supportsReasoning: boolean;
  supportsToolUse: boolean;
  supportsVoiceGen: boolean;
  supportsImageGen: boolean;
  supportsText: boolean;
  supportsDeepReasoning: boolean;
  reasoningControllable: boolean;
  priceTier: number;
  systemProvision?: string;
  icon?: string;
  briefDescription?: string;
  source: string;
  aiScenarios: string[];
  aiToolScenarios: string[];
  relatedTaskCodes: string[];
  isDefault: boolean;
  temperature: number;
  maxTokens: number;
  baseModelName?: string;
  localFilename?: string;

  constructor(params: AIScenarioRemoteModelRowParams) {
    this.name = params.name;
    this.displayName = params.displayName;
    this.identity = params.identity;
    this.providerID = normalizeProviderID(params.providerID ?? params.company);
    this.company = params.company;
    this.endpoint = params.endpoint;
    this.apiKey = params.apiKey;
    this.supportsSearch = params.supportsSearch;
    this.supportsMultimodal = params.supportsMultimodal;
    this.supportsReasoning = params.supportsReasoning;
    this.supportsToolUse = params.supportsToolUse;
    this.supportsVoiceGen = params.supportsVoiceGen;
    this.supportsImageGen = params.supportsImageGen;
    this.supportsText = params.supportsText;
    this.supportsDeepReasoning = params.supportsDeepReasoning;
    this.reasoningControllable = params.reasoningControllable;
    this.priceTier = params.priceTier;
    this.systemProvision = params.systemProvision;
    this.icon = params.icon;
    this.briefDescription = params.briefDescription;
    this.source = params.source;
    this.aiScenarios = params.aiScenarios;
    this.aiToolScenarios = params.aiToolScenarios;
    this.relatedTaskCodes = params.relatedTaskCodes ?? [];
    this.isDefault = params.isDefault ?? false;
    this.temperature = params.temperature ?? 0.2;
    this.maxTokens = params.maxTokens;
    this.baseModelName = params.baseModelName;
    this.localFilename = params.localFilename;
  }

  get id(): string {
    return this.name;
  }

  get providerCompany(): string | undefined {
    return this.company === '' ? undefined : this.company;
  }

  get displayTitle(): string {
    const trimmed = this.displayName.trim();
    return trimmed === '' ? this.name : trimmed;
  }

  /**
   * 对应 iOS composerIconSystemName。
   * 自定义 icon 媒体资源未入库前，回退到系统 Symbol；动态 `$r(app.media.x)` 在 ArkTS 不可编译期解析。
   */
  get composerIconResource(): Resource {
    const trimmed = this.icon?.trim() ?? '';
    if (trimmed.length > 0) {
      // 已声明同名 media 时可改为静态 $r('app.media.xxx') 映射表
      return this.identity === AIModelIdentity.AGENT
        ? $r('sys.symbol.person_badge_plus')
        : $r('sys.symbol.square_stack_3d');
    }
    return this.identity === AIModelIdentity.AGENT
      ? $r('sys.symbol.person_badge_plus')
      : $r('sys.symbol.square_stack_3d');
  }

  get systemPrompt(): string | undefined {
    const trimmed = this.systemProvision?.trim();
    return trimmed && trimmed !== '' ? trimmed : undefined;
  }

  asScenarioConfig(): AIScenarioConfig {
    const config: AIScenarioConfig = {
      endpoint: this.endpoint,
      model: this.name,
      apiKey: this.apiKey,
      temperature: this.temperature,
      maxTokens: this.maxTokens
    };
    return config;
  }

  get configSource(): AIConfigSource {
    switch (this.source) {
      case 'pro':
        return AIConfigSource.PRO_OVERLAY;
      case 'system':
      case 'custom':
        return AIConfigSource.LOCAL_CATALOG;
      default:
        return AIConfigSource.LOCAL_DEFAULT;
    }
  }

  /**
   * 从 Runtime chat 候选构造选择器行。
   * name 使用 modelName，与 ScenarioPolicyResolver.pickExact / preferredModelName 一致。
   */
  static fromResolved(config: AIResolvedConfig, isDefault: boolean = false): AIScenarioRemoteModelRow {
    const caps = config.capabilities;
    const identity = AIModelIdentity.MODEL;
    const display = config.modelName.trim().length > 0 ? config.modelName : config.modelId;
    const params: AIScenarioRemoteModelRowParams = {
      name: config.modelName.trim().length > 0 ? config.modelName : config.modelId,
      displayName: display,
      identity: identity,
      providerID: config.providerId,
      company: config.company,
      endpoint: config.endpoint ?? '',
      supportsSearch: caps.supportsSearch,
      supportsMultimodal: caps.supportsMultimodal,
      supportsReasoning: caps.supportsReasoning,
      supportsToolUse: caps.supportsToolUse,
      supportsVoiceGen: caps.supportsVoiceGen,
      supportsImageGen: caps.supportsImageGen,
      supportsText: caps.supportsText,
      supportsDeepReasoning: caps.supportsDeepReasoning,
      reasoningControllable: caps.reasoningControllable,
      priceTier: 0,
      systemProvision: config.systemProvision,
      source: config.source,
      aiScenarios: [config.scenario],
      aiToolScenarios: [],
      relatedTaskCodes: config.relatedTaskCodes.slice(),
      isDefault: isDefault,
      temperature: config.temperature,
      maxTokens: config.maxTokens ?? 4096,
      baseModelName: config.modelId
    };
    return new AIScenarioRemoteModelRow(params);
  }

  /** 取 chat 场景 ready 候选，与发送管线同一事实源。 */
  static fromChatRuntime(runtime: RuntimeSnapshot): AIScenarioRemoteModelRow[] {
    const list = runtime.scenarios.get(AIScenario.CHAT) ?? [];
    const defaultName = runtime.effectiveDefaults.get(AIScenario.CHAT);
    const rows: AIScenarioRemoteModelRow[] = [];
    for (let i = 0; i < list.length; i++) {
      const config = list[i];
      if (!config.isReady) {
        continue;
      }
      const name = config.modelName.trim().length > 0 ? config.modelName : config.modelId;
      const isDefault = defaultName !== undefined && defaultName.length > 0
        ? (name === defaultName || config.modelId === defaultName)
        : i === 0;
      rows.push(AIScenarioRemoteModelRow.fromResolved(config, isDefault));
    }
    return rows;
  }

  /** 对应 Codable decode，从 JSON 构造。 */
  static fromJSON(json: Record<string, Object>): AIScenarioRemoteModelRow {
    const params: AIScenarioRemoteModelRowParams = {
      name: (json['name'] as string) ?? '',
      displayName: (json['displayName'] as string) ?? '',
      identity: (json['identity'] as string) ?? AIModelIdentity.MODEL,
      providerID: json['providerId'] as string | undefined,
      company: (json['company'] as string) ?? '',
      endpoint: (json['endpoint'] as string) ?? '',
      apiKey: json['apiKey'] as string | undefined,
      supportsSearch: (json['supportsSearch'] as boolean) ?? false,
      supportsMultimodal: (json['supportsMultimodal'] as boolean) ?? false,
      supportsReasoning: (json['supportsReasoning'] as boolean) ?? false,
      supportsToolUse: (json['supportsToolUse'] as boolean) ?? false,
      supportsVoiceGen: (json['supportsVoiceGen'] as boolean) ?? false,
      supportsImageGen: (json['supportsImageGen'] as boolean) ?? false,
      supportsText: (json['supportsText'] as boolean) ?? true,
      supportsDeepReasoning: (json['supportsDeepReasoning'] as boolean) ?? false,
      reasoningControllable: (json['reasoningControllable'] as boolean) ?? false,
      priceTier: (json['priceTier'] as number) ?? 0,
      systemProvision: json['systemProvision'] as string | undefined,
      icon: json['icon'] as string | undefined,
      briefDescription: json['briefDescription'] as string | undefined,
      source: (json['source'] as string) ?? 'system',
      aiScenarios: (json['aiScenarios'] as string[]) ?? [],
      aiToolScenarios: (json['aiToolScenarios'] as string[]) ?? [],
      relatedTaskCodes: (json['relatedTaskCodes'] as string[]) ?? [],
      isDefault: (json['isDefault'] as boolean) ?? false,
      temperature: json['temperature'] as number | undefined,
      maxTokens: (json['maxTokens'] as number) ?? 4096,
      baseModelName: json['baseModelName'] as string | undefined,
      localFilename: json['localFilename'] as string | undefined
    };
    return new AIScenarioRemoteModelRow(params);
  }

  static fromProRow(row: ProScenarioModelRow): AIScenarioRemoteModelRow {
    const params: AIScenarioRemoteModelRowParams = {
      name: row.name,
      displayName: row.displayName,
      identity: row.identity,
      providerID: row.company,
      company: row.company,
      endpoint: row.endpoint ?? '',
      apiKey: row.apiKey,
      supportsSearch: row.capabilities.supportsSearch,
      supportsMultimodal: row.capabilities.supportsMultimodal,
      supportsReasoning: row.capabilities.supportsReasoning,
      supportsToolUse: row.capabilities.supportsToolUse,
      supportsVoiceGen: row.capabilities.supportsVoiceGen,
      supportsImageGen: row.capabilities.supportsImageGen,
      supportsText: row.capabilities.supportsText,
      supportsDeepReasoning: row.capabilities.supportsDeepReasoning,
      reasoningControllable: row.capabilities.reasoningControllable,
      priceTier: Number.parseInt(row.priceTier ?? '0') || 0,
      systemProvision: row.systemProvision,
      icon: row.icon,
      briefDescription: row.briefDescription,
      source: row.source,
      aiScenarios: row.aiScenarios.slice(),
      aiToolScenarios: row.aiToolScenarios.slice(),
      relatedTaskCodes: row.relatedTaskCodes.slice(),
      isDefault: row.isDefault,
      temperature: row.temperature,
      maxTokens: row.maxTokens ?? 4096,
      baseModelName: row.baseModelName
    };
    return new AIScenarioRemoteModelRow(params);
  }

  static demoRows(): AIScenarioRemoteModelRow[] {
    const doubaoParams: AIScenarioRemoteModelRowParams = {
      name: 'Doubao-Seed-2.0-Pro',
      displayName: 'Doubao Seed 2.0 Pro',
      identity: AIModelIdentity.MODEL,
      company: 'ByteDance',
      endpoint: '',
      supportsSearch: false,
      supportsMultimodal: true,
      supportsReasoning: true,
      supportsToolUse: true,
      supportsVoiceGen: false,
      supportsImageGen: false,
      supportsText: true,
      supportsDeepReasoning: true,
      reasoningControllable: true,
      priceTier: 2,
      source: 'pro',
      aiScenarios: [],
      aiToolScenarios: [],
      isDefault: true,
      maxTokens: 4096
    };
    const deepseekParams: AIScenarioRemoteModelRowParams = {
      name: 'deepseek-r1',
      displayName: 'DeepSeek R1',
      identity: AIModelIdentity.MODEL,
      company: 'DeepSeek',
      endpoint: '',
      supportsSearch: false,
      supportsMultimodal: false,
      supportsReasoning: true,
      supportsToolUse: true,
      supportsVoiceGen: false,
      supportsImageGen: false,
      supportsText: true,
      supportsDeepReasoning: true,
      reasoningControllable: true,
      priceTier: 2,
      source: 'pro',
      aiScenarios: [],
      aiToolScenarios: [],
      maxTokens: 4096
    };
    const rows: AIScenarioRemoteModelRow[] = [];
    rows.push(new AIScenarioRemoteModelRow(doubaoParams));
    rows.push(new AIScenarioRemoteModelRow(deepseekParams));
    return rows;
  }
}

function normalizeProviderID(value: string): string {
  // 对应 AIProviderIdentifier.normalize
  return value.trim().toLowerCase();
}

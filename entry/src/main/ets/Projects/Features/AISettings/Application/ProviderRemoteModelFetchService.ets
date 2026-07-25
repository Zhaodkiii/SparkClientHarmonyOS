import { http } from '@kit.NetworkKit';

/** 对标 iOS ProviderRemoteModel */
export class ProviderRemoteModel {
  name: string = '';
  displayName: string = '';
  ownedBy: string = '';
  supportsText: boolean = true;
  supportsMultimodal: boolean = false;
  supportsReasoning: boolean = false;
  supportsToolUse: boolean = false;
  supportsImageGen: boolean = false;
}

enum ProviderEndpointKind {
  OPENAI_COMPATIBLE = 'openAICompatible',
  ANTHROPIC = 'anthropic',
  GEMINI = 'gemini'
}

/**
 * 对标 iOS ProviderModelCatalogService.fetchModels：
 * 按厂商 endpoint 拉取远端模型目录（OpenAI 兼容 / Anthropic / Gemini）。
 */
export class ProviderRemoteModelFetchService {
  static async fetchModels(endpoint: string, apiKey: string): Promise<ProviderRemoteModel[]> {
    const url = endpoint.trim();
    const key = apiKey.trim();
    if (url.length === 0 || key.length === 0) {
      throw new Error('请先填写有效的请求地址和 API Key');
    }
    const kind = ProviderRemoteModelFetchService.endpointKind(url);
    let models: ProviderRemoteModel[] = [];
    if (kind === ProviderEndpointKind.ANTHROPIC) {
      models = await ProviderRemoteModelFetchService.fetchAnthropicModels(key);
    } else if (kind === ProviderEndpointKind.GEMINI) {
      models = await ProviderRemoteModelFetchService.fetchGeminiModels(url, key);
    } else {
      models = await ProviderRemoteModelFetchService.fetchOpenAICompatibleModels(url, key);
    }
    const filtered: ProviderRemoteModel[] = [];
    const seen: Set<string> = new Set();
    for (let i = 0; i < models.length; i++) {
      const m = models[i];
      if (!m.supportsText && !m.supportsImageGen) {
        continue;
      }
      if (seen.has(m.name)) {
        continue;
      }
      seen.add(m.name);
      filtered.push(m);
    }
    filtered.sort((a: ProviderRemoteModel, b: ProviderRemoteModel) => {
      return a.displayName.localeCompare(b.displayName);
    });
    return filtered;
  }

  private static endpointKind(endpoint: string): ProviderEndpointKind {
    const normalized = endpoint.toLowerCase();
    if (normalized.indexOf('generativelanguage.googleapis.com') >= 0) {
      return ProviderEndpointKind.GEMINI;
    }
    if (normalized.indexOf('api.anthropic.com') >= 0 || normalized.endsWith('/v1/messages')) {
      return ProviderEndpointKind.ANTHROPIC;
    }
    return ProviderEndpointKind.OPENAI_COMPATIBLE;
  }

  private static async fetchOpenAICompatibleModels(
    endpoint: string,
    apiKey: string
  ): Promise<ProviderRemoteModel[]> {
    const listUrl = ProviderRemoteModelFetchService.listURLForOpenAICompatibleEndpoint(endpoint);
    const payload = await ProviderRemoteModelFetchService.requestJSON(listUrl, {
      'Authorization': `Bearer ${apiKey}`,
      'Accept': 'application/json'
    });
    const data = payload['data'];
    if (!Array.isArray(data)) {
      throw new Error('模型列表返回格式无法识别');
    }
    const out: ProviderRemoteModel[] = [];
    for (let i = 0; i < data.length; i++) {
      const item = data[i] as Record<string, Object>;
      const rawName = `${item['id'] ?? ''}`.trim();
      if (rawName.length === 0) {
        continue;
      }
      const ownedBy = `${item['owned_by'] ?? ''}`.trim();
      const model = ProviderRemoteModelFetchService.modelFromName(rawName, rawName, ownedBy);
      if (model) {
        out.push(model);
      }
    }
    return out;
  }

  private static async fetchAnthropicModels(apiKey: string): Promise<ProviderRemoteModel[]> {
    const payload = await ProviderRemoteModelFetchService.requestJSON(
      'https://api.anthropic.com/v1/models',
      {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Accept': 'application/json'
      }
    );
    const data = payload['data'];
    if (!Array.isArray(data)) {
      throw new Error('模型列表返回格式无法识别');
    }
    const out: ProviderRemoteModel[] = [];
    for (let i = 0; i < data.length; i++) {
      const item = data[i] as Record<string, Object>;
      const rawName = `${item['id'] ?? ''}`.trim();
      if (rawName.length === 0) {
        continue;
      }
      const displayName = `${item['display_name'] ?? rawName}`.trim() || rawName;
      const model = ProviderRemoteModelFetchService.modelFromName(rawName, displayName, 'Anthropic');
      if (model) {
        out.push(model);
      }
    }
    return out;
  }

  private static async fetchGeminiModels(
    endpoint: string,
    apiKey: string
  ): Promise<ProviderRemoteModel[]> {
    let listUrl = endpoint;
    const joiner = endpoint.indexOf('?') >= 0 ? '&' : '?';
    listUrl = `${endpoint}${joiner}key=${encodeURIComponent(apiKey)}&pageSize=1000`;
    const payload = await ProviderRemoteModelFetchService.requestJSON(listUrl, {
      'Accept': 'application/json'
    });
    const models = payload['models'];
    if (!Array.isArray(models)) {
      throw new Error('模型列表返回格式无法识别');
    }
    const out: ProviderRemoteModel[] = [];
    for (let i = 0; i < models.length; i++) {
      const item = models[i] as Record<string, Object>;
      const rawNameFull = `${item['name'] ?? ''}`.trim();
      if (rawNameFull.length === 0) {
        continue;
      }
      const methodsRaw = item['supportedGenerationMethods'];
      const methods: string[] = Array.isArray(methodsRaw) ? methodsRaw as string[] : [];
      const supportsImageGen = methods.indexOf('generateImages') >= 0;
      const supportsText =
        methods.indexOf('generateContent') >= 0 || methods.indexOf('streamGenerateContent') >= 0;
      if (!supportsText && !supportsImageGen) {
        continue;
      }
      const rawDisplay = `${item['displayName'] ?? ''}`.trim();
      const stripped = rawNameFull.replace('models/', '');
      const displayName = rawDisplay.length > 0 ? rawDisplay : stripped;
      const base = ProviderRemoteModelFetchService.modelFromName(stripped, displayName, 'Google');
      if (!base) {
        continue;
      }
      base.supportsText = supportsText;
      base.supportsMultimodal = true;
      base.supportsToolUse = methods.indexOf('generateContent') >= 0;
      base.supportsImageGen = supportsImageGen;
      out.push(base);
    }
    return out;
  }

  private static listURLForOpenAICompatibleEndpoint(endpoint: string): string {
    let path = endpoint;
    const qIndex = path.indexOf('?');
    if (qIndex >= 0) {
      path = path.substring(0, qIndex);
    }
    if (path.endsWith('/models')) {
      return path;
    }
    const replacements = ['/chat/completions', '/responses', '/completions', '/messages'];
    for (let i = 0; i < replacements.length; i++) {
      const suffix = replacements[i];
      if (path.endsWith(suffix)) {
        return path.substring(0, path.length - suffix.length) + '/models';
      }
    }
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path + '/models';
  }

  private static async requestJSON(
    url: string,
    headers: Record<string, string>
  ): Promise<Record<string, Object>> {
    const httpRequest = http.createHttp();
    try {
      const result = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 30000
      });
      const code = result.responseCode;
      const body = `${result.result ?? ''}`;
      if (code < 200 || code >= 300) {
        const trimmed = body.trim();
        if (trimmed.length === 0) {
          throw new Error(`刷新模型列表失败（HTTP ${code}）`);
        }
        throw new Error(`刷新模型列表失败（HTTP ${code}）：${trimmed}`);
      }
      try {
        return JSON.parse(body) as Record<string, Object>;
      } catch (_e) {
        throw new Error('模型列表返回格式无法识别');
      }
    } finally {
      httpRequest.destroy();
    }
  }

  private static modelFromName(
    rawName: string,
    displayName: string,
    ownedBy: string
  ): ProviderRemoteModel | undefined {
    const normalizedName = rawName.trim();
    if (normalizedName.length === 0) {
      return undefined;
    }
    const lowercased = normalizedName.toLowerCase();
    if (lowercased.indexOf('embedding') >= 0 || lowercased.indexOf('moderation') >= 0) {
      return undefined;
    }
    const supportsImageGen = lowercased.indexOf('image') >= 0 || lowercased.indexOf('dall-e') >= 0;
    const isAudioOnly =
      lowercased.indexOf('whisper') >= 0 ||
        lowercased.indexOf('tts') >= 0 ||
        lowercased.indexOf('transcribe') >= 0 ||
        lowercased.indexOf('realtime') >= 0 ||
        lowercased.indexOf('audio') >= 0;
    const supportsText = !supportsImageGen && !isAudioOnly;
    const supportsMultimodal = supportsText && (
      lowercased.indexOf('gpt-4o') >= 0 ||
        lowercased.indexOf('gpt-4.1') >= 0 ||
        lowercased.indexOf('gpt-5') >= 0 ||
        lowercased.indexOf('gemini') >= 0 ||
        lowercased.indexOf('claude') >= 0 ||
        lowercased.indexOf('vision') >= 0 ||
        lowercased.indexOf('vl') >= 0 ||
        lowercased.indexOf('omni') >= 0
    );
    const supportsReasoning = supportsText && (
      lowercased.indexOf('reason') >= 0 ||
        lowercased.indexOf('thinking') >= 0 ||
        lowercased.indexOf('o1') >= 0 ||
        lowercased.indexOf('o3') >= 0 ||
        lowercased.indexOf('o4') >= 0 ||
        lowercased.indexOf('gpt-5') >= 0 ||
        lowercased.indexOf('sonnet') >= 0 ||
        lowercased.indexOf('opus') >= 0 ||
        lowercased.indexOf('pro') >= 0
    );
    const m = new ProviderRemoteModel();
    m.name = normalizedName;
    m.displayName = displayName.trim().length > 0 ? displayName.trim() : normalizedName;
    m.ownedBy = ownedBy;
    m.supportsText = supportsText;
    m.supportsMultimodal = supportsMultimodal;
    m.supportsReasoning = supportsReasoning;
    m.supportsToolUse = supportsText;
    m.supportsImageGen = supportsImageGen;
    return m;
  }

  /** 对标 iOS remotePriceTier */
  static remotePriceTier(remoteModel: ProviderRemoteModel): number {
    const name = remoteModel.name.toLowerCase();
    if (remoteModel.supportsImageGen) {
      return 3;
    }
    if (name.indexOf('nano') >= 0 || name.indexOf('mini') >= 0 ||
      name.indexOf('flash') >= 0 || name.indexOf('lite') >= 0) {
      return 1;
    }
    if (name.indexOf('reasoner') >= 0 || name.indexOf('max') >= 0 ||
      name.indexOf('opus') >= 0 || name.indexOf('pro') >= 0) {
      return 3;
    }
    return 2;
  }

  static normalizedModelName(name: string): string {
    return name.trim().replace('models/', '').toLowerCase();
  }
}

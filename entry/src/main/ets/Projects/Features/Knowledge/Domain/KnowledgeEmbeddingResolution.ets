import { AIResolvedConfig, AIScenario, RuntimeSnapshot } from '../../../../Core/AI/Domain/AIConfigModels';
import { ScenarioPolicyResolver } from '../../../../Core/AI/Application/ScenarioPolicyResolver';

/**
 * 从运行时合并后的 embedding 场景候选中解析嵌入调用所需的模型名、密钥引用与端点。
 * 对齐 iOS KnowledgeEmbeddingResolution.swift。
 *
 * 与 iOS 的差异：iOS `row.apiKey` 在 `AIConfigCenter.effectiveScenarioBundles()` 阶段已从 Keychain 解出明文；
 * 鸿蒙端 API Key 只以 HUKS 密文落盘，`AIResolvedConfig` 只带 `secretRef`。领域层不做密钥解密（无 I/O），
 * 调用方（Application 层 BuildKnowledgeEmbeddingsUseCase / SearchKnowledgeUseCase）需在真正发起 HTTP 调用前
 * 用 `AIKeyStore.get(secretRef)` 解出明文，与 `Core/AI/Runtime/OpenAICompatibleProviderAdapter.ets`
 * 解密 apiKey 的方式一致。
 */
export class KnowledgeEmbeddingResolved {
  /** 发往 API 的 `model` 字段（可能经厂商别名映射）。 */
  apiModelName: string = '';
  /** HUKS 密钥引用；调用方需自行解出明文 API Key。 */
  secretRef?: string;
  embeddingsURL: string = '';
}

/** 对齐 iOS KnowledgeEmbeddingResolution.ResolutionError / AIConfigError.missingModelForScenario。 */
export class KnowledgeEmbeddingResolutionError extends Error {
  code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

export class KnowledgeEmbeddingResolution {
  /** 对齐 iOS resolve(modelName:in:)：从运行时快照的 embedding 候选中挑一行并解析。 */
  static resolve(modelName: string | undefined, runtime: RuntimeSnapshot): KnowledgeEmbeddingResolved {
    const candidates = runtime.scenarios.get(AIScenario.EMBEDDING) ?? [];
    const ready = candidates.filter((c: AIResolvedConfig): boolean => c.isReady);
    const preferred = modelName?.trim();
    const row = ScenarioPolicyResolver.pickExact(ready, preferred && preferred.length > 0 ? preferred : undefined);
    if (!row) {
      throw new KnowledgeEmbeddingResolutionError('missingModelForScenario', '未找到可用的嵌入模型配置。');
    }
    return KnowledgeEmbeddingResolution.resolveRow(row);
  }

  /** 对齐 iOS resolve(row:)。 */
  static resolveRow(row: AIResolvedConfig): KnowledgeEmbeddingResolved {
    const rawModel = row.modelName && row.modelName.trim().length > 0 ? row.modelName : row.modelId;
    const apiModel = (rawModel ?? '').trim();
    if (apiModel.length === 0) {
      throw new KnowledgeEmbeddingResolutionError('emptyModelName', '未选择嵌入模型。');
    }

    const endpoint = KnowledgeEmbeddingResolution.resolveEmbeddingURL(row.endpoint ?? '', apiModel);
    if (!KnowledgeEmbeddingResolution.isValidHttpUrl(endpoint)) {
      throw new KnowledgeEmbeddingResolutionError('invalidURL', `无效的嵌入端点：${endpoint}`);
    }

    const resolved = new KnowledgeEmbeddingResolved();
    resolved.apiModelName = apiModel;
    resolved.secretRef = row.secretRef;
    resolved.embeddingsURL = endpoint;
    return resolved;
  }

  /** 本地 bundle 可能仍复用厂商的 chat/responses 基址，运行时调用前统一落到 embeddings 端点。 */
  private static resolveEmbeddingURL(providerEndpoint: string, modelName: string): string {
    const endpoint = providerEndpoint.trim();
    if (endpoint.length === 0) {
      return '';
    }
    if (endpoint.includes('/chat/completions')) {
      if (modelName.toLowerCase().includes('vision')) {
        return endpoint.replace('/chat/completions', '/embeddings/multimodal');
      }
      return endpoint.replace('/chat/completions', '/embeddings');
    }
    if (endpoint.includes('/responses')) {
      return endpoint.replace('/responses', '/embeddings');
    }
    if (endpoint.endsWith('/')) {
      return `${endpoint}embeddings`;
    }
    if (endpoint.toLowerCase().endsWith('/embeddings') || endpoint.includes('/embeddings')) {
      return endpoint;
    }
    return `${endpoint}/embeddings`;
  }

  /** 对齐 iOS `URL(string:), scheme != nil` 校验；ArkTS 侧用前缀判断近似。 */
  private static isValidHttpUrl(value: string): boolean {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}

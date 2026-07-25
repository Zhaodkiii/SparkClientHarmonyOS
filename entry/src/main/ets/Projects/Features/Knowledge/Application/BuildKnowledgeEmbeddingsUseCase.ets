import { AIKeyStore } from '../../../../Core/AI/Infrastructure/AIKeyStore';
import { AIRuntimeSnapshotStore } from '../../../../Core/AI/Runtime/AIRuntimeSnapshotStore';
import { KnowledgeChunking } from '../Domain/KnowledgeChunking';
import { KnowledgeEmbeddingResolution } from '../Domain/KnowledgeEmbeddingResolution';
import { KnowledgeDocument } from '../Domain/KnowledgeModels';
import { KnowledgeRepository } from '../Domain/KnowledgeRepository';
import { KnowledgeEmbeddingClient } from '../Infrastructure/KnowledgeEmbeddingClient';
import { KnowledgeUseCaseSupport } from './KnowledgeUseCases';

/**
 * 「构建知识库向量嵌入」用例；对齐 iOS BuildKnowledgeEmbeddingsUseCase.swift。
 * 流程：加载文档 → Markdown 切块 → 批量调用 Embedding → 替换切块向量 → 标记已索引。
 *
 * 与 iOS 差异：
 * - accountId 显式传入
 * - 用 AIRuntimeSnapshotStore + AIKeyStore 替代 AIConfigCenter（明文 apiKey → secretRef 解密）
 */
export class BuildKnowledgeEmbeddingsUseCase {
  private readonly repository: KnowledgeRepository;
  private readonly snapshotStore: AIRuntimeSnapshotStore;
  private readonly keyStore: AIKeyStore;
  private readonly embeddingClient: KnowledgeEmbeddingClient;

  constructor(
    repository: KnowledgeRepository,
    snapshotStore: AIRuntimeSnapshotStore,
    keyStore: AIKeyStore,
    embeddingClient: KnowledgeEmbeddingClient
  ) {
    this.repository = repository;
    this.snapshotStore = snapshotStore;
    this.keyStore = keyStore;
    this.embeddingClient = embeddingClient;
  }

  async execute(accountId: number, documentID: string, modelName: string): Promise<KnowledgeDocument> {
    KnowledgeUseCaseSupport.requireAccount(accountId);

    const runtime = this.snapshotStore.get(accountId);
    if (!runtime) {
      throw new BuildKnowledgeEmbeddingsError('runtimeNotReady', 'AI 运行时未就绪，无法构建嵌入。');
    }
    const resolved = KnowledgeEmbeddingResolution.resolve(modelName, runtime);
    const apiKey = await KnowledgeUseCaseSupport.resolveApiKey(this.keyStore, resolved.secretRef);

    const doc = await this.repository.loadDocument(accountId, documentID);
    if (!doc) {
      throw new BuildKnowledgeEmbeddingsError('documentNotFound', '未找到知识文档。');
    }

    const chunkTexts = KnowledgeChunking.chunksForEmbedding(doc.content);
    if (chunkTexts.length === 0) {
      throw new BuildKnowledgeEmbeddingsError('emptyContent', '正文为空，无法切块嵌入。');
    }

    const allEmbeddings: number[][] = [];
    const batchSize = 10;
    let start = 0;
    while (start < chunkTexts.length) {
      const end = Math.min(start + batchSize, chunkTexts.length);
      const batch: string[] = [];
      for (let i = start; i < end; i++) {
        batch.push(chunkTexts[i]);
      }
      const vectors = await this.embeddingClient.embed(
        batch,
        resolved.apiModelName,
        apiKey,
        resolved.embeddingsURL
      );
      for (let i = 0; i < vectors.length; i++) {
        allEmbeddings.push(vectors[i]);
      }
      start = end;
    }

    if (allEmbeddings.length !== chunkTexts.length) {
      throw new BuildKnowledgeEmbeddingsError('embeddingCountMismatch', '嵌入返回数量与切块不一致。');
    }

    return await this.repository.replaceDocumentChunksWithEmbeddings(
      accountId,
      documentID,
      chunkTexts,
      allEmbeddings,
      modelName
    );
  }
}

export class BuildKnowledgeEmbeddingsError extends Error {
  code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

import { AIKeyStore } from '../../../../Core/AI/Infrastructure/AIKeyStore';
import { AIRuntimeSnapshotStore } from '../../../../Core/AI/Runtime/AIRuntimeSnapshotStore';
import { KnowledgeDocument, KnowledgeDocumentDraft, KnowledgeSearchResult } from '../Domain/KnowledgeModels';
import { KnowledgeEmbeddingResolution } from '../Domain/KnowledgeEmbeddingResolution';
import { KnowledgeRepository } from '../Domain/KnowledgeRepository';
import { KnowledgeEmbeddingClient } from '../Infrastructure/KnowledgeEmbeddingClient';

/**
 * 知识库 CRUD / 检索 / 重建索引用例；对齐 iOS KnowledgeUseCases.swift。
 * 与 iOS 差异：账号 ID 由调用方显式传入（对齐本工程 Chat 仓库约定）。
 */

export class LoadKnowledgeListUseCase {
  private readonly repository: KnowledgeRepository;

  constructor(repository: KnowledgeRepository) {
    this.repository = repository;
  }

  async execute(accountId: number, query?: string): Promise<KnowledgeDocument[]> {
    KnowledgeUseCaseSupport.requireAccount(accountId);
    return await this.repository.loadDocuments(accountId, query);
  }
}

export class LoadKnowledgeDocumentUseCase {
  private readonly repository: KnowledgeRepository;

  constructor(repository: KnowledgeRepository) {
    this.repository = repository;
  }

  async execute(accountId: number, id: string): Promise<KnowledgeDocument | undefined> {
    KnowledgeUseCaseSupport.requireAccount(accountId);
    return await this.repository.loadDocument(accountId, id);
  }
}

export class CreateKnowledgeDocumentUseCase {
  private readonly repository: KnowledgeRepository;

  constructor(repository: KnowledgeRepository) {
    this.repository = repository;
  }

  async execute(accountId: number, draft: KnowledgeDocumentDraft): Promise<KnowledgeDocument> {
    KnowledgeUseCaseSupport.requireAccount(accountId);
    return await this.repository.createDocument(accountId, draft);
  }
}

export class UpdateKnowledgeDocumentUseCase {
  private readonly repository: KnowledgeRepository;

  constructor(repository: KnowledgeRepository) {
    this.repository = repository;
  }

  async execute(accountId: number, id: string, draft: KnowledgeDocumentDraft): Promise<KnowledgeDocument> {
    KnowledgeUseCaseSupport.requireAccount(accountId);
    return await this.repository.updateDocument(accountId, id, draft);
  }
}

export class DeleteKnowledgeDocumentUseCase {
  private readonly repository: KnowledgeRepository;

  constructor(repository: KnowledgeRepository) {
    this.repository = repository;
  }

  async execute(accountId: number, id: string): Promise<void> {
    KnowledgeUseCaseSupport.requireAccount(accountId);
    await this.repository.deleteDocument(accountId, id);
  }
}

export class SearchKnowledgeUseCase {
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

  async execute(accountId: number, query: string, limit: number = 8): Promise<KnowledgeSearchResult[]> {
    KnowledgeUseCaseSupport.requireAccount(accountId);
    const trimmed = query.trim();
    if (trimmed.length === 0) {
      return [];
    }

    const hasVectors = await this.repository.hasVectorIndexedChunks(accountId);
    if (hasVectors) {
      try {
        const runtime = this.snapshotStore.get(accountId);
        if (runtime) {
          const resolved = KnowledgeEmbeddingResolution.resolve(undefined, runtime);
          const apiKey = await KnowledgeUseCaseSupport.resolveApiKey(this.keyStore, resolved.secretRef);
          const vectors = await this.embeddingClient.embed(
            [trimmed],
            resolved.apiModelName,
            apiKey,
            resolved.embeddingsURL
          );
          if (vectors.length > 0 && vectors[0].length > 0) {
            return await this.repository.search(accountId, trimmed, limit, vectors[0]);
          }
        }
      } catch (_e) {
        // 查询嵌入失败时回退词法，保证 ToolHub 仍可用。
      }
    }
    return await this.repository.search(accountId, trimmed, limit, undefined);
  }
}

export class ReindexKnowledgeDocumentUseCase {
  private readonly repository: KnowledgeRepository;

  constructor(repository: KnowledgeRepository) {
    this.repository = repository;
  }

  async execute(accountId: number, id: string): Promise<KnowledgeDocument> {
    KnowledgeUseCaseSupport.requireAccount(accountId);
    return await this.repository.rebuildIndex(accountId, id);
  }
}

/** Application 层共用校验 / 密钥解密。 */
export class KnowledgeUseCaseSupport {
  static requireAccount(accountId: number): void {
    if (accountId <= 0) {
      throw new Error('accountRequired');
    }
  }

  /**
   * 鸿蒙 API Key 仅以 HUKS secretRef 落盘；在发起 HTTP 前解出明文。
   * 对齐 OpenAICompatibleProviderAdapter 的解密时机。
   */
  static async resolveApiKey(keyStore: AIKeyStore, secretRef?: string): Promise<string> {
    if (!secretRef || secretRef.trim().length === 0) {
      return '';
    }
    const plain = await keyStore.get(secretRef);
    return plain ?? '';
  }
}

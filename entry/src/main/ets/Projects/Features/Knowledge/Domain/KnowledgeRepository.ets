import { KnowledgeDocument, KnowledgeDocumentDraft, KnowledgeSearchResult } from './KnowledgeModels';

/**
 * 知识库持久化抽象；对齐 iOS KnowledgeRepository.swift。
 * 由 `RdbKnowledgeRepository` 实现，供各用例注入。
 *
 * 与 iOS 版本的差异：iOS 仓库内部通过 SessionSnapshotStore 异步取当前账号 ID；
 * 鸿蒙端沿用本工程既有仓库约定（参考 ChatRepository），账号 ID 由调用方（UseCase/ViewModel）
 * 从 AccountSessionRuntime.activeAccountId 解析后显式传入，未登录判断前移到调用方。
 */
export interface KnowledgeRepository {
  loadDocuments(accountId: number, query?: string): Promise<KnowledgeDocument[]>;

  loadDocument(accountId: number, id: string): Promise<KnowledgeDocument | undefined>;

  createDocument(accountId: number, draft: KnowledgeDocumentDraft): Promise<KnowledgeDocument>;

  updateDocument(accountId: number, id: string, draft: KnowledgeDocumentDraft): Promise<KnowledgeDocument>;

  rebuildIndex(accountId: number, id: string): Promise<KnowledgeDocument>;

  deleteDocument(accountId: number, id: string): Promise<void>;

  /** 是否存在至少一条带 vectorData 的切块（用于决定是否走语义检索）。 */
  hasVectorIndexedChunks(accountId: number): Promise<boolean>;

  /** 用切块文本与向量替换文档的切块行，并标记已向量化。 */
  replaceDocumentChunksWithEmbeddings(
    accountId: number,
    documentID: string,
    chunkTexts: string[],
    embeddings: number[][],
    modelName: string
  ): Promise<KnowledgeDocument>;

  /** queryEmbedding 非空时，对带向量的切块做余弦相似度 Top-K；否则回退词法打分。 */
  search(accountId: number, query: string, limit: number, queryEmbedding?: number[]): Promise<KnowledgeSearchResult[]>;
}

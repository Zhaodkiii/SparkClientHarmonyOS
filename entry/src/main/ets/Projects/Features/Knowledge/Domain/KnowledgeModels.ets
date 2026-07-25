/**
 * 知识库领域模型；对齐 iOS KnowledgeModels.swift，与 knowledge_document / knowledge_chunk 表一一对应。
 */

/** 文档作用域：个人私有 / 绑定到某个智能体 */
export enum KnowledgeDocumentScope {
  PERSONAL = 'personal',
  AGENT_BOUND = 'agentBound'
}

export function parseKnowledgeDocumentScope(raw: string | undefined): KnowledgeDocumentScope {
  return raw === KnowledgeDocumentScope.AGENT_BOUND ? KnowledgeDocumentScope.AGENT_BOUND : KnowledgeDocumentScope.PERSONAL;
}

/** 文档来源：用户手动创建 / 工具/自动化流程创建 */
export enum KnowledgeDocumentSource {
  USER = 'user',
  TOOL = 'tool'
}

export function parseKnowledgeDocumentSource(raw: string | undefined): KnowledgeDocumentSource {
  return raw === KnowledgeDocumentSource.TOOL ? KnowledgeDocumentSource.TOOL : KnowledgeDocumentSource.USER;
}

/** 知识库文档（对应 knowledge_document 表一行） */
export class KnowledgeDocument {
  id: string = '';
  title: string = '';
  content: string = '';
  excerpt: string = '';
  scope: KnowledgeDocumentScope = KnowledgeDocumentScope.PERSONAL;
  boundModelID?: string;
  source: KnowledgeDocumentSource = KnowledgeDocumentSource.USER;
  chunkCount: number = 0;
  isEmbeddingIndexed: boolean = false;
  lastEmbeddingModelName?: string;
  createdAt: string = '';
  updatedAt: string = '';

  /** 列表页展示用副标题：优先使用摘要，没有则取内容预览 */
  get listSubtitle(): string {
    return this.excerpt.length > 0 ? this.excerpt : KnowledgeDocument.previewText(this.content, 96);
  }

  private static previewText(text: string, limit: number): string {
    const normalized = text
      .replace(/\n/g, ' ')
      .replace(/\t/g, ' ')
      .trim();
    if (normalized.length <= limit) {
      return normalized;
    }
    return `${normalized.substring(0, limit)}...`;
  }
}

/** 文档切块（对应 knowledge_chunk 表一行） */
export class KnowledgeChunk {
  id: string = '';
  documentID: string = '';
  sequence: number = 0;
  content: string = '';
  embedding?: number[];
  createdAt: string = '';
  updatedAt: string = '';
}

/** 知识库搜索/检索结果 */
export class KnowledgeSearchResult {
  documentID: string = '';
  title: string = '';
  excerpt: string = '';
  matchedChunkSequence?: number;
  score: number = 0;

  get id(): string {
    return this.documentID;
  }
}

/** 文档草稿（创建/编辑时使用，未持久化） */
export class KnowledgeDocumentDraft {
  title: string = '';
  content: string = '';
  scope: KnowledgeDocumentScope = KnowledgeDocumentScope.PERSONAL;
  boundModelID?: string;
  source: KnowledgeDocumentSource = KnowledgeDocumentSource.USER;

  constructor(
    title: string = '',
    content: string = '',
    scope: KnowledgeDocumentScope = KnowledgeDocumentScope.PERSONAL,
    boundModelID?: string,
    source: KnowledgeDocumentSource = KnowledgeDocumentSource.USER
  ) {
    this.title = title;
    this.content = content;
    this.scope = scope;
    this.boundModelID = boundModelID;
    this.source = source;
  }
}

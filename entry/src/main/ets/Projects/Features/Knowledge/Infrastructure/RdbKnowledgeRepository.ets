import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { AppRelationalDatabase } from '../../../../Core/Storage/AppRelationalDatabase';
import {
  KnowledgeDocument,
  KnowledgeDocumentDraft,
  KnowledgeSearchResult,
  parseKnowledgeDocumentScope,
  parseKnowledgeDocumentSource
} from '../Domain/KnowledgeModels';
import { KnowledgeRepository } from '../Domain/KnowledgeRepository';
import { KnowledgeVectorCoding } from '../Domain/KnowledgeVectorCoding';
import { KnowledgeEmbeddingSimilarity } from '../Domain/KnowledgeEmbeddingSimilarity';
import { KnowledgeSchema } from './KnowledgeSchema';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';

/** 内存态切块行：仅供 search() 内部词法/语义合并使用，不对外导出。 */
class KnowledgeChunkRow {
  documentID: string = '';
  content: string = '';
  sequence: number = 0;
  vectorData?: Uint8Array;
}

/** 语义检索命中的最佳切块（按文档聚合）。 */
class KnowledgeSemanticMatch {
  score: number = 0;
  sequence: number = 0;
  excerpt: string = '';
  title: string = '';
}

/**
 * 知识库 `KnowledgeRepository` 实现；对齐 iOS CoreDataKnowledgeRepository.swift。
 *
 * - 文档正文存 knowledge_document，按段落切块写入 knowledge_chunk 供本地词法检索；向量化后切块带 vector_data。
 * - 检索：可选查询向量 + 切块余弦相似度，无向量或未嵌入时回退词法打分（与 ToolHub search_knowledge_bag 共用）。
 * - 写入统一走 AppRelationalDatabase.queue，避免 RDB 并发写导致乱序（与 Chat/AI 共用同一写队列）。
 */
export class RdbKnowledgeRepository implements KnowledgeRepository {
  private readonly database: AppRelationalDatabase;

  constructor(database: AppRelationalDatabase) {
    this.database = database;
  }

  async loadDocuments(accountId: number, query?: string): Promise<KnowledgeDocument[]> {
    const db = await this.database.open();
    const trimmed = query?.trim();
    let sql = `SELECT * FROM ${KnowledgeSchema.T_DOCUMENT} WHERE account_id = ?`;
    const args: (string | number)[] = [accountId];
    if (trimmed && trimmed.length > 0) {
      sql += ' AND (title LIKE ? OR content LIKE ? OR excerpt LIKE ?)';
      const like = `%${trimmed}%`;
      args.push(like, like, like);
    }
    sql += ' ORDER BY updated_at DESC';
    const rs = await db.querySql(sql, args);
    const out: KnowledgeDocument[] = [];
    try {
      if (rs.goToFirstRow()) {
        do {
          out.push(RdbKnowledgeRepository.readDocument(rs));
        } while (rs.goToNextRow());
      }
    } finally {
      rs.close();
    }
    return out;
  }

  async loadDocument(accountId: number, id: string): Promise<KnowledgeDocument | undefined> {
    const db = await this.database.open();
    return this.fetchDocumentRow(db, accountId, id);
  }

  async createDocument(accountId: number, draft: KnowledgeDocumentDraft): Promise<KnowledgeDocument> {
    const prepared = RdbKnowledgeRepository.validateDraft(draft);
    return this.database.queue.enqueue(async (): Promise<KnowledgeDocument> => {
      const db = await this.database.open();
      const id = util.generateRandomUUID(true);
      const now = new Date().toISOString();
      const excerpt = RdbKnowledgeRepository.makeExcerpt(prepared.content, 140);

      await db.executeSql(`INSERT INTO ${KnowledgeSchema.T_DOCUMENT}
        (id, account_id, title, content, excerpt, scope, bound_model_id, source,
         chunk_count, is_embedding_indexed, last_embedding_model_name, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, NULL, ?, ?)`, [
        id, accountId, prepared.title, prepared.content, excerpt, prepared.scope,
        prepared.boundModelID ?? null, prepared.source, now, now
      ]);
      await this.rebuildChunksInternal(db, accountId, id, prepared.content, now);

      const document = await this.fetchDocumentRow(db, accountId, id);
      if (!document) {
        throw new Error('知识文档创建后无法生成领域对象');
      }
      return document;
    });
  }

  async updateDocument(accountId: number, id: string, draft: KnowledgeDocumentDraft): Promise<KnowledgeDocument> {
    const prepared = RdbKnowledgeRepository.validateDraft(draft);
    return this.database.queue.enqueue(async (): Promise<KnowledgeDocument> => {
      const db = await this.database.open();
      const existing = await this.fetchDocumentRow(db, accountId, id);
      if (!existing) {
        throw new Error('未找到要更新的知识文档');
      }
      const contentBefore = existing.content;
      const now = new Date().toISOString();
      const excerpt = RdbKnowledgeRepository.makeExcerpt(prepared.content, 140);

      await db.executeSql(`UPDATE ${KnowledgeSchema.T_DOCUMENT}
        SET title = ?, content = ?, excerpt = ?, scope = ?, bound_model_id = ?, source = ?, updated_at = ?
        WHERE account_id = ? AND id = ?`, [
        prepared.title, prepared.content, excerpt, prepared.scope,
        prepared.boundModelID ?? null, prepared.source, now, accountId, id
      ]);

      // 仅正文变化时重建切块；否则保留现有切块与向量索引（避免无意义 save 触发清索引）。
      if (contentBefore !== prepared.content) {
        await this.rebuildChunksInternal(db, accountId, id, prepared.content, now);
      }

      const document = await this.fetchDocumentRow(db, accountId, id);
      if (!document) {
        throw new Error('知识文档更新后无法生成领域对象');
      }
      return document;
    });
  }

  async rebuildIndex(accountId: number, id: string): Promise<KnowledgeDocument> {
    return this.database.queue.enqueue(async (): Promise<KnowledgeDocument> => {
      const db = await this.database.open();
      const existing = await this.fetchDocumentRow(db, accountId, id);
      if (!existing) {
        throw new Error('未找到要重建索引的知识文档');
      }
      const now = new Date().toISOString();
      await db.executeSql(`UPDATE ${KnowledgeSchema.T_DOCUMENT} SET updated_at = ? WHERE account_id = ? AND id = ?`,
        [now, accountId, id]);
      await this.rebuildChunksInternal(db, accountId, id, existing.content, now);

      const document = await this.fetchDocumentRow(db, accountId, id);
      if (!document) {
        throw new Error('知识文档重建索引后无法生成领域对象');
      }
      return document;
    });
  }

  async deleteDocument(accountId: number, id: string): Promise<void> {
    await this.database.queue.enqueue(async (): Promise<void> => {
      const db = await this.database.open();
      const existing = await this.fetchDocumentRow(db, accountId, id);
      if (!existing) {
        return;
      }
      await this.deleteChunksInternal(db, accountId, id);
      await db.executeSql(`DELETE FROM ${KnowledgeSchema.T_DOCUMENT} WHERE account_id = ? AND id = ?`, [accountId, id]);
    });
  }

  async hasVectorIndexedChunks(accountId: number): Promise<boolean> {
    const db = await this.database.open();
    const rs = await db.querySql(
      `SELECT 1 FROM ${KnowledgeSchema.T_CHUNK} WHERE account_id = ? AND vector_data IS NOT NULL LIMIT 1`,
      [accountId]
    );
    try {
      return rs.goToFirstRow();
    } finally {
      rs.close();
    }
  }

  async replaceDocumentChunksWithEmbeddings(
    accountId: number,
    documentID: string,
    chunkTexts: string[],
    embeddings: number[][],
    modelName: string
  ): Promise<KnowledgeDocument> {
    if (chunkTexts.length !== embeddings.length) {
      throw new Error('嵌入向量数量与文本块数量不一致');
    }
    return this.database.queue.enqueue(async (): Promise<KnowledgeDocument> => {
      const db = await this.database.open();
      const existing = await this.fetchDocumentRow(db, accountId, documentID);
      if (!existing) {
        throw new Error('未找到要写入向量索引的知识文档');
      }
      await this.deleteChunksInternal(db, accountId, documentID);

      const now = new Date().toISOString();
      for (let i = 0; i < chunkTexts.length; i++) {
        const chunkId = util.generateRandomUUID(true);
        const vectorBytes = KnowledgeVectorCoding.encode(embeddings[i]);
        await db.executeSql(`INSERT INTO ${KnowledgeSchema.T_CHUNK}
          (id, account_id, document_id, sequence, content, vector_data, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, [
          chunkId, accountId, documentID, i, chunkTexts[i], vectorBytes, now, now
        ]);
      }

      await db.executeSql(`UPDATE ${KnowledgeSchema.T_DOCUMENT}
        SET chunk_count = ?, is_embedding_indexed = 1, last_embedding_model_name = ?, updated_at = ?
        WHERE account_id = ? AND id = ?`, [chunkTexts.length, modelName, now, accountId, documentID]);

      const document = await this.fetchDocumentRow(db, accountId, documentID);
      if (!document) {
        throw new Error('写入向量索引后无法生成领域对象');
      }
      return document;
    });
  }

  async search(accountId: number, query: string, limit: number, queryEmbedding?: number[]): Promise<KnowledgeSearchResult[]> {
    const trimmed = query.trim();
    if (trimmed.length === 0) {
      return [];
    }
    const db = await this.database.open();
    const documents = await this.queryAllDocuments(db, accountId);
    const chunks = await this.queryAllChunks(db, accountId);

    const lexical = RdbKnowledgeRepository.lexicalSearchMatches(documents, chunks, trimmed);

    const hasVectorizedChunk = chunks.some((c: KnowledgeChunkRow): boolean => c.vectorData !== undefined);
    const useSemantic = queryEmbedding !== undefined && queryEmbedding.length > 0 && hasVectorizedChunk;
    if (!useSemantic || queryEmbedding === undefined) {
      return RdbKnowledgeRepository.sortedResults(lexical, limit);
    }

    const semanticBest = new Map<string, KnowledgeSemanticMatch>();
    for (const chunk of chunks) {
      if (!chunk.vectorData) {
        continue;
      }
      const vector = KnowledgeVectorCoding.decode(chunk.vectorData);
      if (!vector || vector.length !== queryEmbedding.length) {
        continue;
      }
      const sim = KnowledgeEmbeddingSimilarity.cosine(queryEmbedding, vector);
      const matchedDoc = documents.find((d: KnowledgeDocument): boolean => d.id === chunk.documentID);
      const title = matchedDoc ? matchedDoc.title : 'Untitled';
      const excerpt = RdbKnowledgeRepository.bestExcerpt(chunk.content, trimmed, chunk.content);

      const existing = semanticBest.get(chunk.documentID);
      if (!existing || sim > existing.score) {
        const match = new KnowledgeSemanticMatch();
        match.score = sim;
        match.sequence = chunk.sequence;
        match.excerpt = excerpt;
        match.title = title;
        semanticBest.set(chunk.documentID, match);
      }
    }

    // 合并词法 + 语义得分（语义主导，词法作为轻量加权）。
    const merged = new Map<string, KnowledgeSearchResult>();
    const allIds = new Set<string>();
    lexical.forEach((_v: KnowledgeSearchResult, k: string): void => { allIds.add(k); });
    semanticBest.forEach((_v: KnowledgeSemanticMatch, k: string): void => { allIds.add(k); });
    allIds.forEach((id: string): void => {
      const lex = lexical.get(id);
      const sem = semanticBest.get(id);
      if (sem) {
        const combined = sem.score * 100.0 + (lex ? lex.score : 0) * 0.15;
        const result = new KnowledgeSearchResult();
        result.documentID = id;
        result.title = sem.title;
        result.excerpt = sem.excerpt;
        result.matchedChunkSequence = sem.sequence;
        result.score = combined;
        merged.set(id, result);
      } else if (lex) {
        merged.set(id, lex);
      }
    });

    return RdbKnowledgeRepository.sortedResults(merged, limit);
  }

  // MARK: - 私有：读取

  private async fetchDocumentRow(db: relationalStore.RdbStore, accountId: number, id: string): Promise<KnowledgeDocument | undefined> {
    const rs = await db.querySql(
      `SELECT * FROM ${KnowledgeSchema.T_DOCUMENT} WHERE account_id = ? AND id = ? LIMIT 1`,
      [accountId, id]
    );
    try {
      return rs.goToFirstRow() ? RdbKnowledgeRepository.readDocument(rs) : undefined;
    } finally {
      rs.close();
    }
  }

  private async queryAllDocuments(db: relationalStore.RdbStore, accountId: number): Promise<KnowledgeDocument[]> {
    const rs = await db.querySql(`SELECT * FROM ${KnowledgeSchema.T_DOCUMENT} WHERE account_id = ?`, [accountId]);
    const out: KnowledgeDocument[] = [];
    try {
      if (rs.goToFirstRow()) {
        do {
          out.push(RdbKnowledgeRepository.readDocument(rs));
        } while (rs.goToNextRow());
      }
    } finally {
      rs.close();
    }
    return out;
  }

  private async queryAllChunks(db: relationalStore.RdbStore, accountId: number): Promise<KnowledgeChunkRow[]> {
    const rs = await db.querySql(`SELECT * FROM ${KnowledgeSchema.T_CHUNK} WHERE account_id = ?`, [accountId]);
    const out: KnowledgeChunkRow[] = [];
    try {
      if (rs.goToFirstRow()) {
        do {
          out.push(RdbKnowledgeRepository.readChunkRow(rs));
        } while (rs.goToNextRow());
      }
    } finally {
      rs.close();
    }
    return out;
  }

  // MARK: - 私有：写入

  /** 重建文档文本切块（无向量，仅文本），对齐 iOS rebuildChunks(for:ownerAccountID:context:)。 */
  private async rebuildChunksInternal(
    db: relationalStore.RdbStore,
    accountId: number,
    documentId: string,
    content: string,
    timestamp: string
  ): Promise<void> {
    await this.deleteChunksInternal(db, accountId, documentId);
    const chunks = RdbKnowledgeRepository.chunkContent(content, 480);
    for (let i = 0; i < chunks.length; i++) {
      const chunkId = util.generateRandomUUID(true);
      await db.executeSql(`INSERT INTO ${KnowledgeSchema.T_CHUNK}
        (id, account_id, document_id, sequence, content, vector_data, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, NULL, ?, ?)`, [chunkId, accountId, documentId, i, chunks[i], timestamp, timestamp]);
    }
    await db.executeSql(`UPDATE ${KnowledgeSchema.T_DOCUMENT}
      SET chunk_count = ?, is_embedding_indexed = 0, last_embedding_model_name = NULL
      WHERE account_id = ? AND id = ?`, [chunks.length, accountId, documentId]);
    Logger.info('knowledge.chunks_rebuilt', LogModule.DATABASE);
  }

  private async deleteChunksInternal(db: relationalStore.RdbStore, accountId: number, documentId: string): Promise<void> {
    await db.executeSql(`DELETE FROM ${KnowledgeSchema.T_CHUNK} WHERE account_id = ? AND document_id = ?`,
      [accountId, documentId]);
  }

  // MARK: - 私有：校验、切块、检索打分（纯函数，对齐 iOS 同名私有方法）

  /** 校验并清理文档草稿，对齐 iOS validate(_:)。 */
  private static validateDraft(draft: KnowledgeDocumentDraft): KnowledgeDocumentDraft {
    const title = draft.title.trim();
    const content = draft.content.trim();
    return new KnowledgeDocumentDraft(
      title.length === 0 ? 'Untitled Document' : title,
      content,
      draft.scope,
      draft.boundModelID?.trim(),
      draft.source
    );
  }

  /** 文本智能切块（按段落、长度拆分），对齐 iOS chunkContent(_:maxLength:)。 */
  private static chunkContent(content: string, maxLength: number): string[] {
    const normalized = content.replace(/\r\n/g, '\n');
    const paragraphs = normalized.split('\n\n');
    const chunks: string[] = [];
    let buffer = '';

    for (const paragraph of paragraphs) {
      const trimmed = paragraph.trim();
      if (trimmed.length === 0) {
        continue;
      }
      if (buffer.length === 0) {
        if (trimmed.length <= maxLength) {
          buffer = trimmed;
          continue;
        }
      } else if (buffer.length + 2 + trimmed.length <= maxLength) {
        buffer += `\n\n${trimmed}`;
        continue;
      } else {
        chunks.push(buffer);
        buffer = '';
      }

      if (trimmed.length <= maxLength) {
        buffer = trimmed;
        continue;
      }

      let remainder = trimmed;
      while (remainder.length > 0) {
        const prefix = remainder.substring(0, maxLength);
        chunks.push(prefix);
        remainder = remainder.substring(prefix.length);
      }
    }

    if (buffer.length > 0) {
      chunks.push(buffer);
    }
    return chunks.length === 0 ? [content] : chunks;
  }

  /** 生成摘要，对齐 iOS makeExcerpt(from:limit:)。 */
  private static makeExcerpt(content: string, limit: number): string {
    const compact = content
      .replace(/\n/g, ' ')
      .replace(/\t/g, ' ')
      .trim();
    if (compact.length <= limit) {
      return compact;
    }
    return `${compact.substring(0, limit)}...`;
  }

  /**
   * 搜索分词，对齐 iOS tokenize(_:)：按非字母数字切分。
   * 未使用 Unicode 属性转义（\p{L}），避免依赖 ArkTS 正则引擎的 `u` 模式支持；
   * 用 ASCII 字母数字 + À 以上区段（含中日韩、重音字母等）近似 CharacterSet.alphanumerics。
   */
  private static tokenize(query: string): string[] {
    return query
      .toLowerCase()
      .split(/[^a-z0-9À-￿]+/)
      .filter((token: string): boolean => token.length > 0);
  }

  /** 关键词匹配评分，对齐 iOS score(text:tokens:)。 */
  private static score(text: string, tokens: string[]): number {
    if (tokens.length === 0) {
      return 0;
    }
    const haystack = text.toLowerCase();
    let total = 0;
    for (const token of tokens) {
      if (haystack.includes(token)) {
        total += 1.0 + RdbKnowledgeRepository.occurrences(token, haystack) * 0.2;
      }
    }
    return total;
  }

  /** 统计关键词出现次数，对齐 iOS occurrences(of:in:)。 */
  private static occurrences(needle: string, haystack: string): number {
    if (needle.length === 0) {
      return 0;
    }
    return Math.max(haystack.split(needle).length - 1, 0);
  }

  /** 生成命中关键词居中的摘要，对齐 iOS bestExcerpt(in:query:fallback:)。 */
  private static bestExcerpt(content: string, query: string, fallback: string): string {
    const normalized = content.replace(/\n/g, ' ');
    const lowercase = normalized.toLowerCase();
    const token = query.toLowerCase();
    const hitIndex = lowercase.indexOf(token);
    if (hitIndex < 0) {
      return RdbKnowledgeRepository.makeExcerpt(fallback, 140);
    }
    const startOffset = Math.max(hitIndex - 60, 0);
    const excerpt = normalized.substring(startOffset).trim();
    return RdbKnowledgeRepository.makeExcerpt(excerpt, 160);
  }

  /** 关键词检索（词法匹配），对齐 iOS lexicalSearchMatches(documents:chunks:query:)。 */
  private static lexicalSearchMatches(
    documents: KnowledgeDocument[],
    chunks: KnowledgeChunkRow[],
    query: string
  ): Map<string, KnowledgeSearchResult> {
    const queryTokens = RdbKnowledgeRepository.tokenize(query);
    const lowerQuery = query.toLowerCase();
    const bestMatches = new Map<string, KnowledgeSearchResult>();

    for (const document of documents) {
      const exactTitleHit = document.title.toLowerCase().includes(lowerQuery);
      const exactContentHit = document.content.toLowerCase().includes(lowerQuery);
      const baseScore = RdbKnowledgeRepository.score(document.title, queryTokens) * 3.0
        + RdbKnowledgeRepository.score(document.content, queryTokens)
        + (exactTitleHit ? 6.0 : 0.0)
        + (exactContentHit ? 2.0 : 0.0);

      if (baseScore > 0) {
        const result = new KnowledgeSearchResult();
        result.documentID = document.id;
        result.title = document.title;
        result.excerpt = RdbKnowledgeRepository.bestExcerpt(document.content, query, document.excerpt);
        result.matchedChunkSequence = undefined;
        result.score = baseScore;
        bestMatches.set(document.id, result);
      }
    }

    for (const chunk of chunks) {
      if (chunk.content.length === 0) {
        continue;
      }
      const tokenScore = RdbKnowledgeRepository.score(chunk.content, queryTokens);
      const exactHit = chunk.content.toLowerCase().includes(lowerQuery);
      const candidateScore = tokenScore * 2.0 + (exactHit ? 4.0 : 0.0);
      if (candidateScore <= 0) {
        continue;
      }

      const current = bestMatches.get(chunk.documentID);
      if (!current || candidateScore > current.score) {
        const matchedDoc = documents.find((d: KnowledgeDocument): boolean => d.id === chunk.documentID);
        const title: string = current ? current.title : (matchedDoc ? matchedDoc.title : 'Untitled');
        const result = new KnowledgeSearchResult();
        result.documentID = chunk.documentID;
        result.title = title;
        result.excerpt = RdbKnowledgeRepository.bestExcerpt(chunk.content, query, chunk.content);
        result.matchedChunkSequence = chunk.sequence;
        result.score = candidateScore;
        bestMatches.set(chunk.documentID, result);
      }
    }

    return bestMatches;
  }

  /** 结果排序（按得分降序，同分按标题升序），对齐 iOS sortedResults(from:limit:)。 */
  private static sortedResults(map: Map<string, KnowledgeSearchResult>, limit: number): KnowledgeSearchResult[] {
    const values = Array.from(map.values());
    values.sort((lhs: KnowledgeSearchResult, rhs: KnowledgeSearchResult): number => {
      if (lhs.score === rhs.score) {
        return lhs.title.localeCompare(rhs.title);
      }
      return rhs.score - lhs.score;
    });
    return values.slice(0, Math.max(limit, 1));
  }

  // MARK: - 私有：Row 读取（ResultSet → 领域/内部模型）

  private static readDocument(rs: relationalStore.ResultSet): KnowledgeDocument {
    const doc = new KnowledgeDocument();
    doc.id = RdbKnowledgeRepository.colStr(rs, 'id');
    doc.title = RdbKnowledgeRepository.colStr(rs, 'title');
    doc.content = RdbKnowledgeRepository.colStr(rs, 'content');
    doc.excerpt = RdbKnowledgeRepository.colStr(rs, 'excerpt');
    doc.scope = parseKnowledgeDocumentScope(RdbKnowledgeRepository.colOpt(rs, 'scope'));
    doc.boundModelID = RdbKnowledgeRepository.colOpt(rs, 'bound_model_id');
    doc.source = parseKnowledgeDocumentSource(RdbKnowledgeRepository.colOpt(rs, 'source'));
    doc.chunkCount = RdbKnowledgeRepository.colLong(rs, 'chunk_count', 0);
    doc.isEmbeddingIndexed = RdbKnowledgeRepository.colLong(rs, 'is_embedding_indexed', 0) !== 0;
    doc.lastEmbeddingModelName = RdbKnowledgeRepository.colOpt(rs, 'last_embedding_model_name');
    doc.createdAt = RdbKnowledgeRepository.colStr(rs, 'created_at');
    doc.updatedAt = RdbKnowledgeRepository.colStr(rs, 'updated_at');
    return doc;
  }

  private static readChunkRow(rs: relationalStore.ResultSet): KnowledgeChunkRow {
    const row = new KnowledgeChunkRow();
    row.documentID = RdbKnowledgeRepository.colStr(rs, 'document_id');
    row.content = RdbKnowledgeRepository.colStr(rs, 'content');
    row.sequence = RdbKnowledgeRepository.colLong(rs, 'sequence', 0);
    row.vectorData = RdbKnowledgeRepository.colBlob(rs, 'vector_data');
    return row;
  }

  private static colStr(rs: relationalStore.ResultSet, name: string): string {
    const i = rs.getColumnIndex(name);
    return i < 0 || rs.isColumnNull(i) ? '' : rs.getString(i);
  }

  private static colOpt(rs: relationalStore.ResultSet, name: string): string | undefined {
    const i = rs.getColumnIndex(name);
    return i < 0 || rs.isColumnNull(i) ? undefined : rs.getString(i);
  }

  private static colLong(rs: relationalStore.ResultSet, name: string, fallback: number): number {
    const i = rs.getColumnIndex(name);
    return i < 0 || rs.isColumnNull(i) ? fallback : rs.getLong(i);
  }

  private static colBlob(rs: relationalStore.ResultSet, name: string): Uint8Array | undefined {
    const i = rs.getColumnIndex(name);
    return i < 0 || rs.isColumnNull(i) ? undefined : rs.getBlob(i);
  }
}

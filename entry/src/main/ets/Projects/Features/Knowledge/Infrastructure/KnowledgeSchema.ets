/**
 * Knowledge 模块表 DDL（注册到 spark_client.db）。
 * 对应 iOS Core Data KnowledgeDocumentEntity / KnowledgeChunkEntity。
 */
export class KnowledgeSchema {
  static readonly T_DOCUMENT: string = 'knowledge_document';
  static readonly T_CHUNK: string = 'knowledge_chunk';

  static ddlStatements(): string[] {
    return [
      `CREATE TABLE IF NOT EXISTS knowledge_document (
        id TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        excerpt TEXT NOT NULL DEFAULT '',
        scope TEXT NOT NULL DEFAULT 'personal',
        bound_model_id TEXT,
        source TEXT NOT NULL DEFAULT 'user',
        chunk_count INTEGER NOT NULL DEFAULT 0,
        is_embedding_indexed INTEGER NOT NULL DEFAULT 0,
        last_embedding_model_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, id)
      )`,
      `CREATE INDEX IF NOT EXISTS idx_knowledge_document_updated
        ON knowledge_document(account_id, updated_at DESC)`,
      `CREATE TABLE IF NOT EXISTS knowledge_chunk (
        id TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        document_id TEXT NOT NULL,
        sequence INTEGER NOT NULL DEFAULT 0,
        content TEXT NOT NULL DEFAULT '',
        vector_data BLOB,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, id)
      )`,
      `CREATE INDEX IF NOT EXISTS idx_knowledge_chunk_document
        ON knowledge_chunk(account_id, document_id, sequence)`
    ];
  }

  static ensureColumnStatements(): string[] {
    return [];
  }
}

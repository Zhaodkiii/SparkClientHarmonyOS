/** 文件缓存表 DDL（注册到 spark_client.db，不拥有库文件）。全新项目固定 version=1。 */
export class FileCacheSchema {
  static readonly MODULE_VERSION: number = 1;

  static readonly T_FILE_CACHE: string = 'file_cache_record';

  static ddlStatements(): string[] {
    return [
      `CREATE TABLE IF NOT EXISTS file_cache_record (
        account_id_hash TEXT NOT NULL,
        file_id INTEGER NOT NULL,
        file_uuid TEXT NOT NULL,
        local_path TEXT NOT NULL,
        original_name TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        file_md5 TEXT,
        object_key TEXT,
        state TEXT NOT NULL,
        mime_type TEXT,
        business_type TEXT,
        business_id TEXT,
        is_public INTEGER NOT NULL DEFAULT 0,
        last_accessed_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (account_id_hash, file_uuid)
      )`,
      `CREATE INDEX IF NOT EXISTS idx_file_cache_account_access
        ON file_cache_record(account_id_hash, last_accessed_at)`,
      `CREATE INDEX IF NOT EXISTS idx_file_cache_account_state
        ON file_cache_record(account_id_hash, state)`,
      `CREATE INDEX IF NOT EXISTS idx_file_cache_account_file_id
        ON file_cache_record(account_id_hash, file_id)`
    ];
  }

  /** 已有库补列（列已存在时由调用方忽略错误）。 */
  static ensureColumnStatements(): string[] {
    return [
      'ALTER TABLE file_cache_record ADD COLUMN mime_type TEXT',
      'ALTER TABLE file_cache_record ADD COLUMN business_type TEXT',
      'ALTER TABLE file_cache_record ADD COLUMN business_id TEXT',
      'ALTER TABLE file_cache_record ADD COLUMN is_public INTEGER NOT NULL DEFAULT 0'
    ];
  }
}

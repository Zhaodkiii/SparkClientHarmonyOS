/** AI 模块表 DDL（注册到 spark_client.db，不拥有库文件）。全新项目固定 version=1。 */
export class AIConfigSchema {
  static readonly MODULE_VERSION: number = 1;
  static readonly SEED_VERSION: number = 1;

  static readonly T_ACCOUNT_META: string = 'ai_account_meta';
  static readonly T_PROVIDER: string = 'ai_provider';
  static readonly T_MODEL: string = 'ai_model';
  static readonly T_BINDING: string = 'ai_scenario_binding';
  static readonly T_SMALL_TASK: string = 'ai_small_task';
  static readonly T_MODEL_FILE: string = 'ai_model_file';
  static readonly T_PREFERENCES: string = 'ai_preferences';

  static ddlStatements(): string[] {
    return [
      `CREATE TABLE IF NOT EXISTS ai_account_meta (
        account_id INTEGER PRIMARY KEY,
        schema_version INTEGER NOT NULL,
        seed_version INTEGER,
        seeded_at TEXT,
        remote_revision TEXT,
        remote_etag TEXT,
        last_remote_sync_at TEXT,
        sync_state TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )`,
      `CREATE TABLE IF NOT EXISTS ai_provider (
        id TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        company TEXT NOT NULL,
        kind TEXT NOT NULL,
        request_url TEXT,
        secret_ref TEXT,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        position INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, id),
        FOREIGN KEY (account_id) REFERENCES ai_account_meta(account_id) ON DELETE CASCADE
      )`,
      `CREATE TABLE IF NOT EXISTS ai_model (
        id TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        provider_id TEXT NOT NULL,
        name TEXT NOT NULL,
        display_name TEXT NOT NULL,
        base_model_name TEXT,
        model_type TEXT NOT NULL,
        capabilities_json TEXT NOT NULL,
        context_window INTEGER,
        price_tier TEXT,
        is_default INTEGER NOT NULL DEFAULT 0,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        source TEXT NOT NULL,
        identity TEXT,
        system_provision TEXT,
        icon TEXT,
        brief_description TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, id),
        FOREIGN KEY (account_id, provider_id) REFERENCES ai_provider(account_id, id) ON DELETE CASCADE
      )`,
      `CREATE TABLE IF NOT EXISTS ai_scenario_binding (
        account_id INTEGER NOT NULL,
        scenario TEXT NOT NULL,
        model_id TEXT NOT NULL,
        temperature REAL,
        max_tokens INTEGER,
        system_provision TEXT,
        is_default INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0,
        enabled INTEGER NOT NULL DEFAULT 1,
        source TEXT NOT NULL,
        related_task_codes TEXT,
        ai_tool_scenarios TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, scenario, model_id),
        FOREIGN KEY (account_id, model_id) REFERENCES ai_model(account_id, id) ON DELETE CASCADE
      )`,
      `CREATE TABLE IF NOT EXISTS ai_small_task (
        account_id INTEGER NOT NULL,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        brief TEXT,
        prompt TEXT NOT NULL,
        icon TEXT,
        tool_list_json TEXT NOT NULL,
        source TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, code)
      )`,
      `CREATE TABLE IF NOT EXISTS ai_model_file (
        account_id INTEGER NOT NULL,
        model_id TEXT NOT NULL,
        path TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        sha256 TEXT NOT NULL,
        download_state TEXT NOT NULL,
        downloaded_at TEXT,
        error_code TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, model_id),
        FOREIGN KEY (account_id, model_id) REFERENCES ai_model(account_id, id) ON DELETE CASCADE
      )`,
      `CREATE TABLE IF NOT EXISTS ai_preferences (
        account_id INTEGER PRIMARY KEY,
        default_source TEXT NOT NULL,
        allow_network INTEGER NOT NULL DEFAULT 1,
        allow_local_model INTEGER NOT NULL DEFAULT 1,
        selected_provider_id TEXT,
        selected_model_id TEXT,
        extras_json TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES ai_account_meta(account_id) ON DELETE CASCADE
      )`,
      `CREATE INDEX IF NOT EXISTS idx_ai_provider_account_enabled ON ai_provider(account_id, is_enabled, position)`,
      `CREATE INDEX IF NOT EXISTS idx_ai_provider_kind_source ON ai_provider(account_id, kind, source)`,
      `CREATE INDEX IF NOT EXISTS idx_ai_model_account_provider ON ai_model(account_id, provider_id, is_enabled)`,
      `CREATE INDEX IF NOT EXISTS idx_ai_model_source ON ai_model(account_id, source, model_type)`,
      `CREATE INDEX IF NOT EXISTS idx_ai_binding_account_scenario ON ai_scenario_binding(account_id, scenario, enabled, position)`,
      `CREATE INDEX IF NOT EXISTS idx_ai_task_account_enabled ON ai_small_task(account_id, enabled, code)`,
      `CREATE INDEX IF NOT EXISTS idx_ai_file_account_state ON ai_model_file(account_id, download_state)`
    ];
  }
}

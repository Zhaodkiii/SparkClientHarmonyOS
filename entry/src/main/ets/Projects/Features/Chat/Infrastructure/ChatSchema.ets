/** Chat 模块表 DDL（注册到 spark_client.db） */
export class ChatSchema {
  static readonly T_THREAD: string = 'chat_thread';
  static readonly T_MESSAGE: string = 'chat_message';
  static readonly T_BLOCK: string = 'chat_message_block';
  static readonly T_CURSOR: string = 'chat_sync_cursor';
  static readonly T_ATTACHMENT: string = 'chat_attachment_download';
  static readonly T_AUDIT: string = 'chat_tool_audit';

  static ddlStatements(): string[] {
    return [
      `CREATE TABLE IF NOT EXISTS chat_thread (
        client_id TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        preferred_model_name TEXT,
        member_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        thread_id TEXT,
        scenario TEXT NOT NULL DEFAULT 'chat',
        patient_id TEXT,
        server_updated_at TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        temperature REAL,
        top_p REAL NOT NULL DEFAULT 1.0,
        max_tokens INTEGER,
        max_messages INTEGER NOT NULL DEFAULT 20,
        role_prompt TEXT NOT NULL DEFAULT '',
        image_delivery_mode TEXT,
        icon_name TEXT,
        icon_color_name TEXT,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        pinned_at TEXT,
        PRIMARY KEY (account_id, client_id)
      )`,
      `CREATE TABLE IF NOT EXISTS chat_message (
        client_id TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        thread_client_id TEXT NOT NULL,
        role TEXT NOT NULL,
        kind TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        delivery_status TEXT NOT NULL,
        request_id TEXT,
        error_code TEXT,
        server_message_id TEXT,
        thread_id TEXT,
        model_name TEXT,
        tombstone INTEGER NOT NULL DEFAULT 0,
        server_updated_at TEXT,
        attachments_json TEXT NOT NULL DEFAULT '[]',
        reasoning_content TEXT,
        reasoning_duration_ms INTEGER,
        reasoning_expanded INTEGER NOT NULL DEFAULT 0,
        reasoning_visibility TEXT,
        sync_state TEXT NOT NULL DEFAULT 'pending',
        sync_attempt_count INTEGER NOT NULL DEFAULT 0,
        last_sync_error TEXT,
        local_revision INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, client_id)
      )`,
      `CREATE TABLE IF NOT EXISTS chat_message_block (
        block_id TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        message_client_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        tool_name TEXT,
        tool_call_id TEXT,
        status TEXT NOT NULL DEFAULT 'ready',
        parent_tool_call_id TEXT,
        parent_block_id TEXT,
        node_role TEXT NOT NULL DEFAULT 'timeline',
        anchor_json TEXT,
        payload_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL DEFAULT '',
        server_updated_at TEXT,
        sync_state TEXT NOT NULL DEFAULT 'pending',
        order_key REAL NOT NULL DEFAULT 0,
        revision INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, block_id)
      )`,
      `CREATE INDEX IF NOT EXISTS idx_chat_message_thread
        ON chat_message(account_id, thread_client_id, created_at)`,
      `CREATE INDEX IF NOT EXISTS idx_chat_block_message
        ON chat_message_block(account_id, message_client_id, order_key)`,
      `CREATE TABLE IF NOT EXISTS chat_sync_cursor (
        account_id INTEGER NOT NULL,
        cursor_key TEXT NOT NULL,
        cursor_value TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, cursor_key)
      )`,
      `CREATE TABLE IF NOT EXISTS chat_attachment_download (
        id TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        dedupe_key TEXT NOT NULL,
        attachment_id TEXT NOT NULL,
        client_message_id TEXT NOT NULL,
        thread_client_id TEXT NOT NULL,
        payload_json TEXT NOT NULL DEFAULT '{}',
        state TEXT NOT NULL DEFAULT 'pending',
        local_file_path TEXT,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, id),
        UNIQUE (account_id, dedupe_key)
      )`,
      `CREATE TABLE IF NOT EXISTS chat_tool_audit (
        id TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        thread_id TEXT,
        request_id TEXT,
        tool_name TEXT NOT NULL,
        status TEXT NOT NULL,
        input_summary TEXT NOT NULL DEFAULT '',
        output_summary TEXT NOT NULL DEFAULT '',
        member_id INTEGER,
        created_at TEXT NOT NULL,
        PRIMARY KEY (account_id, id)
      )`,
      `CREATE INDEX IF NOT EXISTS idx_chat_audit_created ON chat_tool_audit(account_id, created_at DESC)`,
      `CREATE INDEX IF NOT EXISTS idx_chat_cursor_key ON chat_sync_cursor(account_id, cursor_key)`
    ];
  }

  static ensureColumnStatements(): string[] {
    return [
      'ALTER TABLE chat_thread ADD COLUMN thread_id TEXT',
      'ALTER TABLE chat_thread ADD COLUMN server_updated_at TEXT',
      'ALTER TABLE chat_message ADD COLUMN server_message_id TEXT',
      'ALTER TABLE chat_message ADD COLUMN server_updated_at TEXT',
      'ALTER TABLE chat_message ADD COLUMN sync_state TEXT NOT NULL DEFAULT \'pending\'',
      'ALTER TABLE chat_message ADD COLUMN local_revision INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE chat_message_block ADD COLUMN payload_json TEXT NOT NULL DEFAULT \'{}\'',
      'ALTER TABLE chat_message_block ADD COLUMN server_updated_at TEXT'
      , 'ALTER TABLE chat_message_block ADD COLUMN sync_state TEXT NOT NULL DEFAULT \'pending\''
    ];
  }
}

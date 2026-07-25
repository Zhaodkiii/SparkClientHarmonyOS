import { relationalStore } from '@kit.ArkData';
import { AppRelationalDatabase } from '../../../../Core/Storage/AppRelationalDatabase';
import {
  ChatMessage,
  ChatMessageBlock,
  ChatThread,
  ChatDeliveryStatus,
  ChatMessageKind,
  ChatMessageRole,
  ChatBlockKind
} from '../Domain/ChatModels';
import { ChatAttachmentDownloadJob, ChatNewId, ChatPendingMessageBlock } from '../Domain/ChatModels';
import { ChatSchema } from './ChatSchema';
import { ChatLocalChangeHub } from './ChatLocalChangeHub';

/**
 * Chat 持久化唯一入口。所有账号键均位于 SQL WHERE/PRIMARY KEY 中；
 * 上送/入站/流式块写入共用 AppRdbWriteQueue，避免 RDB 并发写导致乱序。
 */
export class ChatRepository {
  private readonly database: AppRelationalDatabase;

  constructor(database: AppRelationalDatabase) {
    this.database = database;
  }

  async upsertThread(thread: ChatThread, notifyLocalChange: boolean = true): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(`INSERT OR REPLACE INTO ${ChatSchema.T_THREAD}
        (client_id, account_id, title, preferred_model_name, member_id, created_at, updated_at,
         thread_id, scenario, patient_id, server_updated_at, is_deleted, deleted_at,
         temperature, top_p, max_tokens, max_messages, role_prompt, image_delivery_mode,
         icon_name, icon_color_name, is_pinned, pinned_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, [
        thread.clientId, thread.accountId, thread.title, thread.preferredModelName ?? null,
        thread.memberId ?? null, thread.createdAt, thread.updatedAt, thread.threadId || thread.clientId,
        thread.scenario, thread.patientId ?? null, thread.serverUpdatedAt ?? thread.updatedAt,
        thread.isDeleted ? 1 : 0, thread.deletedAt ?? null, thread.temperature ?? null,
        thread.topP, thread.maxTokens ?? null, thread.maxMessages, thread.rolePrompt,
        thread.imageDeliveryMode ?? null, thread.iconName ?? null, thread.iconColorName ?? null,
        thread.isPinned ? 1 : 0, thread.pinnedAt ?? null
      ]);
    });
    if (notifyLocalChange) {
      ChatLocalChangeHub.publish('threadsChanged', thread.threadId || thread.clientId, true);
    }
  }

  /** 对齐 iOS updateThreadGenerationConfig。 */
  async updateThreadGenerationConfig(
    accountId: number,
    threadClientId: string,
    currentModelName: string | undefined,
    temperature: number | undefined,
    topP: number,
    maxTokens: number | undefined,
    maxMessages: number,
    rolePrompt: string
  ): Promise<void> {
    const thread = await this.findThreadByRemoteId(accountId, threadClientId);
    if (!thread) {
      return;
    }
    thread.preferredModelName = currentModelName;
    thread.temperature = temperature;
    thread.topP = topP;
    thread.maxTokens = maxTokens;
    thread.maxMessages = maxMessages;
    thread.rolePrompt = rolePrompt;
    thread.updatedAt = new Date().toISOString();
    await this.upsertThread(thread);
  }

  /** 仅更新会话 rolePrompt，避免系统消息设置重复传 generation 参数。 */
  async updateThreadRolePrompt(
    accountId: number,
    threadClientId: string,
    rolePrompt: string
  ): Promise<void> {
    const thread = await this.findThreadByRemoteId(accountId, threadClientId);
    if (!thread) {
      return;
    }
    thread.rolePrompt = rolePrompt;
    thread.updatedAt = new Date().toISOString();
    await this.upsertThread(thread);
  }

  async listThreads(accountId: number): Promise<ChatThread[]> {
    const db = await this.database.open();
    const rs = await db.querySql(`SELECT * FROM ${ChatSchema.T_THREAD}
      WHERE account_id = ? AND is_deleted = 0 ORDER BY is_pinned DESC, updated_at DESC`, [accountId]);
    const out: ChatThread[] = [];
    try {
      if (rs.goToFirstRow()) {
        do { out.push(ChatRepository.readThread(rs)); } while (rs.goToNextRow());
      }
    } finally { rs.close(); }
    return out;
  }

  async findThreadByRemoteId(accountId: number, threadId: string): Promise<ChatThread | undefined> {
    const db = await this.database.open();
    const rs = await db.querySql(`SELECT * FROM ${ChatSchema.T_THREAD}
      WHERE account_id = ? AND (thread_id = ? OR client_id = ?) LIMIT 1`, [accountId, threadId, threadId]);
    try {
      return rs.goToFirstRow() ? ChatRepository.readThread(rs) : undefined;
    } finally { rs.close(); }
  }

  /**
   * 将早期鸿蒙版本生成的 c_... / chat_... 标识迁移为服务端可接受的 UUID。
   * 迁移保持 client/thread/message/block/attachment 的本地关联，并按 account_id 隔离。
   */
  async normalizeLegacyIdentifiers(accountId: number): Promise<void> {
    if (accountId <= 0) return;
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      const threadRs = await db.querySql(`SELECT client_id, thread_id FROM ${ChatSchema.T_THREAD} WHERE account_id = ?`, [accountId]);
      try {
        if (threadRs.goToFirstRow()) {
          do {
            const clientId = ChatRepository.str(threadRs, 'client_id');
            const remoteId = ChatRepository.opt(threadRs, 'thread_id');
            if (ChatNewId.isUUID(clientId) && ChatNewId.isUUID(remoteId)) continue;
            const canonical = ChatNewId.isUUID(remoteId) ? remoteId as string : ChatNewId.uuidLike();
            await db.executeSql(`UPDATE ${ChatSchema.T_MESSAGE} SET thread_client_id = ?, thread_id = ? WHERE account_id = ? AND (thread_client_id = ? OR thread_id = ?)`,
              [canonical, canonical, accountId, clientId, clientId]);
            await db.executeSql(`UPDATE ${ChatSchema.T_ATTACHMENT} SET thread_client_id = ? WHERE account_id = ? AND thread_client_id = ?`, [canonical, accountId, clientId]);
            await db.executeSql(`UPDATE ${ChatSchema.T_THREAD} SET client_id = ?, thread_id = ? WHERE account_id = ? AND client_id = ?`, [canonical, canonical, accountId, clientId]);
          } while (threadRs.goToNextRow());
        }
      } finally { threadRs.close(); }

      const messageRs = await db.querySql(`SELECT client_id FROM ${ChatSchema.T_MESSAGE} WHERE account_id = ?`, [accountId]);
      try {
        if (messageRs.goToFirstRow()) {
          do {
            const oldId = ChatRepository.str(messageRs, 'client_id');
            if (ChatNewId.isUUID(oldId)) continue;
            const newId = ChatNewId.uuidLike();
            await db.executeSql(`UPDATE ${ChatSchema.T_BLOCK} SET message_client_id = ? WHERE account_id = ? AND message_client_id = ?`, [newId, accountId, oldId]);
            await db.executeSql(`UPDATE ${ChatSchema.T_ATTACHMENT} SET client_message_id = ? WHERE account_id = ? AND client_message_id = ?`, [newId, accountId, oldId]);
            await db.executeSql(`UPDATE ${ChatSchema.T_MESSAGE} SET client_id = ? WHERE account_id = ? AND client_id = ?`, [newId, accountId, oldId]);
          } while (messageRs.goToNextRow());
        }
      } finally { messageRs.close(); }

      const blockRs = await db.querySql(`SELECT block_id FROM ${ChatSchema.T_BLOCK} WHERE account_id = ?`, [accountId]);
      try {
        if (blockRs.goToFirstRow()) {
          do {
            const oldId = ChatRepository.str(blockRs, 'block_id');
            if (ChatNewId.isUUID(oldId)) continue;
            const newId = ChatNewId.uuidLike();
            await db.executeSql(`UPDATE ${ChatSchema.T_BLOCK} SET parent_block_id = ? WHERE account_id = ? AND parent_block_id = ?`, [newId, accountId, oldId]);
            await db.executeSql(`UPDATE ${ChatSchema.T_BLOCK} SET block_id = ? WHERE account_id = ? AND block_id = ?`, [newId, accountId, oldId]);
          } while (blockRs.goToNextRow());
        }
      } finally { blockRs.close(); }

      // 旧游标键携带非法 thread_id，删除后由 canonical thread_id 重新建立。
      await db.executeSql(`DELETE FROM ${ChatSchema.T_CURSOR} WHERE account_id = ? AND cursor_key LIKE 'chat.thread.message.cursor.%'`, [accountId]);
    });
  }

  /** 同步专用读模型：包含本地软删除线程，确保删除 tombstone 能上送服务端。 */
  async listThreadsForSync(accountId: number): Promise<ChatThread[]> {
    const db = await this.database.open();
    const rs = await db.querySql(`SELECT * FROM ${ChatSchema.T_THREAD}
      WHERE account_id = ? ORDER BY updated_at ASC`, [accountId]);
    const out: ChatThread[] = [];
    try {
      if (rs.goToFirstRow()) {
        do { out.push(ChatRepository.readThread(rs)); } while (rs.goToNextRow());
      }
    } finally { rs.close(); }
    return out;
  }

  async softDeleteThread(accountId: number, threadClientId: string): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      const now = new Date().toISOString();
      await db.executeSql(`UPDATE ${ChatSchema.T_THREAD}
        SET is_deleted = 1, deleted_at = ?, updated_at = ?, server_updated_at = NULL
        WHERE account_id = ? AND client_id = ?`, [now, now, accountId, threadClientId]);
    });
  }

  async upsertMessage(
    message: ChatMessage,
    markBlocksPending: boolean = true,
    notifyLocalChange: boolean = true
  ): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(`INSERT OR REPLACE INTO ${ChatSchema.T_MESSAGE}
        (client_id, account_id, thread_client_id, role, kind, text, delivery_status,
         request_id, error_code, created_at, updated_at, server_message_id, thread_id,
         model_name, tombstone, server_updated_at, attachments_json, reasoning_content,
         reasoning_duration_ms, reasoning_expanded, reasoning_visibility, sync_state,
         sync_attempt_count, last_sync_error, local_revision)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, [
        message.clientId, message.accountId, message.threadClientId, message.role, message.kind,
        message.text, message.deliveryStatus, message.requestId ?? null, message.errorCode ?? null,
        message.createdAt, message.updatedAt, message.serverMessageId ?? null,
        message.threadId || message.threadClientId, message.modelName ?? null, message.tombstone ? 1 : 0,
        message.serverUpdatedAt ?? null, message.attachmentsJson, message.reasoningContent ?? null,
        message.reasoningDurationMs ?? null, message.reasoningExpanded ? 1 : 0,
        message.reasoningVisibility ?? null, message.syncState, message.syncAttemptCount,
        message.lastSyncError ?? null, message.localRevision
      ]);
    });
    for (let i = 0; i < message.blocks.length; i++) {
      await this.upsertBlock(message.accountId, message.clientId, message.blocks[i], markBlocksPending);
    }
    if (notifyLocalChange && markBlocksPending &&
      (message.syncState === 'pending' || message.syncState === 'sending')) {
      ChatLocalChangeHub.publish('messagesAppended', message.threadId || message.threadClientId, true);
    }
  }

  async updateMessageStatus(accountId: number, clientId: string, status: ChatDeliveryStatus,
    text?: string, errorCode?: string, markPendingForSync: boolean = false): Promise<void> {
    let threadId: string | undefined = undefined;
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      const now = new Date().toISOString();
      if (markPendingForSync) {
        const sql = text !== undefined
          ? `UPDATE ${ChatSchema.T_MESSAGE} SET delivery_status = ?, text = ?, error_code = ?, sync_state = 'pending', updated_at = ? WHERE account_id = ? AND client_id = ?`
          : `UPDATE ${ChatSchema.T_MESSAGE} SET delivery_status = ?, error_code = ?, sync_state = 'pending', updated_at = ? WHERE account_id = ? AND client_id = ?`;
        const args = text !== undefined
          ? [status, text, errorCode ?? null, now, accountId, clientId]
          : [status, errorCode ?? null, now, accountId, clientId];
        await db.executeSql(sql, args);
      } else {
        const sql = text !== undefined
          ? `UPDATE ${ChatSchema.T_MESSAGE} SET delivery_status = ?, text = ?, error_code = ?, updated_at = ? WHERE account_id = ? AND client_id = ?`
          : `UPDATE ${ChatSchema.T_MESSAGE} SET delivery_status = ?, error_code = ?, updated_at = ? WHERE account_id = ? AND client_id = ?`;
        const args = text !== undefined
          ? [status, text, errorCode ?? null, now, accountId, clientId]
          : [status, errorCode ?? null, now, accountId, clientId];
        await db.executeSql(sql, args);
      }
      const rs = await db.querySql(
        `SELECT thread_client_id, thread_id FROM ${ChatSchema.T_MESSAGE} WHERE account_id = ? AND client_id = ? LIMIT 1`,
        [accountId, clientId]
      );
      try {
        if (rs.goToFirstRow()) {
          threadId = ChatRepository.opt(rs, 'thread_id') ?? ChatRepository.str(rs, 'thread_client_id');
        }
      } finally {
        rs.close();
      }
    });
    if (markPendingForSync) {
      ChatLocalChangeHub.publish('messagesUpdated', threadId, true);
    }
  }

  /** 对齐 iOS RetryFailedMessageUseCase：失败消息重新进入 outbox。 */
  async retryMessage(accountId: number, clientId: string): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(`UPDATE ${ChatSchema.T_MESSAGE}
        SET delivery_status = 'pending', sync_state = 'pending', error_code = NULL,
            last_sync_error = NULL, updated_at = ?, sync_attempt_count = sync_attempt_count + 1
        WHERE account_id = ? AND client_id = ? AND delivery_status IN ('failed','cancelled')`,
        [new Date().toISOString(), accountId, clientId]);
    });
  }

  async upsertBlock(accountId: number, messageClientId: string, block: ChatMessageBlock,
    markParentPending: boolean = true): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(`INSERT OR REPLACE INTO ${ChatSchema.T_BLOCK}
        (block_id, account_id, message_client_id, kind, text, tool_name, tool_call_id,
         order_key, revision, updated_at, status, parent_tool_call_id, parent_block_id,
         node_role, anchor_json, payload_json, created_at, server_updated_at, sync_state)
        SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        WHERE NOT EXISTS (SELECT 1 FROM ${ChatSchema.T_BLOCK}
          WHERE account_id = ? AND block_id = ?)
           OR ? >= COALESCE((SELECT revision FROM ${ChatSchema.T_BLOCK}
             WHERE account_id = ? AND block_id = ?), -1)`, [
        block.blockId, accountId, messageClientId, block.kind, block.text, block.toolName ?? null,
        block.toolCallId ?? null, block.orderKey, block.revision, block.updatedAt, block.status,
        block.parentToolCallId ?? null, block.parentBlockId ?? null, block.nodeRole,
        block.anchorJson ?? null, block.payloadJson, block.createdAt || block.updatedAt,
        block.serverUpdatedAt ?? null, markParentPending ? 'pending' : block.syncState, accountId, block.blockId,
        block.revision, accountId, block.blockId
      ]);
      if (markParentPending) {
        await db.executeSql(`UPDATE ${ChatSchema.T_MESSAGE}
          SET sync_state = CASE WHEN sync_state = 'failed' THEN 'pending' ELSE sync_state END,
              updated_at = ? WHERE account_id = ? AND client_id = ?`,
          [new Date().toISOString(), accountId, messageClientId]);
      }
    });
  }

  async listMessages(accountId: number, threadClientId: string, limit?: number): Promise<ChatMessage[]> {
    const db = await this.database.open();
    const suffix = limit !== undefined && limit > 0 ? ` LIMIT ${Math.min(limit, 500)}` : '';
    const rs = await db.querySql(`SELECT * FROM ${ChatSchema.T_MESSAGE}
      WHERE account_id = ? AND thread_client_id = ? AND tombstone = 0 ORDER BY created_at ASC${suffix}`,
      [accountId, threadClientId]);
    const messages: ChatMessage[] = [];
    try {
      if (rs.goToFirstRow()) {
        do { messages.push(ChatRepository.readMessage(rs)); } while (rs.goToNextRow());
      }
    } finally { rs.close(); }
    for (let i = 0; i < messages.length; i++) {
      messages[i].blocks = await this.listBlocks(accountId, messages[i].clientId);
    }
    return messages;
  }

  async findMessage(accountId: number, clientId: string): Promise<ChatMessage | undefined> {
    const db = await this.database.open();
    const rs = await db.querySql(`SELECT * FROM ${ChatSchema.T_MESSAGE}
      WHERE account_id = ? AND client_id = ?`, [accountId, clientId]);
    try {
      if (!rs.goToFirstRow()) {
        return undefined;
      }
      const message = ChatRepository.readMessage(rs);
      message.blocks = await this.listBlocks(accountId, clientId);
      return message;
    } finally { rs.close(); }
  }

  async listBlocks(accountId: number, messageClientId: string): Promise<ChatMessageBlock[]> {
    const db = await this.database.open();
    const rs = await db.querySql(`SELECT * FROM ${ChatSchema.T_BLOCK}
      WHERE account_id = ? AND message_client_id = ? ORDER BY order_key ASC, created_at ASC`,
      [accountId, messageClientId]);
    const out: ChatMessageBlock[] = [];
    try {
      if (rs.goToFirstRow()) {
        do { out.push(ChatRepository.readBlock(rs)); } while (rs.goToNextRow());
      }
    } finally { rs.close(); }
    return out;
  }

  async listOutbox(accountId: number, limit: number = 50): Promise<ChatMessage[]> {
    const db = await this.database.open();
    const rs = await db.querySql(`SELECT * FROM ${ChatSchema.T_MESSAGE}
      WHERE account_id = ? AND sync_state = 'pending' AND tombstone = 0
      ORDER BY created_at ASC LIMIT ${Math.min(Math.max(limit, 1), 200)}`, [accountId]);
    const out: ChatMessage[] = [];
    try {
      if (rs.goToFirstRow()) {
        do { out.push(ChatRepository.readMessage(rs)); } while (rs.goToNextRow());
      }
    } finally { rs.close(); }
    for (let i = 0; i < out.length; i++) out[i].blocks = await this.listBlocks(accountId, out[i].clientId);
    return out;
  }

  /**
   * 块级 Outbox：仅取整包消息 ACK 后仍修改过的块，避免重复发送消息 payload 内已确认的块。
   * 与 iOS CoreDataChatStore.loadPendingMessageBlocks 的父消息门禁一致。
   */
  async listPendingBlocks(accountId: number, limit: number = 100): Promise<ChatPendingMessageBlock[]> {
    const db = await this.database.open();
    const size = Math.min(Math.max(limit, 1), 100);
    const rs = await db.querySql(`SELECT b.*, m.thread_id AS parent_thread_id, m.delivery_status AS parent_delivery_status
      FROM ${ChatSchema.T_BLOCK} b INNER JOIN ${ChatSchema.T_MESSAGE} m
        ON b.account_id = m.account_id AND b.message_client_id = m.client_id
      WHERE b.account_id = ? AND b.sync_state = 'pending' AND m.tombstone = 0
        AND m.delivery_status IN ('pending', 'sent')
      ORDER BY b.updated_at ASC, b.block_id ASC LIMIT ${size}`, [accountId]);
    const out: ChatPendingMessageBlock[] = [];
    try {
      if (rs.goToFirstRow()) {
        do {
          const item = new ChatPendingMessageBlock();
          item.clientMessageId = ChatRepository.str(rs, 'message_client_id');
          item.threadId = ChatRepository.str(rs, 'parent_thread_id');
          item.block = ChatRepository.readBlock(rs);
          out.push(item);
        } while (rs.goToNextRow());
      }
    } finally { rs.close(); }
    return out;
  }

  async markMessageSending(accountId: number, clientId: string): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(`UPDATE ${ChatSchema.T_MESSAGE}
        SET sync_state = 'sending', delivery_status = CASE WHEN delivery_status = 'pending' THEN 'sending' ELSE delivery_status END,
            sync_attempt_count = sync_attempt_count + 1, updated_at = ?
        WHERE account_id = ? AND client_id = ? AND sync_state = 'pending'`,
        [new Date().toISOString(), accountId, clientId]);
    });
  }

  async markMessageSyncFailed(accountId: number, clientId: string, error: string): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(`UPDATE ${ChatSchema.T_MESSAGE}
        SET sync_state = 'failed', delivery_status = 'failed', last_sync_error = ?, error_code = 'syncFailed', updated_at = ?
        WHERE account_id = ? AND client_id = ?`,
        [error.substring(0, 200), new Date().toISOString(), accountId, clientId]);
    });
  }

  async markMessageSynced(accountId: number, clientId: string, serverId: string | undefined,
    serverUpdatedAt: string | undefined): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(`UPDATE ${ChatSchema.T_MESSAGE}
        SET sync_state = 'synced', delivery_status = CASE WHEN delivery_status IN ('pending','sending') THEN 'sent' ELSE delivery_status END,
        server_message_id = COALESCE(?, server_message_id), server_updated_at = COALESCE(?, server_updated_at),
        last_sync_error = NULL, updated_at = ? WHERE account_id = ? AND client_id = ?`,
        [serverId ?? null, serverUpdatedAt ?? null, new Date().toISOString(), accountId, clientId]);
      await db.executeSql(`UPDATE ${ChatSchema.T_BLOCK} SET sync_state = 'synced'
        WHERE account_id = ? AND message_client_id = ?`, [accountId, clientId]);
    });
  }

  async markBlocksSynced(accountId: number, blockIds: string[], serverUpdatedAt?: string): Promise<void> {
    if (blockIds.length === 0) return;
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      for (let i = 0; i < blockIds.length; i++) {
        await db.executeSql(`UPDATE ${ChatSchema.T_BLOCK}
          SET sync_state = 'synced', server_updated_at = COALESCE(?, server_updated_at)
          WHERE account_id = ? AND block_id = ?`, [serverUpdatedAt ?? null, accountId, blockIds[i]]);
      }
    });
  }

  async applyBlockSyncAck(accountId: number, clientMessageId: string, blockId: string,
    serverUpdatedAt?: string): Promise<void> {
    await this.markBlocksSynced(accountId, [blockId], serverUpdatedAt);
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(`UPDATE ${ChatSchema.T_MESSAGE}
        SET server_updated_at = COALESCE(?, server_updated_at), updated_at = ?
        WHERE account_id = ? AND client_id = ?`,
        [serverUpdatedAt ?? null, new Date().toISOString(), accountId, clientMessageId]);
    });
  }

  async saveCursor(accountId: number, key: string, value: string | undefined): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(`INSERT OR REPLACE INTO ${ChatSchema.T_CURSOR}
        (account_id, cursor_key, cursor_value, updated_at) VALUES (?, ?, ?, ?)`,
        [accountId, key, value ?? null, new Date().toISOString()]);
    });
  }

  async loadCursor(accountId: number, key: string): Promise<string | undefined> {
    const db = await this.database.open();
    const rs = await db.querySql(`SELECT cursor_value FROM ${ChatSchema.T_CURSOR} WHERE account_id = ? AND cursor_key = ?`, [accountId, key]);
    try {
      if (!rs.goToFirstRow() || rs.isColumnNull(0)) return undefined;
      return rs.getString(0);
    } finally { rs.close(); }
  }

  async deleteAccountData(accountId: number): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(`DELETE FROM ${ChatSchema.T_AUDIT} WHERE account_id = ?`, [accountId]);
      await db.executeSql(`DELETE FROM ${ChatSchema.T_ATTACHMENT} WHERE account_id = ?`, [accountId]);
      await db.executeSql(`DELETE FROM ${ChatSchema.T_CURSOR} WHERE account_id = ?`, [accountId]);
      await db.executeSql(`DELETE FROM ${ChatSchema.T_BLOCK} WHERE account_id = ?`, [accountId]);
      await db.executeSql(`DELETE FROM ${ChatSchema.T_MESSAGE} WHERE account_id = ?`, [accountId]);
      await db.executeSql(`DELETE FROM ${ChatSchema.T_THREAD} WHERE account_id = ?`, [accountId]);
    });
  }

  async persistAudit(accountId: number, id: string, threadId: string | undefined, requestId: string | undefined,
    toolName: string, status: string, inputSummary: string, outputSummary: string, memberId: number | undefined,
    createdAt: string): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(`INSERT OR REPLACE INTO ${ChatSchema.T_AUDIT}
        (id, account_id, thread_id, request_id, tool_name, status, input_summary, output_summary, member_id, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, [id, accountId, threadId ?? null, requestId ?? null, toolName,
        status, inputSummary.substring(0, 200), outputSummary.substring(0, 200), memberId ?? null, createdAt]);
    });
  }

  async enqueueAttachmentJob(accountId: number, job: ChatAttachmentDownloadJob): Promise<void> {
    await this.database.queue.enqueue(async () => {
      const db = await this.database.open();
      await db.executeSql(`INSERT OR IGNORE INTO ${ChatSchema.T_ATTACHMENT}
        (id, account_id, dedupe_key, attachment_id, client_message_id, thread_client_id, payload_json, state, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?)`, [job.id, accountId, job.dedupeKey, job.attachmentId, job.clientMessageId, job.threadClientId, job.payloadJson, new Date().toISOString()]);
    });
  }

  async listPendingAttachmentJobs(accountId: number, limit: number = 50): Promise<ChatAttachmentDownloadJob[]> {
    const db = await this.database.open(); const rs = await db.querySql(`SELECT * FROM ${ChatSchema.T_ATTACHMENT} WHERE account_id = ? AND state IN ('pending','failed') ORDER BY updated_at ASC LIMIT ${Math.min(Math.max(limit, 1), 100)}`, [accountId]); const out: ChatAttachmentDownloadJob[] = [];
    try { if (rs.goToFirstRow()) { do { const j = new ChatAttachmentDownloadJob(); j.id = ChatRepository.str(rs, 'id'); j.dedupeKey = ChatRepository.str(rs, 'dedupe_key'); j.attachmentId = ChatRepository.str(rs, 'attachment_id'); j.clientMessageId = ChatRepository.str(rs, 'client_message_id'); j.threadClientId = ChatRepository.str(rs, 'thread_client_id'); j.payloadJson = ChatRepository.str(rs, 'payload_json'); j.state = ChatRepository.str(rs, 'state'); j.localFilePath = ChatRepository.opt(rs, 'local_file_path'); j.attemptCount = ChatRepository.int(rs, 'attempt_count'); j.lastError = ChatRepository.opt(rs, 'last_error'); out.push(j); } while (rs.goToNextRow()); } } finally { rs.close(); } return out;
  }

  async updateAttachmentJob(accountId: number, jobId: string, state: string, localPath?: string, error?: string): Promise<void> {
    await this.database.queue.enqueue(async () => { const db = await this.database.open(); await db.executeSql(`UPDATE ${ChatSchema.T_ATTACHMENT} SET state = ?, local_file_path = ?, last_error = ?, attempt_count = attempt_count + 1, updated_at = ? WHERE account_id = ? AND id = ?`, [state, localPath ?? null, error ?? null, new Date().toISOString(), accountId, jobId]); });
  }

  private static readThread(rs: relationalStore.ResultSet): ChatThread {
    const t = new ChatThread();
    t.clientId = ChatRepository.str(rs, 'client_id'); t.threadId = ChatRepository.str(rs, 'thread_id') || t.clientId;
    t.accountId = rs.getLong(rs.getColumnIndex('account_id')); t.title = ChatRepository.str(rs, 'title');
    t.preferredModelName = ChatRepository.opt(rs, 'preferred_model_name'); t.memberId = ChatRepository.optNum(rs, 'member_id');
    t.createdAt = ChatRepository.str(rs, 'created_at'); t.updatedAt = ChatRepository.str(rs, 'updated_at');
    t.scenario = ChatRepository.str(rs, 'scenario') || 'chat'; t.serverUpdatedAt = ChatRepository.opt(rs, 'server_updated_at');
    t.patientId = ChatRepository.opt(rs, 'patient_id'); t.isDeleted = ChatRepository.int(rs, 'is_deleted') !== 0;
    t.deletedAt = ChatRepository.opt(rs, 'deleted_at'); t.temperature = ChatRepository.optDouble(rs, 'temperature');
    t.topP = ChatRepository.double(rs, 'top_p', 1); t.maxTokens = ChatRepository.optNum(rs, 'max_tokens');
    t.maxMessages = ChatRepository.int(rs, 'max_messages', 20); t.rolePrompt = ChatRepository.str(rs, 'role_prompt');
    t.imageDeliveryMode = ChatRepository.opt(rs, 'image_delivery_mode'); t.iconName = ChatRepository.opt(rs, 'icon_name');
    t.iconColorName = ChatRepository.opt(rs, 'icon_color_name'); t.isPinned = ChatRepository.int(rs, 'is_pinned') !== 0;
    t.pinnedAt = ChatRepository.opt(rs, 'pinned_at'); return t;
  }

  private static readMessage(rs: relationalStore.ResultSet): ChatMessage {
    const m = new ChatMessage();
    m.clientId = ChatRepository.str(rs, 'client_id'); m.accountId = rs.getLong(rs.getColumnIndex('account_id'));
    m.threadClientId = ChatRepository.str(rs, 'thread_client_id'); m.threadId = ChatRepository.str(rs, 'thread_id') || m.threadClientId;
    m.serverMessageId = ChatRepository.opt(rs, 'server_message_id'); m.role = ChatRepository.str(rs, 'role') as ChatMessageRole;
    m.kind = ChatRepository.str(rs, 'kind') as ChatMessageKind; m.text = ChatRepository.str(rs, 'text');
    m.deliveryStatus = ChatRepository.str(rs, 'delivery_status') as ChatDeliveryStatus; m.requestId = ChatRepository.opt(rs, 'request_id');
    m.errorCode = ChatRepository.opt(rs, 'error_code'); m.modelName = ChatRepository.opt(rs, 'model_name');
    m.tombstone = ChatRepository.int(rs, 'tombstone') !== 0; m.serverUpdatedAt = ChatRepository.opt(rs, 'server_updated_at');
    m.attachmentsJson = ChatRepository.str(rs, 'attachments_json') || '[]'; m.reasoningContent = ChatRepository.opt(rs, 'reasoning_content');
    m.reasoningDurationMs = ChatRepository.optNum(rs, 'reasoning_duration_ms'); m.reasoningExpanded = ChatRepository.int(rs, 'reasoning_expanded') !== 0;
    m.reasoningVisibility = ChatRepository.opt(rs, 'reasoning_visibility'); m.syncState = ChatRepository.str(rs, 'sync_state') || 'pending';
    m.syncAttemptCount = ChatRepository.int(rs, 'sync_attempt_count'); m.lastSyncError = ChatRepository.opt(rs, 'last_sync_error');
    m.localRevision = ChatRepository.int(rs, 'local_revision'); m.createdAt = ChatRepository.str(rs, 'created_at'); m.updatedAt = ChatRepository.str(rs, 'updated_at');
    return m;
  }

  private static readBlock(rs: relationalStore.ResultSet): ChatMessageBlock {
    const b = new ChatMessageBlock(); b.blockId = ChatRepository.str(rs, 'block_id');
    b.kind = ChatRepository.str(rs, 'kind') as ChatBlockKind; b.text = ChatRepository.str(rs, 'text');
    b.toolName = ChatRepository.opt(rs, 'tool_name'); b.toolCallId = ChatRepository.opt(rs, 'tool_call_id');
    b.orderKey = ChatRepository.double(rs, 'order_key', 0); b.revision = ChatRepository.int(rs, 'revision');
    b.updatedAt = ChatRepository.str(rs, 'updated_at'); b.status = ChatRepository.str(rs, 'status') || 'ready';
    b.parentToolCallId = ChatRepository.opt(rs, 'parent_tool_call_id'); b.parentBlockId = ChatRepository.opt(rs, 'parent_block_id');
    b.nodeRole = ChatRepository.str(rs, 'node_role') || 'timeline'; b.anchorJson = ChatRepository.opt(rs, 'anchor_json');
    b.payloadJson = ChatRepository.str(rs, 'payload_json') || '{}'; b.createdAt = ChatRepository.str(rs, 'created_at') || b.updatedAt;
    b.serverUpdatedAt = ChatRepository.opt(rs, 'server_updated_at'); b.syncState = ChatRepository.str(rs, 'sync_state') || 'pending'; return b;
  }

  private static str(rs: relationalStore.ResultSet, name: string): string {
    const i = rs.getColumnIndex(name); return i < 0 || rs.isColumnNull(i) ? '' : rs.getString(i);
  }
  private static opt(rs: relationalStore.ResultSet, name: string): string | undefined {
    const i = rs.getColumnIndex(name); return i < 0 || rs.isColumnNull(i) ? undefined : rs.getString(i);
  }
  private static int(rs: relationalStore.ResultSet, name: string, fallback: number = 0): number {
    const i = rs.getColumnIndex(name); return i < 0 || rs.isColumnNull(i) ? fallback : rs.getLong(i);
  }
  private static double(rs: relationalStore.ResultSet, name: string, fallback: number): number {
    const i = rs.getColumnIndex(name); return i < 0 || rs.isColumnNull(i) ? fallback : rs.getDouble(i);
  }
  private static optNum(rs: relationalStore.ResultSet, name: string): number | undefined {
    const i = rs.getColumnIndex(name); return i < 0 || rs.isColumnNull(i) ? undefined : rs.getLong(i);
  }
  private static optDouble(rs: relationalStore.ResultSet, name: string): number | undefined {
    const i = rs.getColumnIndex(name); return i < 0 || rs.isColumnNull(i) ? undefined : rs.getDouble(i);
  }
}

import { AccountSessionRuntime } from '../../../../App/AccountSessionRuntime';
import { AuthTokenProvider } from '../../../Core/Networking/AuthTokenProvider';
import {
  ChatRemoteAPI,
  ChatRemoteBlockDTO,
  ChatRemoteMessageDTO,
  ChatRemoteThreadDTO,
  ChatRemoteBlockUpdateDTO,
  ChatPushAck
} from '../../../Core/Networking/API/AI/ChatRemoteAPI';
import { SupportNetworkError } from '../../../Core/Networking/SupportNetworkModels';
import {
  ChatMessage,
  ChatMessageBlock,
  ChatThread,
  ChatMessageRole,
  ChatBlockKind,
  ChatDeliveryStatus,
  ChatAttachment,
  ChatAttachmentDownloadJob,
  ChatNewId
} from '../Domain/ChatModels';
import { ChatMessageText } from '../Domain/ChatMessageText';
import { ChatRepository } from './ChatRepository';
import { ChatRealtimeSyncClient } from './ChatRealtimeSyncClient';
import { ChatAttachmentPipeline } from './ChatAttachmentPipeline';
import { ChatMergeEngine } from './ChatMergeEngine';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';

/** 对齐 iOS ChatSyncEngine：scoped single-flight、Outbox ACK、40401 软跳过、thread/message cursor。 */
export class ChatSyncEngine {
  private readonly repository: ChatRepository;
  private readonly remote: ChatRemoteAPI;
  private readonly accountRuntime: AccountSessionRuntime;
  private readonly realtime: ChatRealtimeSyncClient;
  private readonly attachmentPipeline?: ChatAttachmentPipeline;
  private readonly inflightByScope: Map<string, Promise<void>> = new Map();

  constructor(
    repository: ChatRepository,
    remote: ChatRemoteAPI,
    accountRuntime: AccountSessionRuntime,
    tokenProvider: AuthTokenProvider,
    baseURL: string,
    attachmentPipeline?: ChatAttachmentPipeline
  ) {
    this.repository = repository;
    this.remote = remote;
    this.accountRuntime = accountRuntime;
    this.realtime = new ChatRealtimeSyncClient(tokenProvider, baseURL);
    this.attachmentPipeline = attachmentPipeline;
  }

  /** 对齐 iOS syncNow：仅上送（删除标记 + outbox），不上送全量线程列表。 */
  async syncNow(): Promise<void> {
    const start = Date.now();
    const begin = new LogFields();
    begin.detail = '聊天同步开始';
    Logger.debug('chat.sync.begin', LogModule.GENERAL, begin);
    await this.singleFlight('global', async () => {
      await this.prepareAccount();
      await this.pushOutbox();
    });
    const done = new LogFields();
    done.detail = `聊天同步完成（仅上送），cost=${((Date.now() - start) / 1000).toFixed(3)}s`;
    Logger.debug('chat.sync.done', LogModule.GENERAL, done);
  }

  async syncNowWithPull(): Promise<void> {
    await this.singleFlight('global', async () => {
      await this.prepareAccount();
      await this.pushThreads();
      await this.pullThreads();
      await this.pullMessages();
      await this.pushOutbox();
      await this.attachmentPipeline?.processPending();
    });
  }

  async refreshThreadListIncremental(): Promise<void> {
    await this.singleFlight('global', async () => {
      await this.prepareAccount();
      await this.pullThreads();
    });
  }

  /** 对齐 iOS pushOutboxOnly。 */
  async pushOutboxOnly(): Promise<void> {
    await this.singleFlight('global', async () => {
      const fields = new LogFields();
      fields.detail = '聊天仅上送 outbox';
      Logger.debug('chat.sync.outbox_only', LogModule.GENERAL, fields);
      await this.prepareAccount();
      await this.pushOutbox();
    });
  }

  /** 对齐 iOS pushSingleThread。 */
  async pushSingleThread(threadId: string): Promise<void> {
    if (!ChatNewId.isUUID(threadId)) {
      return;
    }
    const fields = new LogFields();
    fields.detail = `上送单会话元数据，thread=${ChatSyncEngine.shortId(threadId)}`;
    Logger.debug('chat.sync.thread_push.begin', LogModule.GENERAL, fields);
    await this.prepareAccount();
    const account = this.accountId();
    if (account === undefined) {
      return;
    }
    const thread = await this.repository.findThreadByRemoteId(account, threadId);
    if (!thread || !ChatNewId.isUUID(thread.threadId || thread.clientId)) {
      return;
    }
    const prep = new LogFields();
    prep.detail = `准备上送会话元数据（单会话），thread=${ChatSyncEngine.shortId(threadId)}`;
    Logger.debug('chat.sync.thread_push.prep', LogModule.GENERAL, prep);
    const accepted = await this.remote.pushThreads([ChatSyncEngine.toRemoteThread(thread)]);
    // 回写 server_updated_at
    if (accepted.length > 0) {
      const remote = accepted[0];
      thread.serverUpdatedAt = remote.server_updated_at;
      thread.updatedAt = remote.updated_at || thread.updatedAt;
      if (remote.current_model_name) {
        thread.preferredModelName = remote.current_model_name;
      }
      await this.repository.upsertThread(thread, false);
    }
    const done = new LogFields();
    done.detail = `会话元数据上送完成（单会话），accepted=${accepted.length}`;
    Logger.debug('chat.sync.thread_push.done', LogModule.GENERAL, done);
  }

  /**
   * 对齐 iOS pullThreadMessagesIncrementalOnOpen：
   * 进入会话时先可并发上送本线程，再 pull；40401 软跳过。
   */
  async pullThreadMessagesIncrementalOnOpen(threadId: string): Promise<void> {
    if (!ChatNewId.isUUID(threadId)) {
      return;
    }
    await this.singleFlight(`thread=${threadId}`, async () => {
      await this.prepareAccount();
      await this.pullAndMergeAllowingMissingRemoteThread(threadId);
    });
  }

  /** 兼容旧调用名。 */
  async pullThreadMessages(threadId: string): Promise<void> {
    // 打开详情：对齐 iOS — pull（允许缺失）与单会话上送可并行触发；此处串行保证顺序清晰。
    void this.pushSingleThread(threadId);
    await this.pullThreadMessagesIncrementalOnOpen(threadId);
  }

  async startRealtime(): Promise<void> {
    await this.realtime.start((_cursor?: string) => {
      void this.singleFlight('global', async () => {
        await this.prepareAccount();
        await this.pushOutbox();
      });
    });
  }

  async stopRealtime(): Promise<void> {
    await this.realtime.stop();
  }

  private async singleFlight(scope: string, work: () => Promise<void>): Promise<void> {
    const existing = this.inflightByScope.get(scope);
    if (existing) {
      const reuse = new LogFields();
      reuse.detail = `同步复用进行中的任务 scope=${scope.length > 40 ? scope.substring(0, 40) : scope}`;
      Logger.debug('chat.sync.reuse', LogModule.GENERAL, reuse);
      await existing;
      return;
    }
    const task = work();
    this.inflightByScope.set(scope, task);
    try {
      await task;
    } finally {
      this.inflightByScope.delete(scope);
    }
  }

  private accountId(): number | undefined {
    return this.accountRuntime.activeAccountId;
  }

  private async prepareAccount(): Promise<void> {
    const account = this.accountId();
    if (account !== undefined) {
      await this.repository.normalizeLegacyIdentifiers(account);
    }
  }

  private async pushOutbox(): Promise<void> {
    const account = this.accountId();
    if (account === undefined) {
      return;
    }
    const pending = await this.repository.listOutbox(account);
    const validPending = pending.filter((message: ChatMessage): boolean =>
      ChatNewId.isUUID(message.clientId) && ChatNewId.isUUID(message.threadId || message.threadClientId));
    if (validPending.length === 0) {
      const pendingBlocksEmpty = await this.repository.listPendingBlocks(account);
      if (pendingBlocksEmpty.length === 0) {
        return;
      }
    }
    const threads = new Set<string>();
    let toolCount = 0;
    for (let i = 0; i < validPending.length; i++) {
      threads.add(validPending[i].threadId || validPending[i].threadClientId);
      if (validPending[i].blocks.some((b: ChatMessageBlock): boolean => b.kind === 'tool')) {
        toolCount += 1;
      }
    }
    if (validPending.length > 0) {
      const prep = new LogFields();
      prep.detail =
        `准备上送对话，count=${validPending.length}, threads=${threads.size}, toolMessages=${toolCount}`;
      Logger.info('chat.sync.outbox.prep', LogModule.GENERAL, prep);
    }

    for (let i = 0; i < validPending.length; i++) {
      await this.repository.markMessageSending(account, validPending[i].clientId);
    }

    const threadsById = await this.loadThreadsMap(account);
    // 重载消息确保 blocks 最新
    const payload: ChatRemoteMessageDTO[] = [];
    for (let i = 0; i < validPending.length; i++) {
      const queued = validPending[i];
      const fresh = await this.repository.findMessage(account, queued.clientId);
      const message = fresh ?? queued;
      const kinds = message.blocks.map((b: ChatMessageBlock): string => `${b.kind}(${b.status})`).join(', ');
      const reload = new LogFields();
      reload.detail =
        `push 重载消息 blocks：clientMessageID=${message.clientId}, count=${message.blocks.length}, kinds=[${kinds}]`;
      Logger.info('chat.sync.outbox.reload', LogModule.GENERAL, reload);
      const thread = threadsById.get(message.threadId || message.threadClientId);
      payload.push(ChatSyncEngine.toRemoteMessage(message, thread));
    }

    if (payload.length > 0) {
      let ack: ChatPushAck;
      try {
        ack = await this.remote.push(payload);
      } catch (err) {
        const reason = `${err}`;
        for (let i = 0; i < validPending.length; i++) {
          await this.repository.markMessageSyncFailed(account, validPending[i].clientId, reason);
        }
        return;
      }
      for (let i = 0; i < ack.acceptedMessages.length; i++) {
        const item = ack.acceptedMessages[i];
        await this.repository.markMessageSynced(
          account,
          item.client_message_id,
          item.server_message_id,
          item.server_updated_at
        );
      }
      const done = new LogFields();
      done.detail =
        `上送对话完成，requested=${payload.length}, structuredHealthCardBlocks=0,` +
        ` acceptedMessages=${ack.acceptedMessages.length}, acceptedBlockUpdates=${ack.acceptedBlocks.length}`;
      Logger.info('chat.sync.outbox.done', LogModule.GENERAL, done);
    }

    const pendingBlocks = await this.repository.listPendingBlocks(account);
    const blockUpdates: ChatRemoteBlockUpdateDTO[] = [];
    for (let i = 0; i < pendingBlocks.length; i++) {
      const item = pendingBlocks[i];
      if (!ChatNewId.isUUID(item.threadId) || !ChatNewId.isUUID(item.clientMessageId) ||
        !ChatNewId.isUUID(item.block.blockId)) {
        continue;
      }
      const update = new ChatRemoteBlockUpdateDTO();
      update.thread_id = item.threadId;
      update.client_message_id = item.clientMessageId;
      update.block = ChatSyncEngine.toRemoteBlock(item.block);
      blockUpdates.push(update);
    }
    if (blockUpdates.length > 0) {
      try {
        const blockAck = await this.remote.pushBlockUpdates(blockUpdates);
        for (let i = 0; i < blockAck.acceptedBlocks.length; i++) {
          const item = blockAck.acceptedBlocks[i];
          await this.repository.applyBlockSyncAck(
            account,
            item.client_message_id,
            item.block_id,
            item.server_updated_at
          );
        }
      } catch (_err) {
        // 块级失败保留 pending
      }
    }
  }

  private async loadThreadsMap(account: number): Promise<Map<string, ChatThread>> {
    const list = await this.repository.listThreads(account);
    const map: Map<string, ChatThread> = new Map();
    for (let i = 0; i < list.length; i++) {
      const t = list[i];
      map.set(t.clientId, t);
      if (t.threadId.length > 0) {
        map.set(t.threadId, t);
      }
    }
    return map;
  }

  private async pushThreads(): Promise<void> {
    const account = this.accountId();
    if (account === undefined) {
      return;
    }
    const threads = await this.repository.listThreadsForSync(account);
    const payload = threads
      .filter((thread: ChatThread): boolean => ChatNewId.isUUID(thread.threadId || thread.clientId))
      .map((thread: ChatThread): ChatRemoteThreadDTO => ChatSyncEngine.toRemoteThread(thread));
    if (payload.length > 0) {
      await this.remote.pushThreads(payload);
    }
  }

  private async pullThreads(): Promise<void> {
    const account = this.accountId();
    if (account === undefined) {
      return;
    }
    let cursor = await this.repository.loadCursor(account, 'chat.thread.cursor');
    for (let page = 0; page < 20; page++) {
      const result = await this.remote.pullThreads(cursor, 100);
      for (let i = 0; i < result.threads.length; i++) {
        const remote = result.threads[i];
        const thread = ChatSyncEngine.toDomainThread(remote, account);
        await this.repository.upsertThread(thread, false);
      }
      if (result.cursor && result.cursor !== cursor) {
        cursor = result.cursor;
        await this.repository.saveCursor(account, 'chat.thread.cursor', cursor);
      }
      if (!result.hasMore) {
        break;
      }
    }
  }

  private async pullAndMergeAllowingMissingRemoteThread(threadId: string): Promise<void> {
    const account = this.accountId();
    if (account !== undefined) {
      await this.repairLocalThreadMessages(account, threadId);
    }
    try {
      await this.pullMessages(threadId);
    } catch (err) {
      if (ChatSyncEngine.isRemoteThreadMissing(err)) {
        const fields = new LogFields();
        fields.detail = `拉取跳过：服务端尚无该会话，thread=${ChatSyncEngine.shortId(threadId)}`;
        Logger.debug('chat.sync.pull.skip_missing', LogModule.GENERAL, fields);
        return;
      }
      if (err instanceof Error) {
        throw err;
      }
      throw new Error(`${err}`);
    }
    if (account !== undefined) {
      await this.repairLocalThreadMessages(account, threadId);
    }
  }

  /**
   * 修复旧脏数据：终态已 synced 但块仍 streaming，或 messages.text 为空而 blocks 有正文。
   */
  private async repairLocalThreadMessages(account: number, threadId: string): Promise<void> {
    const thread = await this.repository.findThreadByRemoteId(account, threadId);
    const threadClientId = thread?.clientId ?? threadId;
    const messages = await this.repository.listMessages(account, threadClientId);
    for (let i = 0; i < messages.length; i++) {
      await this.repairSingleMessageIfNeeded(messages[i]);
    }
  }

  private async repairSingleMessageIfNeeded(message: ChatMessage): Promise<void> {
    const beforeStatuses: string[] = [];
    for (let j = 0; j < message.blocks.length; j++) {
      beforeStatuses.push(message.blocks[j].status);
    }
    const beforeText = message.text;
    message.blocks = ChatMessageText.coerceTerminalBlocks(message.deliveryStatus, message.blocks);
    const filled = ChatMessageText.fromMessage(message);
    if (filled.length > 0 && message.text.trim().length === 0) {
      message.text = filled;
    }
    let blocksChanged = false;
    for (let j = 0; j < message.blocks.length; j++) {
      if (message.blocks[j].status !== beforeStatuses[j]) {
        blocksChanged = true;
        break;
      }
    }
    if (!blocksChanged && message.text === beforeText) {
      return;
    }
    await this.repository.upsertMessage(message, false, false);
  }

  private async pullMessages(threadId?: string): Promise<void> {
    const account = this.accountId();
    if (account === undefined) {
      return;
    }
    const key = threadId ? `chat.thread.message.cursor.${threadId}` : 'chat.main';
    let cursor = await this.repository.loadCursor(account, key);
    const scope = threadId ? `thread=${ChatSyncEngine.shortId(threadId)}` : 'global';
    const begin = new LogFields();
    begin.detail = `拉取对话增量开始，cursor=${cursor ?? '-'} scope=${scope}`;
    Logger.debug('chat.sync.pull.begin', LogModule.GENERAL, begin);

    for (let page = 0; page < 20; page++) {
      const result = await this.remote.pull(cursor, threadId, 200);
      for (let i = 0; i < result.messages.length; i++) {
        await this.mergeRemoteMessage(result.messages[i], account);
      }
      if (result.cursor && result.cursor !== cursor) {
        cursor = result.cursor;
        await this.repository.saveCursor(account, key, cursor);
      }
      if (!result.hasMore) {
        break;
      }
    }
  }

  private async mergeRemoteMessage(remote: ChatRemoteMessageDTO, account: number): Promise<void> {
    const local = await this.repository.findMessage(account, remote.client_message_id);
    if (local && ChatSyncEngine.shouldKeepLocal(local, remote)) {
      await this.repairSingleMessageIfNeeded(local);
      return;
    }
    const message = new ChatMessage();
    message.clientId = remote.client_message_id;
    message.serverMessageId = remote.server_message_id;
    message.threadClientId = remote.thread_id;
    message.threadId = remote.thread_id;
    message.accountId = account;
    message.role = ChatSyncEngine.parseRole(remote.role);
    message.kind = remote.blocks.some((b: ChatRemoteBlockDTO): boolean => b.kind === 'tool') ? 'tool' : 'text';
    message.deliveryStatus = ChatSyncEngine.parseDelivery(remote.delivery_state);
    message.createdAt = remote.created_at;
    message.updatedAt = remote.server_updated_at ?? remote.created_at;
    message.serverUpdatedAt = remote.server_updated_at;
    message.tombstone = remote.tombstone;
    message.modelName = remote.model_name;
    message.attachmentsJson = JSON.stringify(remote.attachments);
    message.reasoningContent = remote.reasoning_content;
    message.reasoningDurationMs = remote.reasoning_duration_ms;
    message.reasoningExpanded = remote.reasoning_expanded;
    message.reasoningVisibility = remote.reasoning_visibility;
    message.syncState = 'synced';
    message.blocks = ChatMessageText.coerceTerminalBlocks(
      message.deliveryStatus,
      remote.blocks.map(ChatSyncEngine.toDomainBlock)
    );
    // 回填 denormalized text，避免 INSERT OR REPLACE 把本地全文写成空串导致 UI 主气泡空白
    message.text = ChatMessageText.fromBlocks(message.blocks);
    if (message.text.length === 0 && local && local.text.length > 0) {
      message.text = local.text;
    }
    const merged = ChatMergeEngine.merge(local, message, remote);
    if (merged.text.length === 0) {
      merged.text = ChatMessageText.fromMessage(merged);
    }
    await this.repository.upsertMessage(merged, false, false);
    for (let i = 0; i < remote.attachments.length; i++) {
      const attachment = ChatAttachment.fromJson(remote.attachments[i]);
      if (attachment.fileId ||
        (attachment.url && (attachment.url.startsWith('https://') || attachment.url.startsWith('http://')))) {
        const job = new ChatAttachmentDownloadJob();
        job.id = ChatNewId.uuidLike();
        job.dedupeKey = `${remote.thread_id}:${remote.client_message_id}:${attachment.id}`;
        job.attachmentId = attachment.id;
        job.clientMessageId = remote.client_message_id;
        job.threadClientId = remote.thread_id;
        job.payloadJson = JSON.stringify(remote.attachments[i]);
        await this.repository.enqueueAttachmentJob(account, job);
      }
    }
  }

  private static isRemoteThreadMissing(err: Object | string | number | boolean | undefined | null): boolean {
    if (err instanceof SupportNetworkError) {
      if (err.statusCode === 404 && err.backend) {
        return err.backend.code === 40401 || err.backend.message === 'thread_not_found';
      }
      if (err.backend && (err.backend.code === 40401 || err.backend.message === 'thread_not_found')) {
        return true;
      }
    }
    const text = `${err}`;
    return text.indexOf('40401') >= 0 || text.indexOf('thread_not_found') >= 0;
  }

  private static toRemoteMessage(message: ChatMessage, thread?: ChatThread): ChatRemoteMessageDTO {
    const m = new ChatRemoteMessageDTO();
    m.thread_id = message.threadId || message.threadClientId;
    m.role = message.role;
    m.model_name = message.modelName;
    m.client_message_id = message.clientId;
    m.server_message_id = message.serverMessageId;
    m.delivery_state = message.deliveryStatus === 'completed' ? 'sent' : message.deliveryStatus;
    m.created_at = message.createdAt;
    m.server_updated_at = message.serverUpdatedAt;
    m.tombstone = message.tombstone;
    m.attachments = ChatSyncEngine.jsonArray(message.attachmentsJson);
    m.reasoning_content = message.reasoningContent;
    m.reasoning_duration_ms = message.reasoningDurationMs;
    m.reasoning_expanded = message.reasoningExpanded;
    m.reasoning_visibility = message.reasoningVisibility;
    m.blocks = message.blocks
      .filter((b: ChatMessageBlock): boolean => ChatNewId.isUUID(b.blockId))
      .map((b: ChatMessageBlock): ChatRemoteBlockDTO => ChatSyncEngine.toRemoteBlock(b));
    if (thread) {
      m.thread_current_model_name = thread.preferredModelName;
      m.thread_temperature = thread.temperature;
      m.thread_top_p = thread.topP;
      m.thread_max_tokens = thread.maxTokens;
      m.thread_max_messages = thread.maxMessages;
      m.thread_role_prompt = thread.rolePrompt;
      m.thread_system_prompt = undefined;
    }
    return m;
  }

  private static toRemoteBlock(block: ChatMessageBlock): ChatRemoteBlockDTO {
    const b = new ChatRemoteBlockDTO();
    b.id = block.blockId;
    b.kind = block.kind;
    b.status = block.status;
    b.revision = block.revision;
    b.order_key = block.orderKey;
    b.tool_call_id = block.toolCallId;
    b.parent_tool_call_id = block.parentToolCallId;
    b.parent_block_id = block.parentBlockId;
    b.node_role = block.nodeRole;
    b.anchor = ChatSyncEngine.jsonObject(block.anchorJson);
    b.payload = ChatSyncEngine.payloadObject(block.payloadJson, block.text);
    b.created_at = block.createdAt || block.updatedAt;
    b.updated_at = block.updatedAt;
    return b;
  }

  private static toRemoteThread(thread: ChatThread): ChatRemoteThreadDTO {
    const t = new ChatRemoteThreadDTO();
    t.thread_id = thread.threadId || thread.clientId;
    t.title = thread.title;
    t.scenario = thread.scenario;
    t.patient_id = thread.patientId;
    t.member_id = thread.memberId;
    t.is_deleted = thread.isDeleted;
    t.deleted_at = thread.deletedAt;
    t.updated_at = thread.updatedAt;
    t.server_updated_at = thread.serverUpdatedAt ?? thread.updatedAt;
    t.image_delivery_mode = thread.imageDeliveryMode;
    t.icon_name = thread.iconName;
    t.icon_color_name = thread.iconColorName;
    t.is_pinned = thread.isPinned;
    t.pinned_at = thread.pinnedAt;
    t.current_model_name = thread.preferredModelName;
    t.temperature = thread.temperature;
    t.top_p = thread.topP;
    t.max_tokens = thread.maxTokens;
    t.max_messages = thread.maxMessages;
    t.role_prompt = thread.rolePrompt;
    t.system_prompt = '';
    return t;
  }

  private static toDomainBlock(raw: ChatRemoteBlockDTO): ChatMessageBlock {
    const b = new ChatMessageBlock();
    b.blockId = raw.id;
    b.kind = ChatSyncEngine.parseBlockKind(raw.kind);
    b.status = raw.status;
    b.revision = raw.revision;
    b.orderKey = raw.order_key;
    b.toolCallId = raw.tool_call_id;
    b.parentToolCallId = raw.parent_tool_call_id;
    b.parentBlockId = raw.parent_block_id;
    b.nodeRole = raw.node_role;
    b.anchorJson = raw.anchor ? JSON.stringify(raw.anchor) : undefined;
    b.payloadJson = JSON.stringify(raw.payload);
    b.text = ChatSyncEngine.payloadText(raw.payload);
    b.createdAt = raw.created_at;
    b.updatedAt = raw.updated_at;
    b.syncState = 'synced';
    return b;
  }

  private static payloadObject(payloadJson: string, text: string): Object {
    let value: Object | undefined = ChatSyncEngine.jsonObject(payloadJson);
    if (value === undefined) {
      const fallback = new ChatTextPayload();
      fallback.text = text;
      return fallback;
    }
    if (text.length === 0) {
      return value;
    }
    const record = value as Record<string, Object | string | number | boolean | null>;
    if (record['text'] === undefined || record['text'] === null || `${record['text']}`.length === 0) {
      record['text'] = text;
    }
    return record as Object;
  }

  private static payloadText(payload: Object): string {
    const record = payload as Record<string, Object | string | number | boolean | null>;
    const value = record['text'];
    if (typeof value === 'string') {
      return value;
    }
    if (value !== null && typeof value === 'object') {
      const nested = value as Record<string, Object | string | number | boolean | null>;
      if (typeof nested['_0'] === 'string') {
        return nested['_0'] as string;
      }
      if (typeof nested['value'] === 'string') {
        return nested['value'] as string;
      }
    }
    return '';
  }

  private static toDomainThread(raw: ChatRemoteThreadDTO, account: number): ChatThread {
    const t = new ChatThread();
    t.clientId = raw.thread_id;
    t.threadId = raw.thread_id;
    t.accountId = account;
    t.title = raw.title;
    t.scenario = raw.scenario;
    t.patientId = raw.patient_id;
    t.memberId = raw.member_id;
    t.isDeleted = raw.is_deleted;
    t.deletedAt = raw.deleted_at;
    t.createdAt = raw.updated_at;
    t.updatedAt = raw.updated_at;
    t.serverUpdatedAt = raw.server_updated_at;
    t.preferredModelName = raw.current_model_name;
    t.temperature = raw.temperature;
    t.topP = raw.top_p ?? 1;
    t.maxTokens = raw.max_tokens;
    t.maxMessages = raw.max_messages ?? 20;
    t.rolePrompt = raw.system_prompt ?? raw.role_prompt ?? '';
    t.imageDeliveryMode = raw.image_delivery_mode;
    t.iconName = raw.icon_name;
    t.iconColorName = raw.icon_color_name;
    t.isPinned = raw.is_pinned;
    t.pinnedAt = raw.pinned_at;
    return t;
  }

  private static jsonArray(raw: string): Object[] {
    try {
      const v = JSON.parse(raw) as Object;
      return Array.isArray(v) ? v as Object[] : [];
    } catch (_e) {
      return [];
    }
  }

  private static jsonObject(raw?: string): Object | undefined {
    if (!raw) {
      return undefined;
    }
    try {
      const v = JSON.parse(raw) as Object;
      return typeof v === 'object' ? v as Object : undefined;
    } catch (_e) {
      return undefined;
    }
  }

  private static parseRole(raw: string): ChatMessageRole {
    return raw === 'assistant' ? 'assistant' : raw === 'system' ? 'system' : 'user';
  }

  private static parseDelivery(raw: string): ChatDeliveryStatus {
    return raw === 'pending' || raw === 'sending' || raw === 'streamed' || raw === 'failed' ||
      raw === 'cancelled' || raw === 'sent' || raw === 'read' ? raw : 'completed';
  }

  private static parseBlockKind(raw: string): ChatBlockKind {
    switch (raw) {
      case 'deepThought':
      case 'tool':
      case 'error':
      case 'assistantStatusCard':
      case 'toolPresentation':
      case 'rich':
      case 'imageGallery':
      case 'fileAttachments':
      case 'knowledgeCards':
      case 'translatedText':
      case 'mapRoute':
      case 'events':
      case 'healthCards':
      case 'pendingMemberToolCards':
      case 'structuredHealthCards':
      case 'sleepVisualization':
      case 'nutritionCards':
      case 'workoutVisualization':
      case 'captureCard':
      case 'html':
      case 'smallTaskCard':
      case 'taskCards':
      case 'healthResourceReference':
      case 'medicalRiskNotice':
      case 'medicalDisclaimerCard':
        return raw;
      default:
        return 'text';
    }
  }

  private static shouldKeepLocal(local: ChatMessage, remote: ChatRemoteMessageDTO): boolean {
    if (local.syncState === 'pending' || local.syncState === 'sending') {
      return true;
    }
    if (!local.serverUpdatedAt || !remote.server_updated_at) {
      return false;
    }
    return local.serverUpdatedAt > remote.server_updated_at;
  }

  private static shortId(id: string): string {
    return id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }
}

class ChatTextPayload {
  text: string = '';
}

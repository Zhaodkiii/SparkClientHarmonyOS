import { NetworkRequest, NetworkStrategy, QueryItem, RetryConfig } from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { SupportAPIResponseDecoder } from '../Common/SupportAPIResponseDecoder';

export class ChatJsonObject {
  value: string = '';
}

export class ChatRemoteBlockDTO {
  id: string = '';
  kind: string = 'text';
  status: string = 'ready';
  revision: number = 0;
  order_key: number = 0;
  tool_call_id?: string;
  parent_tool_call_id?: string;
  parent_block_id?: string;
  node_role: string = 'timeline';
  anchor?: Object;
  payload: Object = new ChatJsonObject();
  created_at: string = '';
  updated_at: string = '';
}

export class ChatRemoteMessageDTO {
  thread_id: string = '';
  role: string = 'user';
  model_name?: string;
  blocks: ChatRemoteBlockDTO[] = [];
  client_message_id: string = '';
  server_message_id?: string;
  delivery_state: string = 'pending';
  created_at: string = '';
  server_updated_at?: string;
  tombstone: boolean = false;
  thread_current_model_name?: string;
  thread_temperature?: number;
  thread_top_p?: number;
  thread_max_tokens?: number;
  thread_max_messages?: number;
  thread_role_prompt?: string;
  thread_system_prompt?: string;
  attachments: Object[] = [];
  reasoning_content?: string;
  reasoning_duration_ms?: number;
  reasoning_expanded: boolean = false;
  reasoning_visibility?: string;
}

export class ChatRemoteThreadDTO {
  thread_id: string = '';
  title: string = '';
  scenario: string = 'chat';
  patient_id?: string;
  member_id?: number;
  is_deleted: boolean = false;
  deleted_at?: string;
  updated_at: string = '';
  server_updated_at: string = '';
  image_delivery_mode?: string;
  icon_name?: string;
  icon_color_name?: string;
  is_pinned: boolean = false;
  pinned_at?: string;
  current_model_name?: string;
  temperature?: number;
  top_p?: number;
  max_tokens?: number;
  max_messages?: number;
  role_prompt?: string;
  system_prompt?: string;
}

class ChatPushBody { messages: ChatRemoteMessageDTO[] = []; block_updates: Object[] = []; }
class ChatThreadPushBody { threads: ChatRemoteThreadDTO[] = []; }
class ChatThreadDeleteBody { thread_ids: string[] = []; }

export class ChatPullResult {
  cursor?: string;
  messages: ChatRemoteMessageDTO[] = [];
  hasMore: boolean = false;
}
export class ChatThreadPullResult {
  cursor?: string;
  threads: ChatRemoteThreadDTO[] = [];
  hasMore: boolean = false;
}
export class ChatPushAck {
  acceptedMessages: ChatPushAckMessage[] = [];
  acceptedBlocks: ChatPushAckBlock[] = [];
}
export class ChatRemoteBlockUpdateDTO { thread_id: string = ''; client_message_id: string = ''; block: ChatRemoteBlockDTO = new ChatRemoteBlockDTO(); }
export class ChatPushAckMessage { client_message_id: string = ''; server_message_id?: string; server_updated_at: string = ''; }
export class ChatPushAckBlock { client_message_id: string = ''; block_id: string = ''; server_updated_at: string = ''; }

/** 服务端 chat_sync 唯一客户端 API；path、snake_case 和响应包裹与 SparkService/iOS 相同。 */
export class ChatRemoteAPI {
  private readonly configuration: SupportBackendConfiguration;
  constructor(configuration: SupportBackendConfiguration) { this.configuration = configuration; }

  async push(messages: ChatRemoteMessageDTO[]): Promise<ChatPushAck> {
    const body = new ChatPushBody(); body.messages = messages;
    const op = this.operation('POST', '/api/v1/ai/chat/sync/push/', 'chat.sync.push', body, false, 'high');
    return this.configuration.executeDecoded(op, ChatRemoteAPI.decodePush);
  }

  async pushBlockUpdates(updates: ChatRemoteBlockUpdateDTO[]): Promise<ChatPushAck> {
    const body = new ChatPushBody(); body.block_updates = updates as Object[];
    const op = this.operation('POST', '/api/v1/ai/chat/sync/push/', 'chat.sync.push.blocks', body, true, 'high');
    return this.configuration.executeDecoded(op, ChatRemoteAPI.decodePush);
  }

  async pull(cursor?: string, threadId?: string, limit: number = 200): Promise<ChatPullResult> {
    const query: QueryItem[] = [];
    if (cursor) query.push(new QueryItem('cursor', cursor));
    if (threadId) query.push(new QueryItem('thread_id', threadId));
    query.push(new QueryItem('limit', `${Math.min(Math.max(limit, 1), 200)}`));
    const op = this.operation('GET', '/api/v1/ai/chat/sync/pull/', 'chat.sync.pull', undefined, true, 'normal', query);
    return this.configuration.executeDecoded(op, ChatRemoteAPI.decodePull);
  }

  async pullThreads(cursor?: string, limit: number = 100): Promise<ChatThreadPullResult> {
    const query: QueryItem[] = [new QueryItem('limit', `${Math.min(Math.max(limit, 1), 200)}`)];
    if (cursor) query.push(new QueryItem('cursor', cursor));
    const op = this.operation('GET', '/api/v1/ai/chat/sync/thread-pull/', 'chat.sync.threadPull', undefined, true, 'normal', query);
    return this.configuration.executeDecoded(op, ChatRemoteAPI.decodeThreadPull);
  }

  async pushThreads(threads: ChatRemoteThreadDTO[]): Promise<ChatRemoteThreadDTO[]> {
    const body = new ChatThreadPushBody(); body.threads = threads;
    const op = this.operation('POST', '/api/v1/ai/chat/sync/thread-push/', 'chat.sync.threadPush', body, false, 'high');
    return this.configuration.executeDecoded(op, (data: Object | null): ChatRemoteThreadDTO[] => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      const raw = obj['threads']; return ChatRemoteAPI.decodeThreads(raw);
    });
  }

  async deleteThreads(ids: string[]): Promise<string[]> {
    const body = new ChatThreadDeleteBody(); body.thread_ids = ids;
    const op = this.operation('POST', '/api/v1/ai/chat/sync/thread-delete/', 'chat.sync.threadDelete', body, false, 'high');
    return this.configuration.executeDecoded(op, (data: Object | null): string[] => {
      const obj = SupportAPIResponseDecoder.asRecord(data); const raw = obj['thread_ids'];
      return Array.isArray(raw) ? (raw as Object[]).map((v: Object): string => `${v}`) : [];
    });
  }

  private operation(method: 'GET' | 'POST', path: string, name: string, body?: Object, idempotent: boolean = true,
    priority: 'normal' | 'high' = 'normal', query: QueryItem[] = []): CacheableSupportNetworkOperation {
    const strategy = new NetworkStrategy(true, false, name, idempotent, priority, idempotent ? RetryConfig.defaultConfig() : RetryConfig.disabled());
    return new CacheableSupportNetworkOperation(name, 'ChatRemoteAPI', new NetworkRequest(method, path, strategy, query, {}, body));
  }

  private static decodePull(data: Object | null): ChatPullResult {
    const obj = SupportAPIResponseDecoder.asRecord(data); const result = new ChatPullResult();
    result.cursor = SupportAPIResponseDecoder.optStr(obj, 'cursor'); result.hasMore = SupportAPIResponseDecoder.bool(obj, 'has_more', false);
    result.messages = ChatRemoteAPI.decodeMessages(obj['messages']); return result;
  }
  private static decodeThreadPull(data: Object | null): ChatThreadPullResult {
    const obj = SupportAPIResponseDecoder.asRecord(data); const result = new ChatThreadPullResult();
    result.cursor = SupportAPIResponseDecoder.optStr(obj, 'cursor'); result.hasMore = SupportAPIResponseDecoder.bool(obj, 'has_more', false);
    result.threads = ChatRemoteAPI.decodeThreads(obj['threads']); return result;
  }
  private static decodePush(data: Object | null): ChatPushAck {
    const obj = SupportAPIResponseDecoder.asRecord(data); const result = new ChatPushAck();
    const messages = obj['accepted_messages']; const blocks = obj['accepted_block_updates'];
    if (Array.isArray(messages)) result.acceptedMessages = (messages as Object[]).map(ChatRemoteAPI.decodeAckMessage);
    if (Array.isArray(blocks)) result.acceptedBlocks = (blocks as Object[]).map(ChatRemoteAPI.decodeAckBlock);
    return result;
  }
  private static decodeMessages(raw: Object | string | number | boolean | null | undefined): ChatRemoteMessageDTO[] {
    if (!Array.isArray(raw)) return [];
    return (raw as Object[]).map(ChatRemoteAPI.decodeMessage);
  }
  private static decodeThreads(raw: Object | string | number | boolean | null | undefined): ChatRemoteThreadDTO[] {
    if (!Array.isArray(raw)) return [];
    return (raw as Object[]).map(ChatRemoteAPI.decodeThread);
  }
  private static decodeMessage(raw: Object): ChatRemoteMessageDTO {
    const o = SupportAPIResponseDecoder.asRecord(raw); const m = new ChatRemoteMessageDTO();
    m.thread_id = SupportAPIResponseDecoder.str(o, 'thread_id'); m.role = SupportAPIResponseDecoder.str(o, 'role', 'user');
    m.model_name = SupportAPIResponseDecoder.optStr(o, 'model_name'); m.client_message_id = SupportAPIResponseDecoder.str(o, 'client_message_id');
    m.server_message_id = SupportAPIResponseDecoder.optStr(o, 'server_message_id'); m.delivery_state = SupportAPIResponseDecoder.str(o, 'delivery_state', 'sent');
    m.created_at = SupportAPIResponseDecoder.str(o, 'created_at'); m.server_updated_at = SupportAPIResponseDecoder.optStr(o, 'server_updated_at');
    m.tombstone = SupportAPIResponseDecoder.bool(o, 'tombstone', false); m.reasoning_content = SupportAPIResponseDecoder.optStr(o, 'reasoning_content');
    m.reasoning_duration_ms = SupportAPIResponseDecoder.optNum(o, 'reasoning_duration_ms'); m.reasoning_expanded = SupportAPIResponseDecoder.bool(o, 'reasoning_expanded', false);
    m.reasoning_visibility = SupportAPIResponseDecoder.optStr(o, 'reasoning_visibility'); m.attachments = ChatRemoteAPI.asObjectArray(o['attachments']);
    m.blocks = ChatRemoteAPI.decodeBlocks(o['blocks']); return m;
  }
  private static decodeThread(raw: Object): ChatRemoteThreadDTO {
    const o = SupportAPIResponseDecoder.asRecord(raw); const t = new ChatRemoteThreadDTO();
    t.thread_id = SupportAPIResponseDecoder.str(o, 'thread_id'); t.title = SupportAPIResponseDecoder.str(o, 'title'); t.scenario = SupportAPIResponseDecoder.str(o, 'scenario', 'chat');
    t.patient_id = SupportAPIResponseDecoder.optStr(o, 'patient_id'); t.member_id = SupportAPIResponseDecoder.optNum(o, 'member_id'); t.is_deleted = SupportAPIResponseDecoder.bool(o, 'is_deleted', false);
    t.deleted_at = SupportAPIResponseDecoder.optStr(o, 'deleted_at'); t.updated_at = SupportAPIResponseDecoder.str(o, 'updated_at'); t.server_updated_at = SupportAPIResponseDecoder.str(o, 'server_updated_at', t.updated_at);
    t.image_delivery_mode = SupportAPIResponseDecoder.optStr(o, 'image_delivery_mode'); t.icon_name = SupportAPIResponseDecoder.optStr(o, 'icon_name'); t.icon_color_name = SupportAPIResponseDecoder.optStr(o, 'icon_color_name');
    t.is_pinned = SupportAPIResponseDecoder.bool(o, 'is_pinned', false); t.pinned_at = SupportAPIResponseDecoder.optStr(o, 'pinned_at'); t.current_model_name = SupportAPIResponseDecoder.optStr(o, 'current_model_name');
    t.temperature = SupportAPIResponseDecoder.optNum(o, 'temperature'); t.top_p = SupportAPIResponseDecoder.optNum(o, 'top_p'); t.max_tokens = SupportAPIResponseDecoder.optNum(o, 'max_tokens'); t.max_messages = SupportAPIResponseDecoder.optNum(o, 'max_messages');
    t.role_prompt = SupportAPIResponseDecoder.optStr(o, 'role_prompt'); t.system_prompt = SupportAPIResponseDecoder.optStr(o, 'system_prompt'); return t;
  }
  private static decodeBlocks(raw: Object | string | number | boolean | null | undefined): ChatRemoteBlockDTO[] {
    if (!Array.isArray(raw)) return [];
    return (raw as Object[]).map((value: Object): ChatRemoteBlockDTO => {
      const o = SupportAPIResponseDecoder.asRecord(value); const b = new ChatRemoteBlockDTO();
      b.id = SupportAPIResponseDecoder.str(o, 'id'); b.kind = SupportAPIResponseDecoder.str(o, 'kind', 'text'); b.status = SupportAPIResponseDecoder.str(o, 'status', 'ready'); b.revision = SupportAPIResponseDecoder.num(o, 'revision', 0); b.order_key = SupportAPIResponseDecoder.num(o, 'order_key', 0); b.tool_call_id = SupportAPIResponseDecoder.optStr(o, 'tool_call_id'); b.parent_tool_call_id = SupportAPIResponseDecoder.optStr(o, 'parent_tool_call_id'); b.parent_block_id = SupportAPIResponseDecoder.optStr(o, 'parent_block_id'); b.node_role = SupportAPIResponseDecoder.str(o, 'node_role', 'timeline'); b.anchor = o['anchor'] as Object; b.payload = (o['payload'] as Object) ?? new ChatJsonObject(); b.created_at = SupportAPIResponseDecoder.str(o, 'created_at'); b.updated_at = SupportAPIResponseDecoder.str(o, 'updated_at', b.created_at); return b;
    });
  }
  private static decodeAckMessage(raw: Object): ChatPushAckMessage { const o = SupportAPIResponseDecoder.asRecord(raw); const a = new ChatPushAckMessage(); a.client_message_id = SupportAPIResponseDecoder.str(o, 'client_message_id'); a.server_message_id = SupportAPIResponseDecoder.optStr(o, 'server_message_id'); a.server_updated_at = SupportAPIResponseDecoder.str(o, 'server_updated_at'); return a; }
  private static decodeAckBlock(raw: Object): ChatPushAckBlock { const o = SupportAPIResponseDecoder.asRecord(raw); const a = new ChatPushAckBlock(); a.client_message_id = SupportAPIResponseDecoder.str(o, 'client_message_id'); a.block_id = SupportAPIResponseDecoder.str(o, 'block_id'); a.server_updated_at = SupportAPIResponseDecoder.str(o, 'server_updated_at'); return a; }
  private static asObjectArray(raw: Object | string | number | boolean | null | undefined): Object[] { return Array.isArray(raw) ? raw as Object[] : []; }
}

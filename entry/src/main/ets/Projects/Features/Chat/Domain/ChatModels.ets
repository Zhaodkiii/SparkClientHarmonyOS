/** Chat 领域模型（对齐 iOS ChatMessage / ChatMessageBlock 精简集） */
export type ChatMessageRole = 'system' | 'user' | 'assistant';
export type ChatMessageKind = 'text' | 'tool' | 'system' | 'error';
/** 本地状态兼容 iOS/服务端 delivery_state；sent/read 映射为 completed。 */
export type ChatDeliveryStatus = 'pending' | 'sending' | 'streamed' | 'completed' | 'failed' | 'cancelled' | 'sent' | 'read';
export type ChatBlockKind =
  | 'text' | 'deepThought' | 'tool' | 'error' | 'assistantStatusCard' | 'toolPresentation' | 'rich'
  | 'imageGallery' | 'fileAttachments' | 'knowledgeCards' | 'translatedText' | 'mapRoute'
  | 'events' | 'healthCards' | 'pendingMemberToolCards' | 'structuredHealthCards'
  | 'sleepVisualization' | 'nutritionCards' | 'workoutVisualization' | 'captureCard'
  | 'html' | 'smallTaskCard' | 'taskCards' | 'healthResourceReference'
  | 'medicalRiskNotice' | 'medicalDisclaimerCard';

export class ChatThread {
  clientId: string = '';
  /** 线程 ID 与服务端 UUID 相同；clientId 保留兼容已有本地表。 */
  threadId: string = '';
  accountId: number = 0;
  title: string = '';
  scenario: string = 'chat';
  patientId?: string;
  createdAt: string = '';
  updatedAt: string = '';
  serverUpdatedAt?: string;
  isDeleted: boolean = false;
  deletedAt?: string;
  preferredModelName?: string;
  memberId?: number;
  temperature?: number;
  topP: number = 1.0;
  maxTokens?: number;
  maxMessages: number = 20;
  rolePrompt: string = '';
  imageDeliveryMode?: string;
  iconName?: string;
  iconColorName?: string;
  isPinned: boolean = false;
  pinnedAt?: string;
}

export class ChatMessageBlock {
  blockId: string = '';
  kind: ChatBlockKind = 'text';
  text: string = '';
  toolName?: string;
  toolCallId?: string;
  orderKey: number = 0;
  revision: number = 0;
  status: string = 'ready';
  parentToolCallId?: string;
  parentBlockId?: string;
  nodeRole: string = 'timeline';
  anchorJson?: string;
  payloadJson: string = '{}';
  createdAt: string = '';
  serverUpdatedAt?: string;
  /** 块级 outbox 状态；允许主消息已同步后继续上传迟到的结构化块。 */
  syncState: string = 'pending';
  updatedAt: string = '';
}

export class ChatMessage {
  clientId: string = '';
  serverMessageId?: string;
  threadClientId: string = '';
  threadId: string = '';
  accountId: number = 0;
  role: ChatMessageRole = 'user';
  kind: ChatMessageKind = 'text';
  text: string = '';
  deliveryStatus: ChatDeliveryStatus = 'pending';
  requestId?: string;
  errorCode?: string;
  modelName?: string;
  tombstone: boolean = false;
  serverUpdatedAt?: string;
  attachmentsJson: string = '[]';
  reasoningContent?: string;
  reasoningDurationMs?: number;
  reasoningExpanded: boolean = false;
  reasoningVisibility?: string;
  /** Outbox 状态：pending/sending/synced/failed。 */
  syncState: string = 'pending';
  syncAttemptCount: number = 0;
  lastSyncError?: string;
  localRevision: number = 0;
  createdAt: string = '';
  updatedAt: string = '';
  blocks: ChatMessageBlock[] = [];
}

export type ChatAttachmentKind = 'image' | 'pdf' | 'file' | 'toolContent';

export class ChatAttachment {
  id: string = '';
  kind: ChatAttachmentKind = 'file';
  fileId?: string;
  fileMd5?: string;
  fileName?: string;
  mimeType?: string;
  size?: number;
  url?: string;
  text?: string;
  fullCacheKey?: string;
  fileUuid?: string;
  objectKey?: string;
  isChatImageLike: boolean = false;
  static fromJson(raw: Object): ChatAttachment {
    const o = raw as Record<string, Object | string | number | boolean | null>;
    const a = new ChatAttachment();
    a.id = `${o['id'] ?? o['attachment_id'] ?? ''}`;
    a.kind = ChatModels.parseAttachmentKind(`${o['type'] ?? o['kind'] ?? 'file'}`);
    a.fileId = o['file_id'] ? `${o['file_id']}` : undefined;
    a.fileUuid = o['file_uuid'] ? `${o['file_uuid']}` : undefined;
    a.fileMd5 = o['file_md5'] ? `${o['file_md5']}` : undefined;
    a.fileName = o['file_name'] ? `${o['file_name']}` : undefined;
    a.mimeType = o['mime_type'] ? `${o['mime_type']}` : undefined;
    a.size = typeof o['size'] === 'number' ? o['size'] as number : undefined;
    a.url = o['url'] ? `${o['url']}` : undefined;
    a.text = o['text'] ? `${o['text']}` : undefined;
    a.fullCacheKey = o['full_cache_key'] ? `${o['full_cache_key']}` : undefined;
    a.objectKey = o['object_key'] ? `${o['object_key']}` : undefined;
    a.isChatImageLike = a.kind === 'image' || (a.mimeType !== undefined && a.mimeType.startsWith('image/'));
    return a;
  }
}

export class ChatModels {
  static parseAttachmentKind(raw: string): ChatAttachmentKind {
    if (raw === 'image' || raw === 'pdf' || raw === 'toolContent') {
      return raw;
    }
    return 'file';
  }
}

export class ChatAttachmentDownloadJob {
  id: string = '';
  dedupeKey: string = '';
  attachmentId: string = '';
  clientMessageId: string = '';
  threadClientId: string = '';
  payloadJson: string = '{}';
  state: string = 'pending';
  localFilePath?: string;
  attemptCount: number = 0;
  lastError?: string;
}

/** 对齐 iOS ChatPendingMessageBlock：父消息与块的独立 Outbox 投影。 */
export class ChatPendingMessageBlock {
  threadId: string = '';
  clientMessageId: string = '';
  block: ChatMessageBlock = new ChatMessageBlock();
}

export class ChatNewId {
  static uuidLike(): string {
    // SparkService 的 UUIDField/UUID 主键要求 RFC 4122 形态。
    // 这里保留 uuidLike 名称以减少调用方改动，但不再生成 c_... 业务字符串。
    const hex = '0123456789abcdef';
    let out = '';
    for (let i = 0; i < 32; i++) {
      out += hex.charAt(Math.floor(Math.random() * 16));
    }
    out = `${out.substring(0, 12)}4${out.substring(13)}`;
    const variant = ['8', '9', 'a', 'b'][Math.floor(Math.random() * 4)];
    out = `${out.substring(0, 16)}${variant}${out.substring(17)}`;
    return `${out.substring(0, 8)}-${out.substring(8, 12)}-${out.substring(12, 16)}-${out.substring(16, 20)}-${out.substring(20)}`;
  }

  static isUUID(value: string | undefined): boolean {
    if (!value) return false;
    return /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$/.test(value);
  }
}

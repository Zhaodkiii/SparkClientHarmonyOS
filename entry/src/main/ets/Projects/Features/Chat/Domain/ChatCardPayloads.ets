/** 卡片 payload 的 ArkTS 显式模型；避免 UI 直接依赖无类型 JSON 对象。 */
export class ChatCardActionPolicy {
  canOpen: boolean = false;
  canSave: boolean = false;
  canRetry: boolean = false;
  canSelectMember: boolean = false;
}

export class ChatCardEnvelope {
  schemaVersion: string = '1.0';
  cardId: string = '';
  title: string = '';
  subtitle: string = '';
  status: string = 'ready';
  source: string = 'ai';
  createdAt: string = '';
  actionPolicy: ChatCardActionPolicy = new ChatCardActionPolicy();
}

export class ChatToolCardPayload extends ChatCardEnvelope {
  toolName: string = '';
  toolCallId: string = '';
  invocationSummary: string = '';
  resultSummary: string = '';
  waitingForConsent: boolean = false;
}

export class ChatHealthMetricPayload {
  key: string = '';
  label: string = '';
  value: string = '';
  unit: string = '';
  trend: string = '';
  measuredAt: string = '';
  source: string = '';
}

export class ChatHealthCardPayload extends ChatCardEnvelope {
  memberId: number = 0;
  rangeStart: string = '';
  rangeEnd: string = '';
  metrics: ChatHealthMetricPayload[] = [];
  attribution: string = '';
}

export class ChatAttachmentCardItem {
  id: string = '';
  kind: string = 'file';
  name: string = '';
  mimeType: string = '';
  size: number = 0;
  url: string = '';
  localPath: string = '';
  state: string = 'ready';
  ocrText: string = '';
}

export class ChatAttachmentCardPayload extends ChatCardEnvelope {
  items: ChatAttachmentCardItem[] = [];
}

export class ChatTaskCardItem {
  id: string = '';
  title: string = '';
  brief: string = '';
  state: string = 'pending';
  dueAt: string = '';
  actionLabel: string = '';
}

export class ChatTaskCardPayload extends ChatCardEnvelope {
  items: ChatTaskCardItem[] = [];
}

export class ChatMedicalNoticePayload extends ChatCardEnvelope {
  severity: string = 'info';
  message: string = '';
  disclaimer: string = '';
  requiresProfessionalCare: boolean = false;
}

export class ChatCardPayloadDecoder {
  static decode<T extends ChatCardEnvelope>(raw: string, target: T): T {
    try {
      const parsed = JSON.parse(raw) as Object;
      const record = parsed as Record<string, Object | string | number | boolean | null>;
      const schema = record['schemaVersion']; if (typeof schema === 'string') target.schemaVersion = schema;
      const cardId = record['cardId']; if (typeof cardId === 'string') target.cardId = cardId;
      const title = record['title']; if (typeof title === 'string') target.title = title;
      const subtitle = record['subtitle']; if (typeof subtitle === 'string') target.subtitle = subtitle;
      const status = record['status']; if (typeof status === 'string') target.status = status;
      const source = record['source']; if (typeof source === 'string') target.source = source;
      const createdAt = record['createdAt']; if (typeof createdAt === 'string') target.createdAt = createdAt;
    } catch (_e) {
      target.status = 'failed';
    }
    return target;
  }
}

/**
 * 应用内通知领域模型；level/presentation/dropReason rawValue 与 iOS 对齐。
 */

export type NotificationLevel = 'success' | 'error' | 'warning' | 'info';
export type NotificationPresentation = 'toast' | 'banner' | 'alert';
export type NotificationDropReason = 'duplicate' | 'queueOverflow';

export type NotificationTapAction = () => void;

export class NotificationIntent {
  title?: string;
  message: string;
  level: NotificationLevel;
  presentation: NotificationPresentation;
  dedupeKey?: string;
  source: string;
  /** 毫秒；未设则由 Delivery 按 presentation 默认 */
  autoDismissAfterMs?: number;
  onTap?: NotificationTapAction;

  constructor(
    message: string,
    level: NotificationLevel,
    presentation: NotificationPresentation = 'toast',
    source: string = 'app',
    title?: string,
    dedupeKey?: string,
    autoDismissAfterMs?: number,
    onTap?: NotificationTapAction
  ) {
    this.message = message;
    this.level = level;
    this.presentation = presentation;
    this.source = source;
    this.title = title;
    this.dedupeKey = dedupeKey;
    this.autoDismissAfterMs = autoDismissAfterMs;
    this.onTap = onTap;
  }

  static toast(message: string, level: NotificationLevel, source: string = 'app', title?: string): NotificationIntent {
    return new NotificationIntent(message, level, 'toast', source, title);
  }

  static banner(message: string, level: NotificationLevel, source: string = 'app', title?: string): NotificationIntent {
    return new NotificationIntent(message, level, 'banner', source, title);
  }

  static alert(message: string, level: NotificationLevel, source: string = 'app', title?: string): NotificationIntent {
    return new NotificationIntent(message, level, 'alert', source, title);
  }
}

export class NotificationMessage {
  id: string;
  title?: string;
  message: string;
  level: NotificationLevel;
  presentation: NotificationPresentation;
  source: string;
  dedupeKey: string;
  enqueuedAtMs: number;
  autoDismissAfterMs?: number;

  constructor(
    id: string,
    message: string,
    level: NotificationLevel,
    presentation: NotificationPresentation,
    source: string,
    dedupeKey: string,
    enqueuedAtMs: number,
    title?: string,
    autoDismissAfterMs?: number
  ) {
    this.id = id;
    this.message = message;
    this.level = level;
    this.presentation = presentation;
    this.source = source;
    this.dedupeKey = dedupeKey;
    this.enqueuedAtMs = enqueuedAtMs;
    this.title = title;
    this.autoDismissAfterMs = autoDismissAfterMs;
  }

  static fromIntent(intent: NotificationIntent): NotificationMessage {
    const trimmed = intent.dedupeKey !== undefined ? intent.dedupeKey.trim() : '';
    const fallback =
      `${intent.level}|${intent.presentation}|${intent.message.toLowerCase()}`;
    const key = trimmed.length > 0 ? trimmed : fallback;
    return new NotificationMessage(
      NotificationMessage.newId(),
      intent.message,
      intent.level,
      intent.presentation,
      intent.source,
      key,
      Date.now(),
      intent.title,
      intent.autoDismissAfterMs
    );
  }

  static defaultPresentationFor(level: NotificationLevel): NotificationPresentation {
    if (level === 'error' || level === 'warning') {
      return 'banner';
    }
    return 'toast';
  }

  static newId(): string {
    return `n_${Date.now().toString(36)}_${Math.floor(Math.random() * 1e9).toString(36)}`;
  }

  toUiJson(): string {
    const payload: Record<string, string> = {};
    payload['id'] = this.id;
    payload['title'] = this.title ?? '';
    payload['message'] = this.message;
    payload['level'] = this.level;
    payload['presentation'] = this.presentation;
    payload['source'] = this.source;
    return JSON.stringify(payload);
  }

  static fromUiJson(json: string): NotificationMessage | undefined {
    if (!json || json.length === 0) {
      return undefined;
    }
    try {
      const obj = JSON.parse(json) as Record<string, string>;
      return new NotificationMessage(
        obj['id'] ?? '',
        obj['message'] ?? '',
        (obj['level'] as NotificationLevel) ?? 'info',
        (obj['presentation'] as NotificationPresentation) ?? 'toast',
        obj['source'] ?? 'app',
        '',
        Date.now(),
        obj['title'] && obj['title'].length > 0 ? obj['title'] : undefined
      );
    } catch (_e) {
      return undefined;
    }
  }
}

export class NotificationInboxItem {
  id: string;
  title?: string;
  message: string;
  level: NotificationLevel;
  presentation: NotificationPresentation;
  source: string;
  createdAtMs: number;
  presentedAtMs?: number;
  dismissedAtMs?: number;
  droppedReason?: NotificationDropReason;

  constructor(
    id: string,
    message: string,
    level: NotificationLevel,
    presentation: NotificationPresentation,
    source: string,
    createdAtMs: number,
    title?: string
  ) {
    this.id = id;
    this.message = message;
    this.level = level;
    this.presentation = presentation;
    this.source = source;
    this.createdAtMs = createdAtMs;
    this.title = title;
  }

  static queued(message: NotificationMessage): NotificationInboxItem {
    return new NotificationInboxItem(
      message.id,
      message.message,
      message.level,
      message.presentation,
      message.source,
      message.enqueuedAtMs,
      message.title
    );
  }

  static fromPlain(obj: Record<string, Object | string | number | undefined>): NotificationInboxItem {
    const item = new NotificationInboxItem(
      `${obj['id'] ?? ''}`,
      `${obj['message'] ?? ''}`,
      (obj['level'] as NotificationLevel) ?? 'info',
      (obj['presentation'] as NotificationPresentation) ?? 'toast',
      `${obj['source'] ?? 'app'}`,
      typeof obj['createdAtMs'] === 'number' ? obj['createdAtMs'] : Date.now(),
      obj['title'] !== undefined && `${obj['title']}`.length > 0 ? `${obj['title']}` : undefined
    );
    if (typeof obj['presentedAtMs'] === 'number') {
      item.presentedAtMs = obj['presentedAtMs'];
    }
    if (typeof obj['dismissedAtMs'] === 'number') {
      item.dismissedAtMs = obj['dismissedAtMs'];
    }
    if (typeof obj['droppedReason'] === 'string') {
      item.droppedReason = obj['droppedReason'] as NotificationDropReason;
    }
    return item;
  }

  toPlain(): Record<string, string | number | undefined> {
    const out: Record<string, string | number | undefined> = {};
    out['id'] = this.id;
    out['title'] = this.title;
    out['message'] = this.message;
    out['level'] = this.level;
    out['presentation'] = this.presentation;
    out['source'] = this.source;
    out['createdAtMs'] = this.createdAtMs;
    out['presentedAtMs'] = this.presentedAtMs;
    out['dismissedAtMs'] = this.dismissedAtMs;
    out['droppedReason'] = this.droppedReason;
    return out;
  }
}

export class NotificationMetricsSnapshot {
  enqueuedCount: number = 0;
  displayedCount: number = 0;
  droppedDuplicateCount: number = 0;
  droppedOverflowCount: number = 0;
  averageDisplayLatencyMs: number = 0;
}

export class NotificationEnqueueResult {
  enqueued: boolean;
  message: NotificationMessage;
  dropReason?: NotificationDropReason;

  constructor(enqueued: boolean, message: NotificationMessage, dropReason?: NotificationDropReason) {
    this.enqueued = enqueued;
    this.message = message;
    this.dropReason = dropReason;
  }

  static enqueued(message: NotificationMessage): NotificationEnqueueResult {
    return new NotificationEnqueueResult(true, message);
  }

  static dropped(message: NotificationMessage, reason: NotificationDropReason): NotificationEnqueueResult {
    return new NotificationEnqueueResult(false, message, reason);
  }
}

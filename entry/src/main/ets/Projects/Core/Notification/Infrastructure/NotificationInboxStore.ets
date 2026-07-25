import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import {
  NotificationDropReason,
  NotificationInboxItem,
  NotificationMessage
} from '../Domain/NotificationModels';
import { ErrorLogger } from '../../../../Foundation/Logging/ErrorLogger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';

/**
 * 通知历史：最多 500 条；写失败不阻塞展示。
 * 启动加载必须有文件大小上限，禁止整文件逐字节拼字符串（易 SharedHeap OOM）。
 */
export class NotificationInboxStore {
  private readonly maxItems: number = 500;
  /** 500 条摘要级 JSON 远小于此；超限视为损坏并重置，避免冷启动 OOM。 */
  private static readonly MAX_INBOX_FILE_BYTES: number = 512 * 1024;
  private readonly path: string;
  private items: NotificationInboxItem[] = [];
  private readonly persistEnabled: boolean;

  constructor(filesDirOrPath: string, absoluteFilePath: boolean = false) {
    if (absoluteFilePath) {
      this.path = filesDirOrPath;
      // 空路径：单测用内存 inbox，不落盘
      this.persistEnabled = filesDirOrPath.length > 0;
      this.items = [];
      return;
    }
    const dir = `${filesDirOrPath}/SupportClient`;
    NotificationInboxStore.ensureDir(dir);
    this.path = `${dir}/notification_inbox.json`;
    this.persistEnabled = true;
    this.items = this.loadItems();
  }

  get allItems(): NotificationInboxItem[] {
    return this.items.slice();
  }

  get count(): number {
    return this.items.length;
  }

  async appendQueued(message: NotificationMessage): Promise<void> {
    this.items.unshift(NotificationInboxItem.queued(message));
    this.trim();
    await this.persistSafely();
  }

  async markPresented(messageId: string, atMs: number = Date.now()): Promise<void> {
    const item = this.find(messageId);
    if (item) {
      item.presentedAtMs = atMs;
      await this.persistSafely();
    }
  }

  async markDismissed(messageId: string, atMs: number = Date.now()): Promise<void> {
    const item = this.find(messageId);
    if (item) {
      item.dismissedAtMs = atMs;
      await this.persistSafely();
    }
  }

  async markDropped(
    message: NotificationMessage,
    reason: NotificationDropReason,
    atMs: number = Date.now()
  ): Promise<void> {
    const item = NotificationInboxItem.queued(message);
    item.droppedReason = reason;
    item.createdAtMs = atMs;
    this.items.unshift(item);
    this.trim();
    await this.persistSafely();
  }

  async clear(): Promise<void> {
    this.items = [];
    if (!this.persistEnabled) {
      return;
    }
    try {
      if (fs.accessSync(this.path)) {
        fs.unlinkSync(this.path);
      }
    } catch (_e) {
      // ignore
    }
  }

  private find(messageId: string): NotificationInboxItem | undefined {
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].id === messageId) {
        return this.items[i];
      }
    }
    return undefined;
  }

  private trim(): void {
    if (this.items.length > this.maxItems) {
      this.items = this.items.slice(0, this.maxItems);
    }
  }

  private loadItems(): NotificationInboxItem[] {
    try {
      if (!fs.accessSync(this.path)) {
        return [];
      }
      const stat = fs.statSync(this.path);
      if (stat.size <= 0) {
        return [];
      }
      // 必须在分配 ArrayBuffer 之前拦截，否则超大文件直接 SharedHeap OOM。
      if (stat.size > NotificationInboxStore.MAX_INBOX_FILE_BYTES) {
        this.resetCorruptFile('oversized', stat.size);
        return [];
      }
      const file = fs.openSync(this.path, fs.OpenMode.READ_ONLY);
      let content = '';
      try {
        const buf = new ArrayBuffer(stat.size);
        const read = fs.readSync(file.fd, buf);
        if (read <= 0) {
          return [];
        }
        // 仅解码实际读到的字节，避免未填满区域干扰。
        const view = read === stat.size ? new Uint8Array(buf) : new Uint8Array(buf, 0, read);
        content = NotificationInboxStore.decodeUtf8(view);
      } finally {
        fs.closeSync(file);
      }
      if (!content || content.length === 0) {
        return [];
      }
      const arr = JSON.parse(content) as Object[];
      if (!Array.isArray(arr)) {
        this.resetCorruptFile('not_array', stat.size);
        return [];
      }
      const out: NotificationInboxItem[] = [];
      const limit = arr.length < this.maxItems ? arr.length : this.maxItems;
      for (let i = 0; i < limit; i++) {
        out.push(NotificationInboxItem.fromPlain(arr[i] as Record<string, Object | string | number | undefined>));
      }
      // 磁盘条数超限：加载后写回裁剪结果，防止文件继续膨胀。
      if (arr.length > this.maxItems) {
        this.items = out;
        this.persistSafely().catch(() => {
          // ignore
        });
      }
      return out;
    } catch (e) {
      ErrorLogger.log('notification.inbox_load_failed', LogModule.NOTIFICATION, e as Object);
      try {
        this.resetCorruptFile('load_exception', 0);
      } catch (_resetErr) {
        // ignore
      }
      return [];
    }
  }

  private resetCorruptFile(reason: string, size: number): void {
    const fields = new LogFields();
    fields.operation = 'notification.inbox';
    fields.detail = `reason=${reason};sizeBytes=${size};action=reset`;
    Logger.warn('notification.inbox_reset', LogModule.NOTIFICATION, fields);
    try {
      if (fs.accessSync(this.path)) {
        fs.unlinkSync(this.path);
      }
    } catch (_e) {
      // ignore
    }
  }

  private async persistSafely(): Promise<void> {
    if (!this.persistEnabled) {
      return;
    }
    try {
      this.trim();
      const plain: Object[] = [];
      for (let i = 0; i < this.items.length; i++) {
        plain.push(this.items[i].toPlain());
      }
      const text = JSON.stringify(plain);
      // 防御：异常大 payload 不落盘，避免下次启动再次 OOM。
      if (text.length > NotificationInboxStore.MAX_INBOX_FILE_BYTES) {
        const fields = new LogFields();
        fields.operation = 'notification.inbox';
        fields.detail = `reason=persist_too_large;chars=${text.length}`;
        Logger.warn('notification.inbox_persist_skipped', LogModule.NOTIFICATION, fields);
        return;
      }
      const file = fs.openSync(this.path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, text);
      } finally {
        fs.closeSync(file);
      }
    } catch (err) {
      ErrorLogger.log('notification.inbox_persist_failed', LogModule.NOTIFICATION, err as Object);
    }
  }

  private static ensureDir(dir: string): void {
    try {
      fs.mkdirSync(dir, true);
    } catch (_e) {
      // may exist
    }
  }

  /** UTF-8 解码；禁止 fromCharCode 循环拼接（大文件会 O(n²) 撑爆堆）。 */
  private static decodeUtf8(bytes: Uint8Array): string {
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    return decoder.decodeWithStream(bytes);
  }
}

import { FileDownloadOptions, ManagedFileRecord } from '../../../../Core/FileStorage/FileStorageModels';
import { FileTransferService } from '../../../../Core/FileStorage/FileTransferService';
import { ChatAttachmentDownloadJob } from '../Domain/ChatModels';
import { ChatRepository } from './ChatRepository';

class ChatAttachmentPayload {
  id: string = '';
  file_id: number = 0;
  file_uuid: string = '';
  file_name: string = '';
  file_size: number = 0;
  mime_type: string = '';
  file_md5: string = '';
  object_key: string = '';
}

/** 对齐 iOS ChatAttachmentPipeline：同步完成后消费下载任务并写入账号隔离缓存。 */
export class ChatAttachmentPipeline {
  private readonly repository: ChatRepository;
  private readonly fileTransfer: FileTransferService;
  private readonly getAccountId: () => number | undefined;
  private readonly getGeneration: () => number;
  private running?: Promise<void>;

  constructor(
    repository: ChatRepository,
    fileTransfer: FileTransferService,
    getAccountId: () => number | undefined,
    getGeneration: () => number
  ) {
    this.repository = repository;
    this.fileTransfer = fileTransfer;
    this.getAccountId = getAccountId;
    this.getGeneration = getGeneration;
  }

  async processPending(limit: number = 20): Promise<void> {
    if (this.running) {
      return this.running;
    }
    this.running = this.processInternal(limit).finally(() => { this.running = undefined; });
    return this.running;
  }

  private async processInternal(limit: number): Promise<void> {
    const accountId = this.getAccountId();
    if (accountId === undefined || accountId <= 0) {
      return;
    }
    const jobs = await this.repository.listPendingAttachmentJobs(accountId, limit);
    for (let i = 0; i < jobs.length; i++) {
      await this.processOne(accountId, jobs[i]);
    }
  }

  private async processOne(accountId: number, job: ChatAttachmentDownloadJob): Promise<void> {
    await this.repository.updateAttachmentJob(accountId, job.id, 'processing');
    try {
      const payload = this.decode(job.payloadJson);
      if (payload.file_id <= 0) {
        throw new Error('attachmentRemoteIdentityMissing');
      }
      const record = new ManagedFileRecord();
      record.id = payload.file_id;
      record.fileUuid = payload.file_uuid.length > 0 ? payload.file_uuid : `remote_file_${payload.file_id}`;
      record.originalName = payload.file_name;
      record.fileSize = payload.file_size;
      record.mimeType = payload.mime_type;
      record.fileMd5 = payload.file_md5;
      record.objectKey = payload.object_key;
      const options = new FileDownloadOptions();
      options.expectedMd5 = record.fileMd5;
      options.generation = this.getGeneration();
      const cached = await this.fileTransfer.cachedURL(record, record.fileMd5);
      const handle = cached ?? await this.fileTransfer.download(record, options);
      await this.repository.updateAttachmentJob(accountId, job.id, 'completed', handle.localPath);
    } catch (err) {
      const message = `${err}`;
      await this.repository.updateAttachmentJob(accountId, job.id, 'failed', undefined, message.substring(0, 200));
    }
  }

  private decode(raw: string): ChatAttachmentPayload {
    const parsed: Object = JSON.parse(raw) as Object;
    const source = parsed as Record<string, Object | string | number | boolean | null>;
    const p = new ChatAttachmentPayload();
    p.id = ChatAttachmentPipeline.stringValue(source['id'] ?? source['attachment_id']);
    p.file_id = ChatAttachmentPipeline.numberValue(source['file_id']);
    p.file_uuid = ChatAttachmentPipeline.stringValue(source['file_uuid'] ?? source['file_id_uuid']);
    p.file_name = ChatAttachmentPipeline.stringValue(source['file_name'] ?? source['file_name_original']);
    p.file_size = ChatAttachmentPipeline.numberValue(source['file_size']);
    p.mime_type = ChatAttachmentPipeline.stringValue(source['mime_type']);
    p.file_md5 = ChatAttachmentPipeline.stringValue(source['file_md5']);
    p.object_key = ChatAttachmentPipeline.stringValue(source['object_key'] ?? source['full_cache_key']);
    return p;
  }

  private static stringValue(value: Object | string | number | boolean | null | undefined): string {
    return value === null || value === undefined ? '' : `${value}`;
  }

  private static numberValue(value: Object | string | number | boolean | null | undefined): number {
    if (typeof value === 'number') return value;
    const n = Number(ChatAttachmentPipeline.stringValue(value));
    return Number.isNaN(n) ? 0 : n;
  }
}

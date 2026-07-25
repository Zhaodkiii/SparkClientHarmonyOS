import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ManagedFileRecord } from '../../../../Core/FileStorage/FileStorageModels';
import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalDocumentUploadEntrySource } from '../Domain/MedicalDocumentUploadModels';
import { MedicalDocumentUploadCheckpointStage } from '../Domain/MedicalDocumentUploadPipeline';

const PREF_NAME: string = 'medical_document_upload_checkpoints';
const SESSION_PREFIX: string = 'session_';
const LATEST_PREFIX: string = 'latest_';
const ACCOUNT_INDEX_PREFIX: string = 'account_index_';

class PersistedMedicalCheckpointFile {
  localId: string = '';
  uri: string = '';
  displayName: string = '';
  mimeType: string = '';
  remoteFileId: number = 0;
  fileUuid: string = '';
  objectKey: string = '';
  filePath: string = '';
  fileSize: number = 0;
  fileMd5: string = '';
  /** 单文件 OCR 文本（非敏感）。 */
  ocrText: string = '';
}

class PersistedMedicalDocumentUploadCheckpoint {
  uploadSessionId: string = '';
  accountId: number = 0;
  memberId: number = 0;
  source: string = MedicalDocumentUploadEntrySource.HOME;
  selectedFiles: PersistedMedicalCheckpointFile[] = [];
  uploadedFiles: PersistedMedicalCheckpointFile[] = [];
  stage: string = 'picking';
  updatedAt: string = '';
  selectedKind: string = '';
  pipelineOCRText: string = '';
  typeResolutionJSON: string = '';
  extractedJSON: string = '';
  failedStep: string = '';
}

/** 断点快照（工单预提交校验与断点续跑）。禁止写入 STS / Token / API Key。 */
export class MedicalDocumentUploadCheckpoint {
  uploadSessionId: string = '';
  accountId: number = 0;
  memberId: number = 0;
  source: MedicalDocumentUploadEntrySource = MedicalDocumentUploadEntrySource.HOME;
  selectedFiles: MedicalCheckpointFileSnapshot[] = [];
  uploadedFiles: MedicalCheckpointFileSnapshot[] = [];
  stage: MedicalDocumentUploadCheckpointStage = 'picking';
  updatedAt: string = '';
  /** 用户选择的文档类型。 */
  selectedKind: string = '';
  /** 合并 OCR 文本（可恢复类型判定 / 抽取）。 */
  pipelineOCRText: string = '';
  /** 类型判定 JSON。 */
  typeResolutionJSON: string = '';
  /** 结构化抽取 JSON（可重建 typedDrafts）。 */
  extractedJSON: string = '';
  /** 失败步骤（可选）。 */
  failedStep: string = '';
}

/** 快照内文件：仅 UUID / 远端记录 / URI / OCR 文本，无密钥。 */
export class MedicalCheckpointFileSnapshot {
  localId: string = '';
  uri: string = '';
  displayName: string = '';
  mimeType: string = '';
  remoteFileId: number = 0;
  fileUuid: string = '';
  objectKey: string = '';
  filePath: string = '';
  fileSize: number = 0;
  fileMd5: string = '';
  ocrText: string = '';

  static fromAttachment(file: MedicalAttachmentInput): MedicalCheckpointFileSnapshot {
    const snap = new MedicalCheckpointFileSnapshot();
    snap.localId = file.previewId;
    snap.uri = file.sourceUri;
    snap.displayName = file.originalName;
    snap.mimeType = file.mimeType;
    snap.ocrText = file.ocrText;
    if (file.remoteFile !== undefined) {
      snap.remoteFileId = file.remoteFile.id;
      snap.fileUuid = file.remoteFile.fileUuid;
      snap.objectKey = file.remoteFile.objectKey;
      snap.filePath = file.remoteFile.filePath;
      snap.fileSize = file.remoteFile.fileSize;
      snap.fileMd5 = file.remoteFile.fileMd5;
    }
    return snap;
  }

  toAttachment(): MedicalAttachmentInput {
    const input = new MedicalAttachmentInput();
    input.previewId = this.localId;
    input.sourceUri = this.uri;
    input.originalName = this.displayName;
    input.mimeType = this.mimeType;
    input.ocrText = this.ocrText;
    if (this.remoteFileId > 0 || this.fileUuid.length > 0) {
      const remote = new ManagedFileRecord();
      remote.id = this.remoteFileId;
      remote.fileUuid = this.fileUuid;
      remote.objectKey = this.objectKey;
      remote.filePath = this.filePath;
      remote.fileSize = this.fileSize;
      remote.fileMd5 = this.fileMd5;
      remote.originalName = this.displayName;
      remote.mimeType = this.mimeType;
      remote.businessType = 'medical_document_upload_source';
      remote.storageType = 'oss';
      input.remoteFile = remote;
    }
    return input;
  }
}

export interface MedicalDocumentUploadCheckpointStore {
  save(snapshot: MedicalDocumentUploadCheckpoint): Promise<void>;
  load(uploadSessionId: string): Promise<MedicalDocumentUploadCheckpoint | undefined>;
  /** 按账号+成员加载最近一次会话（重进页面恢复）。 */
  loadLatest(accountId: number, memberId: number): Promise<MedicalDocumentUploadCheckpoint | undefined>;
  clear(uploadSessionId: string): Promise<void>;
}

/**
 * Preferences 断点仓库：保存非敏感上传阶段快照，用于重进页面恢复已上传源文件。
 * 只保存文件中心返回的 metadata / 阶段 / 账号成员索引；禁止保存 STS、Token、API Key。
 */
export class PreferencesMedicalDocumentUploadCheckpointStore implements MedicalDocumentUploadCheckpointStore {
  private pref?: preferences.Preferences;
  private readonly ready: Promise<void>;

  constructor(context: common.Context) {
    this.ready = preferences.getPreferences(context, PREF_NAME)
      .then((p: preferences.Preferences) => {
        this.pref = p;
      })
      .catch(() => {
        this.pref = undefined;
      });
  }

  async save(snapshot: MedicalDocumentUploadCheckpoint): Promise<void> {
    await this.ensureReady();
    if (!this.pref || snapshot.uploadSessionId.length === 0) {
      return;
    }
    const sessionKey = PreferencesMedicalDocumentUploadCheckpointStore.sessionKey(snapshot.uploadSessionId);
    const latestKey = PreferencesMedicalDocumentUploadCheckpointStore.latestKey(
      snapshot.accountId,
      snapshot.memberId
    );
    await this.pref.put(sessionKey, PreferencesMedicalDocumentUploadCheckpointStore.toJson(snapshot));
    await this.pref.put(latestKey, snapshot.uploadSessionId);
    await this.addAccountIndex(snapshot.accountId, sessionKey, latestKey);
    await this.pref.flush();
  }

  async load(uploadSessionId: string): Promise<MedicalDocumentUploadCheckpoint | undefined> {
    await this.ensureReady();
    if (!this.pref || uploadSessionId.length === 0) {
      return undefined;
    }
    const raw = await this.pref.get(
      PreferencesMedicalDocumentUploadCheckpointStore.sessionKey(uploadSessionId),
      ''
    );
    if (typeof raw !== 'string' || raw.length === 0) {
      return undefined;
    }
    return PreferencesMedicalDocumentUploadCheckpointStore.fromJson(raw);
  }

  async loadLatest(accountId: number, memberId: number): Promise<MedicalDocumentUploadCheckpoint | undefined> {
    await this.ensureReady();
    if (!this.pref || accountId <= 0 || memberId <= 0) {
      return undefined;
    }
    const raw = await this.pref.get(
      PreferencesMedicalDocumentUploadCheckpointStore.latestKey(accountId, memberId),
      ''
    );
    if (typeof raw !== 'string' || raw.length === 0) {
      return undefined;
    }
    return this.load(raw);
  }

  async clear(uploadSessionId: string): Promise<void> {
    await this.ensureReady();
    if (!this.pref || uploadSessionId.length === 0) {
      return;
    }
    const existing = await this.load(uploadSessionId);
    await this.pref.delete(PreferencesMedicalDocumentUploadCheckpointStore.sessionKey(uploadSessionId));
    if (existing) {
      await this.pref.delete(PreferencesMedicalDocumentUploadCheckpointStore.latestKey(
        existing.accountId,
        existing.memberId
      ));
    }
    await this.pref.flush();
  }

  /** 登出/切号时清理该账号上传断点，避免源文件 metadata 在本地跨会话留存。 */
  async clearForAccount(accountId: number): Promise<void> {
    await this.ensureReady();
    if (!this.pref || accountId <= 0) {
      return;
    }
    const indexKey = PreferencesMedicalDocumentUploadCheckpointStore.accountIndexKey(accountId);
    const raw = await this.pref.get(indexKey, '');
    if (typeof raw === 'string' && raw.length > 0) {
      const keys = PreferencesMedicalDocumentUploadCheckpointStore.decodeStringArray(raw);
      for (let i = 0; i < keys.length; i++) {
        await this.pref.delete(keys[i]);
      }
    }
    await this.pref.delete(indexKey);
    await this.pref.flush();
  }

  private async ensureReady(): Promise<void> {
    await this.ready;
  }

  private async addAccountIndex(accountId: number, sessionKey: string, latestKey: string): Promise<void> {
    if (!this.pref || accountId <= 0) {
      return;
    }
    const indexKey = PreferencesMedicalDocumentUploadCheckpointStore.accountIndexKey(accountId);
    const raw = await this.pref.get(indexKey, '');
    const keys = typeof raw === 'string' && raw.length > 0 ?
      PreferencesMedicalDocumentUploadCheckpointStore.decodeStringArray(raw) : [];
    PreferencesMedicalDocumentUploadCheckpointStore.pushUnique(keys, sessionKey);
    PreferencesMedicalDocumentUploadCheckpointStore.pushUnique(keys, latestKey);
    await this.pref.put(indexKey, JSON.stringify(keys));
  }

  private static pushUnique(items: string[], value: string): void {
    if (items.indexOf(value) < 0) {
      items.push(value);
    }
  }

  private static sessionKey(uploadSessionId: string): string {
    return `${SESSION_PREFIX}${uploadSessionId}`;
  }

  private static latestKey(accountId: number, memberId: number): string {
    return `${LATEST_PREFIX}${accountId}_${memberId}`;
  }

  private static accountIndexKey(accountId: number): string {
    return `${ACCOUNT_INDEX_PREFIX}${accountId}`;
  }

  private static toJson(snapshot: MedicalDocumentUploadCheckpoint): string {
    const out = new PersistedMedicalDocumentUploadCheckpoint();
    out.uploadSessionId = snapshot.uploadSessionId;
    out.accountId = snapshot.accountId;
    out.memberId = snapshot.memberId;
    out.source = snapshot.source;
    out.selectedFiles = snapshot.selectedFiles.map(
        PreferencesMedicalDocumentUploadCheckpointStore.fileToPlain
      );
    out.uploadedFiles = snapshot.uploadedFiles.map(
        PreferencesMedicalDocumentUploadCheckpointStore.fileToPlain
      );
    out.stage = snapshot.stage;
    out.updatedAt = snapshot.updatedAt;
    out.selectedKind = snapshot.selectedKind;
    out.pipelineOCRText = snapshot.pipelineOCRText;
    out.typeResolutionJSON = snapshot.typeResolutionJSON;
    out.extractedJSON = snapshot.extractedJSON;
    out.failedStep = snapshot.failedStep;
    return JSON.stringify(out);
  }

  private static fromJson(raw: string): MedicalDocumentUploadCheckpoint | undefined {
    try {
      const obj = JSON.parse(raw) as Record<string, Object | string | number>;
      const out = new MedicalDocumentUploadCheckpoint();
      out.uploadSessionId = `${obj['uploadSessionId'] ?? ''}`;
      out.accountId = PreferencesMedicalDocumentUploadCheckpointStore.num(obj['accountId']);
      out.memberId = PreferencesMedicalDocumentUploadCheckpointStore.num(obj['memberId']);
      out.source = PreferencesMedicalDocumentUploadCheckpointStore.source(`${obj['source'] ?? ''}`);
      out.stage = PreferencesMedicalDocumentUploadCheckpointStore.stage(`${obj['stage'] ?? ''}`);
      out.updatedAt = `${obj['updatedAt'] ?? ''}`;
      out.selectedFiles = PreferencesMedicalDocumentUploadCheckpointStore.files(obj['selectedFiles']);
      out.uploadedFiles = PreferencesMedicalDocumentUploadCheckpointStore.files(obj['uploadedFiles']);
      out.selectedKind = `${obj['selectedKind'] ?? ''}`;
      out.pipelineOCRText = `${obj['pipelineOCRText'] ?? ''}`;
      out.typeResolutionJSON = `${obj['typeResolutionJSON'] ?? ''}`;
      out.extractedJSON = `${obj['extractedJSON'] ?? ''}`;
      out.failedStep = `${obj['failedStep'] ?? ''}`;
      return out.uploadSessionId.length > 0 ? out : undefined;
    } catch (_e) {
      return undefined;
    }
  }

  private static fileToPlain(file: MedicalCheckpointFileSnapshot): PersistedMedicalCheckpointFile {
    const out = new PersistedMedicalCheckpointFile();
    out.localId = file.localId;
    out.uri = file.uri;
    out.displayName = file.displayName;
    out.mimeType = file.mimeType;
    out.remoteFileId = file.remoteFileId;
    out.fileUuid = file.fileUuid;
    out.objectKey = file.objectKey;
    out.filePath = file.filePath;
    out.fileSize = file.fileSize;
    out.fileMd5 = file.fileMd5;
    out.ocrText = file.ocrText;
    return out;
  }

  private static files(raw: Object | string | number | undefined): MedicalCheckpointFileSnapshot[] {
    const arr = raw as Object[];
    if (!Array.isArray(arr)) {
      return [];
    }
    return arr.map((item: Object): MedicalCheckpointFileSnapshot =>
      PreferencesMedicalDocumentUploadCheckpointStore.fileFromObject(item)
    );
  }

  private static fileFromObject(raw: Object): MedicalCheckpointFileSnapshot {
    const obj = raw as Record<string, Object | string | number>;
    const file = new MedicalCheckpointFileSnapshot();
    file.localId = `${obj['localId'] ?? ''}`;
    file.uri = `${obj['uri'] ?? ''}`;
    file.displayName = `${obj['displayName'] ?? ''}`;
    file.mimeType = `${obj['mimeType'] ?? ''}`;
    file.remoteFileId = PreferencesMedicalDocumentUploadCheckpointStore.num(obj['remoteFileId']);
    file.fileUuid = `${obj['fileUuid'] ?? ''}`;
    file.objectKey = `${obj['objectKey'] ?? ''}`;
    file.filePath = `${obj['filePath'] ?? ''}`;
    file.fileSize = PreferencesMedicalDocumentUploadCheckpointStore.num(obj['fileSize']);
    file.fileMd5 = `${obj['fileMd5'] ?? ''}`;
    file.ocrText = `${obj['ocrText'] ?? ''}`;
    return file;
  }

  private static num(raw: Object | string | number | undefined): number {
    if (typeof raw === 'number' && Number.isFinite(raw)) {
      return raw;
    }
    const parsed = Number(raw ?? 0);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private static source(raw: string): MedicalDocumentUploadEntrySource {
    switch (raw) {
      case MedicalDocumentUploadEntrySource.SECOND_CAMERA:
        return MedicalDocumentUploadEntrySource.SECOND_CAMERA;
      case MedicalDocumentUploadEntrySource.CHAT:
        return MedicalDocumentUploadEntrySource.CHAT;
      case MedicalDocumentUploadEntrySource.EXTERNAL_PDF:
        return MedicalDocumentUploadEntrySource.EXTERNAL_PDF;
      default:
        return MedicalDocumentUploadEntrySource.HOME;
    }
  }

  private static stage(raw: string): MedicalDocumentUploadCheckpointStage {
    switch (raw) {
      case 'uploading':
        return 'uploading';
      case 'uploaded':
        return 'uploaded';
      case 'ocr_pending':
        return 'ocr_pending';
      case 'ocr_done':
        return 'ocr_done';
      case 'type_resolved':
        return 'type_resolved';
      case 'extracted':
        return 'extracted';
      default:
        return 'picking';
    }
  }

  private static decodeStringArray(raw: string): string[] {
    try {
      const arr = JSON.parse(raw) as string[];
      return Array.isArray(arr) ? arr.filter((item: string): boolean => item.length > 0) : [];
    } catch (_e) {
      return [];
    }
  }
}

/**
 * 内存断点仓库：单测与无 Preferences 场景默认实现。
 * 不持久化跨进程；正式环境由 Preferences 实现替换。
 */
export class InMemoryMedicalDocumentUploadCheckpointStore implements MedicalDocumentUploadCheckpointStore {
  private readonly bySession: Map<string, MedicalDocumentUploadCheckpoint> = new Map();
  private readonly latestKeyToSession: Map<string, string> = new Map();

  async save(snapshot: MedicalDocumentUploadCheckpoint): Promise<void> {
    const copy = InMemoryMedicalDocumentUploadCheckpointStore.clone(snapshot);
    this.bySession.set(copy.uploadSessionId, copy);
    const latestKey = `${copy.accountId}:${copy.memberId}`;
    this.latestKeyToSession.set(latestKey, copy.uploadSessionId);
  }

  async load(uploadSessionId: string): Promise<MedicalDocumentUploadCheckpoint | undefined> {
    const found = this.bySession.get(uploadSessionId);
    return found ? InMemoryMedicalDocumentUploadCheckpointStore.clone(found) : undefined;
  }

  async loadLatest(accountId: number, memberId: number): Promise<MedicalDocumentUploadCheckpoint | undefined> {
    const sessionId = this.latestKeyToSession.get(`${accountId}:${memberId}`);
    if (!sessionId) {
      return undefined;
    }
    return this.load(sessionId);
  }

  async clear(uploadSessionId: string): Promise<void> {
    const existing = this.bySession.get(uploadSessionId);
    this.bySession.delete(uploadSessionId);
    if (existing) {
      const latestKey = `${existing.accountId}:${existing.memberId}`;
      if (this.latestKeyToSession.get(latestKey) === uploadSessionId) {
        this.latestKeyToSession.delete(latestKey);
      }
    }
  }

  private static clone(src: MedicalDocumentUploadCheckpoint): MedicalDocumentUploadCheckpoint {
    const out = new MedicalDocumentUploadCheckpoint();
    out.uploadSessionId = src.uploadSessionId;
    out.accountId = src.accountId;
    out.memberId = src.memberId;
    out.source = src.source;
    out.stage = src.stage;
    out.updatedAt = src.updatedAt;
    out.selectedKind = src.selectedKind;
    out.pipelineOCRText = src.pipelineOCRText;
    out.typeResolutionJSON = src.typeResolutionJSON;
    out.extractedJSON = src.extractedJSON;
    out.failedStep = src.failedStep;
    out.selectedFiles = src.selectedFiles.map(
      (f: MedicalCheckpointFileSnapshot): MedicalCheckpointFileSnapshot => {
        const c = new MedicalCheckpointFileSnapshot();
        c.localId = f.localId;
        c.uri = f.uri;
        c.displayName = f.displayName;
        c.mimeType = f.mimeType;
        c.remoteFileId = f.remoteFileId;
        c.fileUuid = f.fileUuid;
        c.objectKey = f.objectKey;
        c.filePath = f.filePath;
        c.fileSize = f.fileSize;
        c.fileMd5 = f.fileMd5;
        c.ocrText = f.ocrText;
        return c;
      }
    );
    out.uploadedFiles = src.uploadedFiles.map(
      (f: MedicalCheckpointFileSnapshot): MedicalCheckpointFileSnapshot => {
        const c = new MedicalCheckpointFileSnapshot();
        c.localId = f.localId;
        c.uri = f.uri;
        c.displayName = f.displayName;
        c.mimeType = f.mimeType;
        c.remoteFileId = f.remoteFileId;
        c.fileUuid = f.fileUuid;
        c.objectKey = f.objectKey;
        c.filePath = f.filePath;
        c.fileSize = f.fileSize;
        c.fileMd5 = f.fileMd5;
        c.ocrText = f.ocrText;
        return c;
      }
    );
    return out;
  }
}

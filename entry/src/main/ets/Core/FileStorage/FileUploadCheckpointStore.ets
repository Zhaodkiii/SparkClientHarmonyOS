import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { FileHashUtil } from './FileHashUtil';
import {
  MultipartCheckpointStatus,
  MultipartPartRecord,
  MultipartPartStatus,
  MultipartUploadCheckpoint
} from './MultipartUploadModels';

const PREF_NAME: string = 'oss_multipart_upload_checkpoints';
const CP_PREFIX: string = 'cp_';
const ACCOUNT_INDEX_PREFIX: string = 'acct_';
const PENDING_ABORT_KEY: string = 'pending_abort_index';

class PersistedMultipartPart {
  partNumber: number = 0;
  offset: number = 0;
  length: number = 0;
  attempt: number = 0;
  etagHash: string = '';
  etag: string = '';
  status: string = 'pending';
  lastErrorCode: string = '';
  lastRequestId: string = '';
  completedAt: number = 0;
}

class PersistedMultipartCheckpoint {
  checkpointVersion: string = 'v1';
  uploadId: string = '';
  uploadIdHash: string = '';
  bucketFp: string = '';
  objectKey: string = '';
  objectKeyFp: string = '';
  fileUuid: string = '';
  localPath: string = '';
  fileSize: number = 0;
  fileMd5: string = '';
  mimeType: string = '';
  partSize: number = 0;
  totalParts: number = 0;
  accountId: number = 0;
  generation: number = 0;
  createdAt: number = 0;
  updatedAt: number = 0;
  status: string = 'initiated';
  policyVersion: string = '';
  parts: PersistedMultipartPart[] = [];
  pendingAbort: boolean = false;
  abortReason: string = '';
}

export interface FileUploadCheckpointStore {
  save(checkpoint: MultipartUploadCheckpoint): Promise<void>;
  load(fileUuid: string, accountId: number): Promise<MultipartUploadCheckpoint | undefined>;
  remove(fileUuid: string, accountId: number): Promise<void>;
  listPendingAbort(accountId: number): Promise<MultipartUploadCheckpoint[]>;
  clearAccount(accountId: number): Promise<void>;
}

/**
 * Preferences 分片断点仓库。
 * 可存 uploadId（恢复必需）；禁止存 STS/Token。日志层不得输出 uploadId/ETag 原文。
 */
export class PreferencesFileUploadCheckpointStore implements FileUploadCheckpointStore {
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

  async save(checkpoint: MultipartUploadCheckpoint): Promise<void> {
    await this.ensureReady();
    if (!this.pref || checkpoint.fileUuid.length === 0 || checkpoint.accountId <= 0) {
      return;
    }
    checkpoint.updatedAt = Date.now();
    const key = PreferencesFileUploadCheckpointStore.cpKey(checkpoint.accountId, checkpoint.fileUuid);
    await this.pref.put(key, PreferencesFileUploadCheckpointStore.toJson(checkpoint));
    await this.addAccountIndex(checkpoint.accountId, key);
    if (checkpoint.pendingAbort || checkpoint.status === 'pending_abort') {
      await this.addPendingAbort(key);
    } else {
      await this.removePendingAbort(key);
    }
    await this.pref.flush();
  }

  async load(fileUuid: string, accountId: number): Promise<MultipartUploadCheckpoint | undefined> {
    await this.ensureReady();
    if (!this.pref || fileUuid.length === 0 || accountId <= 0) {
      return undefined;
    }
    const raw = await this.pref.get(PreferencesFileUploadCheckpointStore.cpKey(accountId, fileUuid), '');
    if (typeof raw !== 'string' || raw.length === 0) {
      return undefined;
    }
    return PreferencesFileUploadCheckpointStore.fromJson(raw);
  }

  async remove(fileUuid: string, accountId: number): Promise<void> {
    await this.ensureReady();
    if (!this.pref || fileUuid.length === 0 || accountId <= 0) {
      return;
    }
    const key = PreferencesFileUploadCheckpointStore.cpKey(accountId, fileUuid);
    await this.pref.delete(key);
    await this.removeAccountIndex(accountId, key);
    await this.removePendingAbort(key);
    await this.pref.flush();
  }

  async listPendingAbort(accountId: number): Promise<MultipartUploadCheckpoint[]> {
    await this.ensureReady();
    const out: MultipartUploadCheckpoint[] = [];
    if (!this.pref) {
      return out;
    }
    const raw = await this.pref.get(PENDING_ABORT_KEY, '[]');
    if (typeof raw !== 'string' || raw.length === 0) {
      return out;
    }
    let keys: string[] = [];
    try {
      keys = JSON.parse(raw) as string[];
    } catch (_e) {
      return out;
    }
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      const json = await this.pref.get(k, '');
      if (typeof json !== 'string' || json.length === 0) {
        continue;
      }
      const cp = PreferencesFileUploadCheckpointStore.fromJson(json);
      if (cp && (accountId <= 0 || cp.accountId === accountId)) {
        out.push(cp);
      }
    }
    return out;
  }

  async clearAccount(accountId: number): Promise<void> {
    await this.ensureReady();
    if (!this.pref || accountId <= 0) {
      return;
    }
    const indexKey = `${ACCOUNT_INDEX_PREFIX}${accountId}`;
    const raw = await this.pref.get(indexKey, '[]');
    let keys: string[] = [];
    if (typeof raw === 'string' && raw.length > 0) {
      try {
        keys = JSON.parse(raw) as string[];
      } catch (_e) {
        keys = [];
      }
    }
    for (let i = 0; i < keys.length; i++) {
      await this.pref.delete(keys[i]);
      await this.removePendingAbort(keys[i]);
    }
    await this.pref.delete(indexKey);
    await this.pref.flush();
  }

  static uploadIdHash(uploadId: string): string {
    if (uploadId.length === 0) {
      return 'empty';
    }
    return FileHashUtil.sha256HexOfString(uploadId).substring(0, 16);
  }

  static etagHash(etag: string): string {
    if (etag.length === 0) {
      return '';
    }
    return FileHashUtil.sha256HexOfString(etag).substring(0, 12);
  }

  private async ensureReady(): Promise<void> {
    await this.ready;
  }

  private async addAccountIndex(accountId: number, key: string): Promise<void> {
    if (!this.pref) {
      return;
    }
    const indexKey = `${ACCOUNT_INDEX_PREFIX}${accountId}`;
    const raw = await this.pref.get(indexKey, '[]');
    let keys: string[] = [];
    if (typeof raw === 'string' && raw.length > 0) {
      try {
        keys = JSON.parse(raw) as string[];
      } catch (_e) {
        keys = [];
      }
    }
    if (keys.indexOf(key) < 0) {
      keys.push(key);
      await this.pref.put(indexKey, JSON.stringify(keys));
    }
  }

  private async removeAccountIndex(accountId: number, key: string): Promise<void> {
    if (!this.pref) {
      return;
    }
    const indexKey = `${ACCOUNT_INDEX_PREFIX}${accountId}`;
    const raw = await this.pref.get(indexKey, '[]');
    let keys: string[] = [];
    if (typeof raw === 'string' && raw.length > 0) {
      try {
        keys = JSON.parse(raw) as string[];
      } catch (_e) {
        keys = [];
      }
    }
    const next: string[] = [];
    for (let i = 0; i < keys.length; i++) {
      if (keys[i] !== key) {
        next.push(keys[i]);
      }
    }
    await this.pref.put(indexKey, JSON.stringify(next));
  }

  private async addPendingAbort(key: string): Promise<void> {
    if (!this.pref) {
      return;
    }
    const raw = await this.pref.get(PENDING_ABORT_KEY, '[]');
    let keys: string[] = [];
    if (typeof raw === 'string' && raw.length > 0) {
      try {
        keys = JSON.parse(raw) as string[];
      } catch (_e) {
        keys = [];
      }
    }
    if (keys.indexOf(key) < 0) {
      keys.push(key);
      await this.pref.put(PENDING_ABORT_KEY, JSON.stringify(keys));
    }
  }

  private async removePendingAbort(key: string): Promise<void> {
    if (!this.pref) {
      return;
    }
    const raw = await this.pref.get(PENDING_ABORT_KEY, '[]');
    let keys: string[] = [];
    if (typeof raw === 'string' && raw.length > 0) {
      try {
        keys = JSON.parse(raw) as string[];
      } catch (_e) {
        keys = [];
      }
    }
    const next: string[] = [];
    for (let i = 0; i < keys.length; i++) {
      if (keys[i] !== key) {
        next.push(keys[i]);
      }
    }
    await this.pref.put(PENDING_ABORT_KEY, JSON.stringify(next));
  }

  private static cpKey(accountId: number, fileUuid: string): string {
    return `${CP_PREFIX}${accountId}_${fileUuid}`;
  }

  private static toJson(cp: MultipartUploadCheckpoint): string {
    const persisted = new PersistedMultipartCheckpoint();
    persisted.checkpointVersion = cp.checkpointVersion;
    persisted.uploadId = cp.uploadId;
    persisted.uploadIdHash = cp.uploadIdHash;
    persisted.bucketFp = cp.bucketFp;
    persisted.objectKey = cp.objectKey;
    persisted.objectKeyFp = cp.objectKeyFp;
    persisted.fileUuid = cp.fileUuid;
    persisted.localPath = cp.localPath;
    persisted.fileSize = cp.fileSize;
    persisted.fileMd5 = cp.fileMd5;
    persisted.mimeType = cp.mimeType;
    persisted.partSize = cp.partSize;
    persisted.totalParts = cp.totalParts;
    persisted.accountId = cp.accountId;
    persisted.generation = cp.generation;
    persisted.createdAt = cp.createdAt;
    persisted.updatedAt = cp.updatedAt;
    persisted.status = cp.status;
    persisted.policyVersion = cp.policyVersion;
    persisted.pendingAbort = cp.pendingAbort;
    persisted.abortReason = cp.abortReason;
    const parts: PersistedMultipartPart[] = [];
    for (let i = 0; i < cp.parts.length; i++) {
      const p = cp.parts[i];
      const pp = new PersistedMultipartPart();
      pp.partNumber = p.partNumber;
      pp.offset = p.offset;
      pp.length = p.length;
      pp.attempt = p.attempt;
      pp.etagHash = p.etagHash;
      pp.etag = p.etag;
      pp.status = p.status;
      pp.lastErrorCode = p.lastErrorCode;
      pp.lastRequestId = p.lastRequestId;
      pp.completedAt = p.completedAt;
      parts.push(pp);
    }
    persisted.parts = parts;
    return JSON.stringify(persisted);
  }

  private static fromJson(raw: string): MultipartUploadCheckpoint | undefined {
    try {
      const obj = JSON.parse(raw) as Record<string, Object | string | number | boolean>;
      const cp = new MultipartUploadCheckpoint();
      cp.checkpointVersion = `${obj['checkpointVersion'] ?? 'v1'}`;
      cp.uploadId = `${obj['uploadId'] ?? ''}`;
      cp.uploadIdHash = `${obj['uploadIdHash'] ?? ''}`;
      cp.bucketFp = `${obj['bucketFp'] ?? ''}`;
      cp.objectKey = `${obj['objectKey'] ?? ''}`;
      cp.objectKeyFp = `${obj['objectKeyFp'] ?? ''}`;
      cp.fileUuid = `${obj['fileUuid'] ?? ''}`;
      cp.localPath = `${obj['localPath'] ?? ''}`;
      cp.fileSize = Number(obj['fileSize'] ?? 0);
      cp.fileMd5 = `${obj['fileMd5'] ?? ''}`;
      cp.mimeType = `${obj['mimeType'] ?? ''}`;
      cp.partSize = Number(obj['partSize'] ?? 0);
      cp.totalParts = Number(obj['totalParts'] ?? 0);
      cp.accountId = Number(obj['accountId'] ?? 0);
      cp.generation = Number(obj['generation'] ?? 0);
      cp.createdAt = Number(obj['createdAt'] ?? 0);
      cp.updatedAt = Number(obj['updatedAt'] ?? 0);
      cp.status = `${obj['status'] ?? 'initiated'}` as MultipartCheckpointStatus;
      cp.policyVersion = `${obj['policyVersion'] ?? ''}`;
      cp.pendingAbort = obj['pendingAbort'] === true;
      cp.abortReason = `${obj['abortReason'] ?? ''}`;
      const partsRaw = obj['parts'];
      if (partsRaw instanceof Array) {
        for (let i = 0; i < partsRaw.length; i++) {
          const pr = partsRaw[i] as Record<string, Object | string | number>;
          const part = new MultipartPartRecord();
          part.partNumber = Number(pr['partNumber'] ?? 0);
          part.offset = Number(pr['offset'] ?? 0);
          part.length = Number(pr['length'] ?? 0);
          part.attempt = Number(pr['attempt'] ?? 0);
          part.etagHash = `${pr['etagHash'] ?? ''}`;
          part.etag = `${pr['etag'] ?? ''}`;
          part.status = `${pr['status'] ?? 'pending'}` as MultipartPartStatus;
          part.lastErrorCode = `${pr['lastErrorCode'] ?? ''}`;
          part.lastRequestId = `${pr['lastRequestId'] ?? ''}`;
          part.completedAt = Number(pr['completedAt'] ?? 0);
          cp.parts.push(part);
        }
      }
      return cp;
    } catch (_e) {
      return undefined;
    }
  }
}

/** 无 Context 时的内存实现（单测 / 退化）。 */
export class InMemoryFileUploadCheckpointStore implements FileUploadCheckpointStore {
  private readonly entries: MultipartUploadCheckpoint[] = [];

  async save(checkpoint: MultipartUploadCheckpoint): Promise<void> {
    checkpoint.updatedAt = Date.now();
    const keyAccount = checkpoint.accountId;
    const keyUuid = checkpoint.fileUuid;
    for (let i = 0; i < this.entries.length; i++) {
      if (this.entries[i].accountId === keyAccount && this.entries[i].fileUuid === keyUuid) {
        this.entries[i] = checkpoint;
        return;
      }
    }
    this.entries.push(checkpoint);
  }

  async load(fileUuid: string, accountId: number): Promise<MultipartUploadCheckpoint | undefined> {
    for (let i = 0; i < this.entries.length; i++) {
      if (this.entries[i].accountId === accountId && this.entries[i].fileUuid === fileUuid) {
        return this.entries[i];
      }
    }
    return undefined;
  }

  async remove(fileUuid: string, accountId: number): Promise<void> {
    const next: MultipartUploadCheckpoint[] = [];
    for (let i = 0; i < this.entries.length; i++) {
      if (!(this.entries[i].accountId === accountId && this.entries[i].fileUuid === fileUuid)) {
        next.push(this.entries[i]);
      }
    }
    this.entries.length = 0;
    for (let i = 0; i < next.length; i++) {
      this.entries.push(next[i]);
    }
  }

  async listPendingAbort(accountId: number): Promise<MultipartUploadCheckpoint[]> {
    const out: MultipartUploadCheckpoint[] = [];
    for (let i = 0; i < this.entries.length; i++) {
      const cp = this.entries[i];
      if (cp.pendingAbort && (accountId <= 0 || cp.accountId === accountId)) {
        out.push(cp);
      }
    }
    return out;
  }

  async clearAccount(accountId: number): Promise<void> {
    const next: MultipartUploadCheckpoint[] = [];
    for (let i = 0; i < this.entries.length; i++) {
      if (this.entries[i].accountId !== accountId) {
        next.push(this.entries[i]);
      }
    }
    this.entries.length = 0;
    for (let i = 0; i < next.length; i++) {
      this.entries.push(next[i]);
    }
  }
}

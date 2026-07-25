import { fileIo as fs } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { FileCacheRepository } from './FileCacheRepository';
import { FileHashUtil } from './FileHashUtil';
import {
  CancelToken,
  DownloadProgressEvent,
  DownloadProgressListener,
  FileCacheRecord,
  FileCacheState,
  FileTransferError,
  LocalFileHandle,
  ManagedFileRecord,
  StagedUploadFile
} from './FileStorageModels';
import { Logger } from '../../Foundation/Logging/Logger';
import { LogModule } from '../../Foundation/Logging/LogModule';

const COPY_CHUNK: number = 256 * 1024;

/**
 * 私有目录、.part、MD5、原子 rename、账号清理。
 * 不发送业务 API、不决定业务归属；下载仅消费已签发的 URL。
 */
export class FileCacheManager {
  private readonly filesDir: string;
  private readonly repository: FileCacheRepository;
  private readonly rootName: string = 'SparkClient.FileCache';

  constructor(filesDir: string, repository: FileCacheRepository) {
    this.filesDir = filesDir;
    this.repository = repository;
    FileCacheManager.ensureDir(`${filesDir}/${this.rootName}`);
  }

  accountRoot(accountId: number): string {
    const hash = FileHashUtil.accountIdHash(accountId);
    return `${this.filesDir}/${this.rootName}/${hash}`;
  }

  fileDir(accountId: number, fileUuid: string): string {
    return `${this.accountRoot(accountId)}/${fileUuid.toLowerCase()}`;
  }

  async stageUpload(
    accountId: number,
    sourceUri: string,
    originalName: string,
    fileUuid: string,
    cancelToken?: CancelToken
  ): Promise<StagedUploadFile> {
    const safeName = FileHashUtil.sanitizeFileName(originalName);
    const dir = this.fileDir(accountId, fileUuid);
    FileCacheManager.ensureDir(dir);
    const finalPath = `${dir}/${safeName}`;
    this.assertUnderAccountRoot(accountId, finalPath);
    const partPath = `${finalPath}.part`;
    try {
      await this.copyUriToPath(sourceUri, partPath, cancelToken);
      cancelToken?.throwIfCancelled('preparing');
      const stat = fs.statSync(partPath);
      const md5 = await FileHashUtil.md5HexOfFile(partPath);
      this.atomicRename(partPath, finalPath);
      const staged = new StagedUploadFile();
      staged.fileUuid = fileUuid;
      staged.localPath = finalPath;
      staged.originalName = safeName;
      staged.fileSize = stat.size;
      staged.fileMd5 = md5;
      staged.mimeType = FileHashUtil.mimeTypeForName(safeName);
      const rec = new FileCacheRecord();
      rec.accountIdHash = FileHashUtil.accountIdHash(accountId);
      rec.fileId = 0;
      rec.fileUuid = fileUuid;
      rec.localPath = finalPath;
      rec.originalName = safeName;
      rec.fileSize = staged.fileSize;
      rec.fileMd5 = md5;
      rec.mimeType = staged.mimeType;
      rec.state = 'staging';
      rec.createdAt = Date.now();
      rec.updatedAt = Date.now();
      rec.lastAccessedAt = Date.now();
      await this.repository.upsert(rec);
      return staged;
    } catch (err) {
      FileCacheManager.safeUnlink(partPath);
      if (err instanceof FileTransferError) {
        throw err;
      }
      throw new FileTransferError('localIoFailed', 'preparing', '无法读取或缓存文件', true);
    }
  }

  /**
   * 登记恢复所需：把业务归属写回 staging / uploaded_unregistered 行。
   */
  async attachUploadContext(
    accountId: number,
    fileUuid: string,
    mimeType: string,
    businessType: string,
    businessId: string,
    isPublic: boolean
  ): Promise<void> {
    const hash = FileHashUtil.accountIdHash(accountId);
    const existing = await this.repository.find(hash, fileUuid);
    if (!existing) {
      return;
    }
    existing.mimeType = mimeType.length > 0 ? mimeType : existing.mimeType;
    existing.businessType = businessType;
    existing.businessId = businessId;
    existing.isPublic = isPublic;
    existing.updatedAt = Date.now();
    await this.repository.upsert(existing);
  }

  async lookupReady(accountId: number, fileUuid: string, expectedMd5: string = ''): Promise<LocalFileHandle | undefined> {
    const hash = FileHashUtil.accountIdHash(accountId);
    const rec = await this.repository.find(hash, fileUuid);
    if (!rec || rec.state !== 'ready') {
      return undefined;
    }
    if (!this.pathExists(rec.localPath)) {
      await this.repository.delete(hash, fileUuid);
      return undefined;
    }
    try {
      const stat = fs.statSync(rec.localPath);
      if (stat.size !== rec.fileSize && rec.fileSize > 0) {
        await this.remove(accountId, fileUuid);
        return undefined;
      }
      if (expectedMd5.length > 0) {
        const actual = await FileHashUtil.md5HexOfFile(rec.localPath);
        if (actual !== expectedMd5.toLowerCase()) {
          await this.remove(accountId, fileUuid);
          return undefined;
        }
      } else if (rec.fileMd5.length > 0) {
        const actual = await FileHashUtil.md5HexOfFile(rec.localPath);
        if (actual !== rec.fileMd5.toLowerCase()) {
          await this.remove(accountId, fileUuid);
          return undefined;
        }
      }
      await this.repository.touchAccess(hash, fileUuid);
      const handle = new LocalFileHandle();
      handle.fileUuid = fileUuid;
      handle.localPath = rec.localPath;
      handle.originalName = rec.originalName;
      handle.fileSize = rec.fileSize;
      handle.fileMd5 = rec.fileMd5;
      handle.remoteFileId = rec.fileId;
      return handle;
    } catch (_e) {
      await this.remove(accountId, fileUuid);
      return undefined;
    }
  }

  async findCacheRecord(accountId: number, fileUuid: string): Promise<FileCacheRecord | undefined> {
    return this.repository.find(FileHashUtil.accountIdHash(accountId), fileUuid);
  }

  async findByFileId(accountId: number, fileId: number): Promise<FileCacheRecord | undefined> {
    return this.repository.findByFileId(FileHashUtil.accountIdHash(accountId), fileId);
  }

  async listByState(accountId: number, state: FileCacheState): Promise<FileCacheRecord[]> {
    return this.repository.listByState(FileHashUtil.accountIdHash(accountId), state);
  }

  async markState(accountId: number, fileUuid: string, state: FileCacheState): Promise<void> {
    await this.repository.markState(FileHashUtil.accountIdHash(accountId), fileUuid, state);
  }

  async commitDownload(
    accountId: number,
    record: ManagedFileRecord,
    downloadUrl: string,
    cancelToken?: CancelToken,
    onProgress?: DownloadProgressListener
  ): Promise<LocalFileHandle> {
    const safeName = FileHashUtil.sanitizeFileName(record.originalName);
    const dir = this.fileDir(accountId, record.fileUuid);
    FileCacheManager.ensureDir(dir);
    const finalPath = `${dir}/${safeName}`;
    this.assertUnderAccountRoot(accountId, finalPath);
    const partPath = `${finalPath}.part`;
    const hash = FileHashUtil.accountIdHash(accountId);
    const meta = new FileCacheRecord();
    meta.accountIdHash = hash;
    meta.fileId = record.id;
    meta.fileUuid = record.fileUuid;
    meta.localPath = finalPath;
    meta.originalName = safeName;
    meta.fileSize = record.fileSize;
    meta.fileMd5 = record.fileMd5;
    meta.objectKey = record.objectKey;
    meta.mimeType = record.mimeType.length > 0 ? record.mimeType : FileHashUtil.mimeTypeForName(safeName);
    meta.businessType = record.businessType;
    meta.businessId = record.businessId;
    meta.isPublic = record.isPublic;
    meta.state = 'downloading';
    meta.createdAt = Date.now();
    meta.updatedAt = Date.now();
    meta.lastAccessedAt = Date.now();
    await this.repository.upsert(meta);
    try {
      await this.downloadUrlToPart(downloadUrl, partPath, cancelToken, onProgress);
      cancelToken?.throwIfCancelled('downloading');
      const stat = fs.statSync(partPath);
      if (record.fileSize > 0 && stat.size !== record.fileSize) {
        FileCacheManager.safeUnlink(partPath);
        throw new FileTransferError('integrityMismatch', 'downloading', '下载大小不一致', true);
      }
      const md5 = await FileHashUtil.md5HexOfFile(partPath);
      if (record.fileMd5.length > 0 && md5 !== record.fileMd5.toLowerCase()) {
        FileCacheManager.safeUnlink(partPath);
        throw new FileTransferError('integrityMismatch', 'downloading', '下载校验失败', true);
      }
      this.atomicRename(partPath, finalPath);
      meta.fileSize = stat.size;
      meta.fileMd5 = md5;
      meta.state = 'ready';
      meta.updatedAt = Date.now();
      meta.lastAccessedAt = Date.now();
      await this.repository.upsert(meta);
      const handle = new LocalFileHandle();
      handle.fileUuid = record.fileUuid;
      handle.localPath = finalPath;
      handle.originalName = safeName;
      handle.fileSize = stat.size;
      handle.fileMd5 = md5;
      handle.remoteFileId = record.id;
      return handle;
    } catch (err) {
      FileCacheManager.safeUnlink(partPath);
      if (err instanceof FileTransferError) {
        if (err.code !== 'cancelled') {
          await this.repository.markState(hash, record.fileUuid, 'failed');
        }
        throw err;
      }
      await this.repository.markState(hash, record.fileUuid, 'failed');
      throw new FileTransferError('localIoFailed', 'downloading', '下载写入失败', true);
    }
  }

  async bindRemoteIdentity(
    accountId: number,
    fileUuid: string,
    record: ManagedFileRecord,
    objectKey: string
  ): Promise<void> {
    const hash = FileHashUtil.accountIdHash(accountId);
    const existing = await this.repository.find(hash, fileUuid);
    const rec = existing ?? new FileCacheRecord();
    rec.accountIdHash = hash;
    rec.fileId = record.id;
    rec.fileUuid = fileUuid;
    if (!existing) {
      rec.localPath = this.fileDir(accountId, fileUuid);
    }
    rec.originalName = FileHashUtil.sanitizeFileName(record.originalName);
    rec.fileSize = record.fileSize;
    rec.fileMd5 = record.fileMd5;
    rec.objectKey = objectKey;
    rec.mimeType = record.mimeType.length > 0 ? record.mimeType : rec.mimeType;
    rec.businessType = record.businessType.length > 0 ? record.businessType : rec.businessType;
    rec.businessId = record.businessId.length > 0 ? record.businessId : rec.businessId;
    rec.isPublic = record.isPublic;
    rec.state = 'ready';
    rec.updatedAt = Date.now();
    rec.lastAccessedAt = Date.now();
    if (rec.createdAt <= 0) {
      rec.createdAt = Date.now();
    }
    await this.repository.upsert(rec);
  }

  async markUploadedUnregistered(
    accountId: number,
    fileUuid: string,
    objectKey: string
  ): Promise<void> {
    const hash = FileHashUtil.accountIdHash(accountId);
    const existing = await this.repository.find(hash, fileUuid);
    if (!existing) {
      return;
    }
    existing.objectKey = objectKey;
    existing.state = 'uploaded_unregistered';
    existing.updatedAt = Date.now();
    await this.repository.upsert(existing);
  }

  async remove(accountId: number, fileUuid: string): Promise<void> {
    const hash = FileHashUtil.accountIdHash(accountId);
    const rec = await this.repository.find(hash, fileUuid);
    if (rec) {
      FileCacheManager.safeUnlink(rec.localPath);
      FileCacheManager.safeUnlink(`${rec.localPath}.part`);
    }
    const dir = this.fileDir(accountId, fileUuid);
    FileCacheManager.safeRemoveDir(dir);
    await this.repository.delete(hash, fileUuid);
  }

  /**
   * 删除不完整的 .part（前后台恢复 / 冷启动）；不碰已提交成品文件。
   */
  removeIncompleteParts(accountId: number): number {
    const root = this.accountRoot(accountId);
    if (!this.pathExists(root)) {
      return 0;
    }
    return FileCacheManager.removePartsUnder(root);
  }

  localFileExists(path: string): boolean {
    return this.pathExists(path);
  }

  async clearAccount(accountId: number): Promise<void> {
    const hash = FileHashUtil.accountIdHash(accountId);
    await this.repository.deleteByAccount(hash);
    FileCacheManager.safeRemoveDir(this.accountRoot(accountId));
    Logger.info('file.cache.account_cleared', LogModule.FILE);
  }

  private assertUnderAccountRoot(accountId: number, path: string): void {
    const root = this.accountRoot(accountId);
    if (!path.startsWith(root + '/') && path !== root) {
      throw new FileTransferError('sourceInvalid', 'preparing', '非法文件路径', false);
    }
  }

  private pathExists(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (_e) {
      return false;
    }
  }

  private async copyUriToPath(sourceUri: string, destPart: string, cancelToken?: CancelToken): Promise<void> {
    FileCacheManager.safeUnlink(destPart);
    let src: fs.File | undefined = undefined;
    let dst: fs.File | undefined = undefined;
    try {
      src = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
      dst = fs.openSync(destPart, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const buffer = new ArrayBuffer(COPY_CHUNK);
      let read = 0;
      do {
        cancelToken?.throwIfCancelled('preparing');
        read = fs.readSync(src.fd, buffer);
        if (read > 0) {
          fs.writeSync(dst.fd, buffer, { length: read });
        }
      } while (read > 0);
    } catch (err) {
      if (err instanceof FileTransferError) {
        throw err;
      }
      throw new FileTransferError('sourceInvalid', 'preparing', '文件不可读取', false);
    } finally {
      if (src !== undefined) {
        try {
          fs.closeSync(src);
        } catch (_e) {
          // ignore
        }
      }
      if (dst !== undefined) {
        try {
          fs.closeSync(dst);
        } catch (_e) {
          // ignore
        }
      }
    }
  }

  /**
   * 流式下载：requestInStream + dataReceive 边收边写 .part；取消/失败删 .part。
   */
  private async downloadUrlToPart(
    url: string,
    partPath: string,
    cancelToken?: CancelToken,
    onProgress?: DownloadProgressListener
  ): Promise<void> {
    FileCacheManager.safeUnlink(partPath);
    cancelToken?.throwIfCancelled('downloading');
    const req = http.createHttp();
    let file: fs.File | undefined = undefined;
    let aborted = false;
    let totalBytes = 0;
    let received = 0;

    try {
      file = fs.openSync(partPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);

      await new Promise<void>((resolve, reject) => {
        const fail = (err: Object): void => {
          if (aborted) {
            return;
          }
          aborted = true;
          reject(err);
          try {
            req.destroy();
          } catch (_e) {
            // ignore
          }
        };

        req.on('headersReceive', (header: Object) => {
          const len = FileCacheManager.readHeaderValue(header, 'content-length');
          if (len.length > 0) {
            const parsed = Number.parseInt(len, 10);
            if (!Number.isNaN(parsed) && parsed > 0) {
              totalBytes = parsed;
            }
          }
        });

        req.on('dataReceiveProgress', (info: http.DataReceiveProgressInfo) => {
          if (aborted) {
            return;
          }
          if (info.totalSize > 0) {
            totalBytes = info.totalSize;
          }
          received = info.receiveSize;
          if (onProgress) {
            const ev = new DownloadProgressEvent();
            ev.bytesReceived = received;
            ev.totalBytes = totalBytes;
            onProgress(ev);
          }
        });

        req.on('dataReceive', (data: ArrayBuffer) => {
          if (aborted) {
            return;
          }
          try {
            cancelToken?.throwIfCancelled('downloading');
            if (file !== undefined) {
              fs.writeSync(file.fd, data);
            }
            received += data.byteLength;
            if (onProgress && totalBytes > 0) {
              const ev = new DownloadProgressEvent();
              ev.bytesReceived = received;
              ev.totalBytes = totalBytes;
              onProgress(ev);
            }
          } catch (err) {
            if (err instanceof FileTransferError) {
              fail(err);
            } else {
              fail(new FileTransferError('localIoFailed', 'downloading', '下载写入失败', true));
            }
          }
        });

        req.requestInStream(url, {
          method: http.RequestMethod.GET,
          connectTimeout: 60000,
          readTimeout: 120000
        }).then((code: number) => {
          if (aborted) {
            return;
          }
          if (code < 200 || code >= 300) {
            if (code === 403 || code === 404) {
              fail(new FileTransferError('fileUnavailable', 'downloading', '文件不可用', false, undefined, code));
            } else {
              fail(new FileTransferError('networkUnavailable', 'downloading', '下载失败', true, undefined, code));
            }
            return;
          }
          resolve();
        }).catch((_err: Object) => {
          if (aborted) {
            return;
          }
          if (cancelToken?.cancelled) {
            fail(new FileTransferError('cancelled', 'downloading', '已取消', true));
          } else {
            fail(new FileTransferError('networkUnavailable', 'downloading', '网络不可用', true));
          }
        });
      });
    } catch (err) {
      FileCacheManager.safeUnlink(partPath);
      if (err instanceof FileTransferError) {
        throw err;
      }
      throw new FileTransferError('networkUnavailable', 'downloading', '网络不可用', true);
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (_e) {
          // ignore
        }
      }
      try {
        req.off('headersReceive');
        req.off('dataReceive');
        req.off('dataReceiveProgress');
        req.destroy();
      } catch (_e) {
        // ignore
      }
    }
  }

  private atomicRename(partPath: string, finalPath: string): void {
    FileCacheManager.safeUnlink(finalPath);
    fs.renameSync(partPath, finalPath);
  }

  private static readHeaderValue(header: Object, key: string): string {
    const lower = key.toLowerCase();
    const map = header as Record<string, string | string[] | undefined>;
    const keys = Object.keys(map);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i].toLowerCase() === lower) {
        const v = map[keys[i]];
        if (typeof v === 'string') {
          return v;
        }
        if (v !== undefined && v.length > 0) {
          return v[0];
        }
      }
    }
    return '';
  }

  private static removePartsUnder(dir: string): number {
    let removed = 0;
    try {
      if (!fs.accessSync(dir)) {
        return 0;
      }
      const entries = fs.listFileSync(dir);
      for (let i = 0; i < entries.length; i++) {
        const name = entries[i];
        const child = `${dir}/${name}`;
        try {
          const st = fs.statSync(child);
          if (st.isDirectory()) {
            removed += FileCacheManager.removePartsUnder(child);
          } else if (name.endsWith('.part')) {
            fs.unlinkSync(child);
            removed += 1;
          }
        } catch (_e) {
          // ignore
        }
      }
    } catch (_e) {
      // ignore
    }
    return removed;
  }

  private static ensureDir(dir: string): void {
    try {
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
    } catch (_e) {
      try {
        fs.mkdirSync(dir, true);
      } catch (__e) {
        // ignore
      }
    }
  }

  private static safeUnlink(path: string): void {
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (_e) {
      // ignore
    }
  }

  private static safeRemoveDir(dir: string): void {
    try {
      if (!fs.accessSync(dir)) {
        return;
      }
      const entries = fs.listFileSync(dir);
      for (let i = 0; i < entries.length; i++) {
        const child = `${dir}/${entries[i]}`;
        try {
          const st = fs.statSync(child);
          if (st.isDirectory()) {
            FileCacheManager.safeRemoveDir(child);
          } else {
            fs.unlinkSync(child);
          }
        } catch (_e) {
          // ignore
        }
      }
      fs.rmdirSync(dir);
    } catch (_e) {
      // ignore
    }
  }
}

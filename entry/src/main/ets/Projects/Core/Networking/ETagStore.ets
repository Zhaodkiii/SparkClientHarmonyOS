import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { ETagCacheRecord, NetworkRequest, NetworkResponse, SupportNetworkError, headerValue } from './SupportNetworkModels';
import { NetworkLogger } from '../../../Foundation/Logging/NetworkLogger';
import { FileHashUtil } from '../../../Core/FileStorage/FileHashUtil';

/**
 * ETag 条件缓存：If-None-Match + 304 本地 body 合并。
 * 与 iOS ETagHTTPInterceptor 对齐；按 accountScope 分目录（鸿蒙增强）。
 */
export class ETagStore {
  private readonly rootDir: string;
  private readonly logger: NetworkLogger;

  constructor(filesDir: string, logger?: NetworkLogger) {
    this.rootDir = `${filesDir}/network-cache`;
    this.logger = logger ?? new NetworkLogger();
    ETagStore.ensureDir(this.rootDir);
  }

  /**
   * 缓存键：对齐 iOS `url|Authorization:…` 指纹后再 SHA-256。
   * authFingerprint 为会话指纹，避免明文 token 写入磁盘键名。
   */
  cacheKey(url: string, authFingerprint: string): string {
    return ETagStore.sha256Hex(`${url}|Authorization:${authFingerprint}`);
  }

  accountDir(accountScope: string): string {
    const safe = accountScope.replace(/[^a-zA-Z0-9._-]/g, '_');
    const dir = `${this.rootDir}/${safe}`;
    ETagStore.ensureDir(dir);
    return dir;
  }

  readMeta(accountScope: string, key: string): ETagCacheRecord | undefined {
    const path = `${this.accountDir(accountScope)}/${key}.meta.json`;
    try {
      if (!fs.accessSync(path)) {
        return undefined;
      }
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      try {
        const stat = fs.statSync(path);
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        const text = ETagStore.abToString(buf);
        const obj = JSON.parse(text) as Record<string, string | number>;
        return new ETagCacheRecord(
          `${obj['etag'] ?? ''}`,
          Number(obj['lastUpdatedMs'] ?? 0),
          obj['expirationMs'] !== undefined ? Number(obj['expirationMs']) : undefined
        );
      } finally {
        fs.closeSync(file);
      }
    } catch (e) {
      this.logger.warn(`ETag meta read failed: ${e}`);
      return undefined;
    }
  }

  readBody(accountScope: string, key: string): string | undefined {
    const path = `${this.accountDir(accountScope)}/${key}.body`;
    try {
      if (!fs.accessSync(path)) {
        return undefined;
      }
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      try {
        const stat = fs.statSync(path);
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        return ETagStore.abToString(buf);
      } finally {
        fs.closeSync(file);
      }
    } catch (e) {
      this.logger.warn(`ETag body read failed: ${e}`);
      return undefined;
    }
  }

  write(accountScope: string, key: string, etag: string, body: string, expirationMs?: number): void {
    const dir = this.accountDir(accountScope);
    const bodyPath = `${dir}/${key}.body`;
    const metaPath = `${dir}/${key}.meta.json`;
    const tmpBody = `${bodyPath}.tmp`;
    const tmpMeta = `${metaPath}.tmp`;
    const meta = new ETagCacheRecord(etag, Date.now(), expirationMs);
    const metaJson = JSON.stringify({
      etag: meta.etag,
      lastUpdatedMs: meta.lastUpdatedMs,
      expirationMs: meta.expirationMs
    });
    ETagStore.writeAtomic(tmpBody, bodyPath, body);
    ETagStore.writeAtomic(tmpMeta, metaPath, metaJson);
  }

  /** 删除单条 ETag 缓存（对齐 iOS removeCache）。 */
  removeCache(accountScope: string, key: string): void {
    const dir = this.accountDir(accountScope);
    const metaPath = `${dir}/${key}.meta.json`;
    const bodyPath = `${dir}/${key}.body`;
    try {
      if (fs.accessSync(metaPath)) {
        fs.unlinkSync(metaPath);
      }
    } catch (_e) {
      // ignore
    }
    try {
      if (fs.accessSync(bodyPath)) {
        fs.unlinkSync(bodyPath);
      }
    } catch (_e) {
      // ignore
    }
  }

  clearAccount(accountScope: string): void {
    const dir = this.accountDir(accountScope);
    try {
      const files = fs.listFileSync(dir);
      for (let i = 0; i < files.length; i++) {
        try {
          fs.unlinkSync(`${dir}/${files[i]}`);
        } catch (_e) {
          // ignore
        }
      }
    } catch (_e) {
      // ignore
    }
  }

  applyIfNoneMatch(
    headers: Record<string, string>,
    accountScope: string,
    key: string,
    request: NetworkRequest
  ): void {
    // 对齐 iOS：有 etagTTL 即上送 X-Cache-Max-Age（不依赖本地命中）
    const ttlMs = request.strategy.etagTtlMs;
    if (ttlMs !== undefined && ttlMs > 0) {
      headers['X-Cache-Max-Age'] = `${Math.floor(ttlMs / 1000)}`;
    }

    const meta = this.readMeta(accountScope, key);
    if (!meta || !meta.etag) {
      return;
    }
    if (meta.isExpired()) {
      this.removeCache(accountScope, key);
      this.logger.debug(`ETag skip stale cache key=${key}`);
      return;
    }
    headers['If-None-Match'] = meta.etag;
  }

  mergeResponse(
    accountScope: string,
    key: string,
    response: NetworkResponse,
    request: NetworkRequest
  ): NetworkResponse {
    if (response.statusCode === 304) {
      const body = this.readBody(accountScope, key);
      if (body === undefined) {
        throw SupportNetworkError.invalidResponse('304 without local body', response.requestId);
      }
      this.logger.etagMerged304(request.path, key, body);
      return new NetworkResponse(200, response.headers, body, true, response.requestId, response.durationMs);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      const etag = headerValue(response.headers, 'ETag') ?? headerValue(response.headers, 'etag');
      if (etag) {
        const expirationMs = ETagStore.resolveExpirationMs(response.headers, request.strategy.etagTtlMs);
        this.write(accountScope, key, etag, response.bodyText, expirationMs);
      }
    }
    return response;
  }

  private static resolveExpirationMs(headers: Record<string, string>, etagTtlMs?: number): number | undefined {
    const cacheControl = headerValue(headers, 'Cache-Control') ?? '';
    if (cacheControl.toLowerCase().indexOf('no-store') >= 0) {
      return Date.now();
    }
    const maxAgeMatch = cacheControl.match(/max-age=(\d+)/i);
    if (maxAgeMatch) {
      return Date.now() + Number(maxAgeMatch[1]) * 1000;
    }
    const expires = headerValue(headers, 'Expires');
    if (expires) {
      const t = Date.parse(expires);
      if (!Number.isNaN(t)) {
        return t;
      }
    }
    if (etagTtlMs !== undefined) {
      return Date.now() + etagTtlMs;
    }
    // 对齐 iOS CachePolicy.defaultTTL = 300s
    return Date.now() + 300000;
  }

  private static writeAtomic(tmpPath: string, finalPath: string, content: string): void {
    const file = fs.openSync(tmpPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, content);
    } finally {
      fs.closeSync(file);
    }
    try {
      if (fs.accessSync(finalPath)) {
        fs.unlinkSync(finalPath);
      }
    } catch (_e) {
      // ignore
    }
    fs.renameSync(tmpPath, finalPath);
  }

  private static ensureDir(dir: string): void {
    try {
      fs.mkdirSync(dir, true);
    } catch (_e) {
      // exists
    }
  }

  private static abToString(buf: ArrayBuffer): string {
    // 文件中保存的是 HTTP UTF-8 原始字节。逐字节 String.fromCharCode
    // 会把中文 UTF-8 当作 Latin-1，304 命中后就会出现“é¿...”乱码。
    // 必须使用 HarmonyOS TextDecoder 按 UTF-8 解码，和正常网络响应保持一致。
    return new util.TextDecoder().decodeToString(new Uint8Array(buf));
  }

  /** 真 SHA-256（CryptoArchitectureKit），与 iOS CryptoKit 对齐。 */
  static sha256Hex(input: string): string {
    return FileHashUtil.sha256HexOfString(input);
  }
}

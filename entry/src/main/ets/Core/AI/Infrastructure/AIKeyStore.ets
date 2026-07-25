import { fileIo as fs } from '@kit.CoreFileKit';
import { HuksAesGcmCipher } from '../../../Foundation/Security/HuksAesGcmCipher';
import { Logger } from '../../../Foundation/Logging/Logger';
import { LogModule } from '../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../Foundation/Logging/LogEvent';

export class AIKeyStoreError extends Error {
  code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
    this.name = 'AIKeyStoreError';
  }
}

/**
 * API Key 仅存 HUKS 密文文件；RDB 只保存 secretRef。
 * 本地用户：ai-key:{accountId}:{providerId}
 * Pro overlay：ai-pro:{accountId}:{providerId}
 * 生产路径禁止明文 memory fallback；单测可 useMemoryOnly=true。
 */
export class AIKeyStore {
  private readonly rootDir: string;
  private readonly memoryOnly: Map<string, string> = new Map();
  private readonly useMemoryOnly: boolean;

  constructor(filesDir: string, useMemoryOnly: boolean = false) {
    this.rootDir = `${filesDir}/ai-secrets`;
    this.useMemoryOnly = useMemoryOnly;
    if (!useMemoryOnly) {
      AIKeyStore.ensureDir(this.rootDir);
    }
  }

  makeSecretRef(accountId: number, providerId: string): string {
    return `ai-key:${accountId}:${providerId}`;
  }

  makeProSecretRef(accountId: number, providerId: string): string {
    return `ai-pro:${accountId}:${providerId}`;
  }

  async put(accountId: number, providerId: string, apiKey: string): Promise<string> {
    return this.putByRef(this.makeSecretRef(accountId, providerId), accountId, apiKey);
  }

  async putPro(accountId: number, providerId: string, apiKey: string): Promise<string> {
    return this.putByRef(this.makeProSecretRef(accountId, providerId), accountId, apiKey);
  }

  private async putByRef(ref: string, accountId: number, apiKey: string): Promise<string> {
    if (!apiKey || apiKey.length === 0) {
      await this.delete(ref);
      return ref;
    }
    if (this.useMemoryOnly) {
      this.memoryOnly.set(ref, apiKey);
      return ref;
    }
    const path = this.pathFor(ref);
    const partPath = `${path}.part`;
    try {
      const payload = await HuksAesGcmCipher.encryptToPayload(apiKey);
      AIKeyStore.ensureDir(this.rootDir);
      const file = fs.openSync(partPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, payload);
      } finally {
        fs.closeSync(file);
      }
      try {
        if (fs.accessSync(path)) {
          fs.unlinkSync(path);
        }
      } catch (_e) {
        // ignore
      }
      fs.renameSync(partPath, path);
      const ok = new LogFields();
      ok.detail = `HUKS 写入成功 accountId=${accountId}`;
      Logger.info('ai.key.put.ok', LogModule.AI_CONFIG, ok);
      return ref;
    } catch (err) {
      try {
        if (fs.accessSync(partPath)) {
          fs.unlinkSync(partPath);
        }
      } catch (_e) {
        // ignore
      }
      const fail = new LogFields();
      fail.detail = 'HUKS 写入失败 code=secureStorageUnavailable';
      Logger.warn('ai.key.put.fail', LogModule.AI_CONFIG, fail);
      throw new AIKeyStoreError('secureStorageUnavailable', '无法安全保存 API Key');
    }
  }

  async get(secretRef: string): Promise<string | undefined> {
    if (!secretRef || secretRef.length === 0) {
      return undefined;
    }
    if (this.useMemoryOnly) {
      return this.memoryOnly.get(secretRef);
    }
    if (this.memoryOnly.has(secretRef)) {
      this.memoryOnly.delete(secretRef);
    }
    const path = this.pathFor(secretRef);
    try {
      if (!fs.accessSync(path)) {
        return undefined;
      }
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(path);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const text = AIKeyStore.bufferToString(buf);
      if (HuksAesGcmCipher.isHuksPayload(text)) {
        return await HuksAesGcmCipher.decryptFromPayload(text);
      }
      throw new AIKeyStoreError('secureStorageUnavailable', '密钥文件格式无效');
    } catch (err) {
      if (err instanceof AIKeyStoreError) {
        throw err;
      }
      return undefined;
    }
  }

  async hasSecret(secretRef?: string): Promise<boolean> {
    if (!secretRef || secretRef.length === 0) {
      return false;
    }
    if (this.useMemoryOnly) {
      return this.memoryOnly.has(secretRef);
    }
    try {
      return fs.accessSync(this.pathFor(secretRef));
    } catch (_e) {
      return false;
    }
  }

  async delete(secretRef: string): Promise<void> {
    this.memoryOnly.delete(secretRef);
    if (this.useMemoryOnly) {
      return;
    }
    const path = this.pathFor(secretRef);
    const partPath = `${path}.part`;
    try {
      if (fs.accessSync(partPath)) {
        fs.unlinkSync(partPath);
      }
    } catch (_e) {
      // ignore
    }
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (_e) {
      // ignore
    }
  }

  async deleteAccount(accountId: number): Promise<void> {
    const prefixes = [`ai-key:${accountId}:`, `ai-pro:${accountId}:`];
    const memKeys: string[] = [];
    this.memoryOnly.forEach((_v: string, k: string) => {
      memKeys.push(k);
    });
    for (let i = 0; i < memKeys.length; i++) {
      for (let p = 0; p < prefixes.length; p++) {
        if (memKeys[i].indexOf(prefixes[p]) === 0) {
          this.memoryOnly.delete(memKeys[i]);
        }
      }
    }
    if (this.useMemoryOnly) {
      return;
    }
    try {
      const files = fs.listFileSync(this.rootDir);
      for (let i = 0; i < files.length; i++) {
        const name = files[i];
        if (name.indexOf(`a${accountId}_`) === 0) {
          try {
            fs.unlinkSync(`${this.rootDir}/${name}`);
          } catch (_e) {
            // ignore
          }
        }
      }
    } catch (_e) {
      // ignore
    }
  }

  private pathFor(secretRef: string): string {
    const parts = secretRef.split(':');
    // ai-key:1:OPENAI 或 ai-pro:1:pro:DEEPSEEK
    const ns = parts.length > 0 ? parts[0] : 'ai-key';
    const accountId = parts.length > 1 ? parts[1] : '0';
    const providerId = parts.length > 2 ? parts.slice(2).join(':') : 'unknown';
    const nsTag = ns === 'ai-pro' ? 'pro' : 'key';
    const safe = providerId.replace(/[^A-Za-z0-9_-]/g, '_');
    return `${this.rootDir}/a${accountId}_${nsTag}_${safe}.enc`;
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

  private static bufferToString(buf: ArrayBuffer): string {
    const bytes = new Uint8Array(buf);
    let s = '';
    for (let i = 0; i < bytes.length; i++) {
      s += String.fromCharCode(bytes[i]);
    }
    return s;
  }
}

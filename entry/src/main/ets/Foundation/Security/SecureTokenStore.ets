import { fileIo as fs } from '@kit.CoreFileKit';
import { AuthTokens } from '../../Projects/Core/Networking/SupportNetworkModels';
import { NetworkLogger } from '../Logging/NetworkLogger';

/**
 * 安全 Token 快照存储：应用私有目录加密快照，禁止 Preferences。
 * 使用沙箱内 AES 密钥文件 + XOR 混淆防明文；可后续替换为 HUKS 包装密钥。
 */
export class SecureTokenStore {
  private readonly snapshotPath: string;
  private readonly keyPath: string;
  private readonly logger: NetworkLogger;

  constructor(filesDir: string, logger?: NetworkLogger) {
    this.logger = logger ?? new NetworkLogger();
    const dir = `${filesDir}/secure-auth`;
    SecureTokenStore.ensureDir(dir);
    this.snapshotPath = `${dir}/tokens.enc`;
    this.keyPath = `${dir}/.aes.key`;
  }

  async save(tokens: AuthTokens): Promise<void> {
    const json = JSON.stringify({
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAtMs: tokens.expiresAtMs,
      tokenType: tokens.tokenType
    });
    const key = this.loadOrCreateKey();
    const cipher = SecureTokenStore.encrypt(json, key);
    const file = fs.openSync(this.snapshotPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, cipher);
    } finally {
      fs.closeSync(file);
    }
  }

  async load(): Promise<AuthTokens | undefined> {
    try {
      if (!fs.accessSync(this.snapshotPath)) {
        return undefined;
      }
    } catch (_e) {
      return undefined;
    }
    try {
      const file = fs.openSync(this.snapshotPath, fs.OpenMode.READ_ONLY);
      let content = '';
      try {
        const stat = fs.statSync(this.snapshotPath);
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        content = SecureTokenStore.abToString(buf);
      } finally {
        fs.closeSync(file);
      }
      const key = this.loadOrCreateKey();
      const plain = SecureTokenStore.decrypt(content, key);
      const obj = JSON.parse(plain) as Record<string, string | number>;
      const accessToken = `${obj['accessToken'] ?? ''}`;
      const refreshToken = `${obj['refreshToken'] ?? ''}`;
      const expiresAtMs = Number(obj['expiresAtMs'] ?? 0);
      const tokenType = `${obj['tokenType'] ?? 'Bearer'}`;
      if (!accessToken || !refreshToken) {
        return undefined;
      }
      return new AuthTokens(accessToken, refreshToken, expiresAtMs, tokenType);
    } catch (e) {
      this.logger.warn(`SecureTokenStore load failed: ${e}`);
      return undefined;
    }
  }

  async clear(): Promise<void> {
    try {
      if (fs.accessSync(this.snapshotPath)) {
        fs.unlinkSync(this.snapshotPath);
      }
    } catch (_e) {
      // ignore
    }
  }

  private loadOrCreateKey(): Uint8Array {
    try {
      if (fs.accessSync(this.keyPath)) {
        const file = fs.openSync(this.keyPath, fs.OpenMode.READ_ONLY);
        try {
          const stat = fs.statSync(this.keyPath);
          const buf = new ArrayBuffer(stat.size);
          fs.readSync(file.fd, buf);
          return new Uint8Array(buf);
        } finally {
          fs.closeSync(file);
        }
      }
    } catch (_e) {
      // create
    }
    const key = new Uint8Array(32);
    for (let i = 0; i < 32; i++) {
      key[i] = Math.floor(Math.random() * 256);
    }
    const file = fs.openSync(this.keyPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, key.buffer);
    } finally {
      fs.closeSync(file);
    }
    return key;
  }

  private static ensureDir(dir: string): void {
    try {
      fs.mkdirSync(dir, true);
    } catch (_e) {
      // may already exist
    }
  }

  private static abToString(buf: ArrayBuffer): string {
    const bytes = new Uint8Array(buf);
    let s = '';
    for (let i = 0; i < bytes.length; i++) {
      s += String.fromCharCode(bytes[i]);
    }
    return s;
  }

  private static stringToBytes(text: string): Uint8Array {
    const arr = new Uint8Array(text.length);
    for (let i = 0; i < text.length; i++) {
      arr[i] = text.charCodeAt(i) & 0xff;
    }
    return arr;
  }

  private static encrypt(plain: string, key: Uint8Array): string {
    const plainBytes = SecureTokenStore.stringToBytes(plain);
    const out = new Uint8Array(plainBytes.length);
    for (let i = 0; i < plainBytes.length; i++) {
      out[i] = plainBytes[i] ^ key[i % key.length];
    }
    return SecureTokenStore.toBase64(out);
  }

  private static decrypt(cipherB64: string, key: Uint8Array): string {
    const cipher = SecureTokenStore.fromBase64(cipherB64);
    const out = new Uint8Array(cipher.length);
    for (let i = 0; i < cipher.length; i++) {
      out[i] = cipher[i] ^ key[i % key.length];
    }
    return SecureTokenStore.bytesToString(out);
  }

  private static toBase64(bytes: Uint8Array): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';
    for (let i = 0; i < bytes.length; i += 3) {
      const a = bytes[i];
      const b = i + 1 < bytes.length ? bytes[i + 1] : 0;
      const c = i + 2 < bytes.length ? bytes[i + 2] : 0;
      const triple = (a << 16) | (b << 8) | c;
      result += chars.charAt((triple >> 18) & 63);
      result += chars.charAt((triple >> 12) & 63);
      result += i + 1 < bytes.length ? chars.charAt((triple >> 6) & 63) : '=';
      result += i + 2 < bytes.length ? chars.charAt(triple & 63) : '=';
    }
    return result;
  }

  private static fromBase64(b64: string): Uint8Array {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const clean = b64.replace(/=+$/, '');
    const bytes: number[] = [];
    let buffer = 0;
    let bits = 0;
    for (let i = 0; i < clean.length; i++) {
      const idx = chars.indexOf(clean.charAt(i));
      if (idx < 0) {
        continue;
      }
      buffer = (buffer << 6) | idx;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        bytes.push((buffer >> bits) & 0xff);
      }
    }
    return new Uint8Array(bytes);
  }

  private static bytesToString(bytes: Uint8Array): string {
    let value = '';
    for (let i = 0; i < bytes.length; i++) {
      value += String.fromCharCode(bytes[i]);
    }
    return value;
  }
}

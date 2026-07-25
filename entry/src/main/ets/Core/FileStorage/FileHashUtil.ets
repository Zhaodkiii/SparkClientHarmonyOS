import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { SecureRandom } from '../../Foundation/Security/SecureRandom';

const COPY_CHUNK: number = 256 * 1024;

/**
 * 文件哈希与命名工具（不依赖 @aliyun/oss）。
 */
export class FileHashUtil {
  static sha256HexOfString(input: string): string {
    const md = cryptoFramework.createMd('SHA256');
    const encoder = new util.TextEncoder();
    const bytes = encoder.encodeInto(input);
    md.updateSync({ data: bytes });
    const digest = md.digestSync();
    return FileHashUtil.toHex(digest.data);
  }

  static accountIdHash(accountId: number): string {
    return FileHashUtil.sha256HexOfString(`account:${accountId}`);
  }

  static async md5HexOfFile(path: string): Promise<string> {
    const md = cryptoFramework.createMd('MD5');
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const buffer = new ArrayBuffer(COPY_CHUNK);
      let read = 0;
      do {
        read = fs.readSync(file.fd, buffer);
        if (read > 0) {
          const slice = new Uint8Array(buffer, 0, read);
          md.updateSync({ data: slice });
        }
      } while (read > 0);
      const digest = md.digestSync();
      return FileHashUtil.toHex(digest.data);
    } finally {
      fs.closeSync(file);
    }
  }

  static randomUuid(): string {
    const hex = SecureRandom.hex(16);
    return `${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}`;
  }

  static sanitizeFileName(fileName: string): string {
    // UTF-8 字节上限与控制字符规则统一由 ObjectKeyPolicy 负责。
    // 此处保留兼容入口，避免业务直接依赖策略类。
    let cleaned = '';
    for (let i = 0; i < fileName.length; i++) {
      const ch = fileName.charAt(i);
      const code = fileName.charCodeAt(i);
      if (ch === '/' || ch === '\\' || ch === ':' || ch === '*' || ch === '?' ||
        ch === '"' || ch === '<' || ch === '>' || ch === '|' || code < 32 || code === 127) {
        cleaned += '_';
      } else {
        cleaned += ch;
      }
    }
    cleaned = cleaned.replace(/\.\./g, '_').trim();
    if (cleaned.length === 0) {
      return 'unnamed_file';
    }
    return FileHashUtil.truncateUtf8Bytes(cleaned, 180);
  }

  /** UTF-8 字节截断（非 JS 字符数）。 */
  static truncateUtf8Bytes(text: string, maxBytes: number): string {
    const encoder = new util.TextEncoder();
    if (encoder.encodeInto(text).length <= maxBytes) {
      return text;
    }
    let end = text.length;
    while (end > 0 && encoder.encodeInto(text.substring(0, end)).length > maxBytes) {
      end -= 1;
    }
    const out = text.substring(0, end).trim();
    return out.length > 0 ? out : 'unnamed_file';
  }

  static mimeTypeForName(fileName: string): string {
    const lower = fileName.toLowerCase();
    const dot = lower.lastIndexOf('.');
    const ext = dot >= 0 ? lower.substring(dot + 1) : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'zip':
        return 'application/zip';
      case 'mp4':
        return 'video/mp4';
      case 'heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  static utcDayStamp(epochMs: number = Date.now()): string {
    const d = new Date(epochMs);
    const y = d.getUTCFullYear();
    const m = d.getUTCMonth() + 1;
    const day = d.getUTCDate();
    const mm = m < 10 ? `0${m}` : `${m}`;
    const dd = day < 10 ? `0${day}` : `${day}`;
    return `${y}${mm}${dd}`;
  }

  static makeObjectKey(fileUuid: string, sanitizedName: string, epochMs: number = Date.now()): string {
    const ymd = FileHashUtil.utcDayStamp(epochMs);
    return `SparkClient/${ymd}/${fileUuid}/${sanitizedName}`;
  }

  private static toHex(data: Uint8Array): string {
    let out = '';
    for (let i = 0; i < data.length; i++) {
      const h = data[i].toString(16);
      out += h.length === 1 ? `0${h}` : h;
    }
    return out;
  }
}

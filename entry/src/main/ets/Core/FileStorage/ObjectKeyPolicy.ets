import { util } from '@kit.ArkTS';
import { FileHashUtil } from './FileHashUtil';
import { FileTransferError } from './FileStorageModels';

/**
 * object key 前置策略：UTF-8 字节校验、控制字符、首位斜杠、完整 key 上限。
 * 失败在 PUT 前抛 sourceInvalid，不调用 OSS。
 */
export class ObjectKeyPolicy {
  static readonly POLICY_VERSION: string = 'v1';
  /** OSS Object 名最大长度（字节）。 */
  static readonly MAX_KEY_UTF8_BYTES: number = 1023;
  /** 文件名段 UTF-8 字节上限。 */
  static readonly MAX_NAME_UTF8_BYTES: number = 180;
  static readonly KEY_PREFIX: string = 'SparkClient';

  /**
   * 生成并校验业务 object key：`{prefix}/yyyyMMdd/fileUuid/sanitizedName`。
   * @param keyPrefix 服务端 object_key_prefix；空则 SparkClient
   */
  static makeValidatedKey(
    fileUuid: string,
    originalName: string,
    epochMs: number = Date.now(),
    keyPrefix: string = ''
  ): string {
    ObjectKeyPolicy.assertUuid(fileUuid);
    const safeName = ObjectKeyPolicy.sanitizeFileName(originalName);
    const prefix = ObjectKeyPolicy.normalizePrefix(keyPrefix);
    const key = `${prefix}/${FileHashUtil.utcDayStamp(epochMs)}/${fileUuid}/${safeName}`;
    ObjectKeyPolicy.assertKeyValid(key, prefix);
    return key;
  }

  /** 去掉首尾斜杠；空则默认 SparkClient。 */
  static normalizePrefix(raw: string): string {
    let p = raw.trim();
    while (p.indexOf('/') === 0) {
      p = p.substring(1);
    }
    while (p.length > 0 && p.charAt(p.length - 1) === '/') {
      p = p.substring(0, p.length - 1);
    }
    return p.length > 0 ? p : ObjectKeyPolicy.KEY_PREFIX;
  }

  static sanitizeFileName(fileName: string): string {
    return FileHashUtil.sanitizeFileName(fileName);
  }

  static assertKeyValid(objectKey: string, expectedPrefix: string = ObjectKeyPolicy.KEY_PREFIX): void {
    if (objectKey.length === 0) {
      throw new FileTransferError('sourceInvalid', 'preparing', '该文件无法上传，请重新选择。', false);
    }
    const first = objectKey.charAt(0);
    if (first === '/' || first === '\\') {
      throw new FileTransferError('sourceInvalid', 'preparing', '该文件无法上传，请重新选择。', false);
    }
    for (let i = 0; i < objectKey.length; i++) {
      const code = objectKey.charCodeAt(i);
      if (code < 32 || code === 127) {
        throw new FileTransferError('sourceInvalid', 'preparing', '该文件无法上传，请重新选择。', false);
      }
    }
    const bytes = ObjectKeyPolicy.utf8ByteLength(objectKey);
    if (bytes <= 0 || bytes > ObjectKeyPolicy.MAX_KEY_UTF8_BYTES) {
      throw new FileTransferError('sourceInvalid', 'preparing', '该文件无法上传，请重新选择。', false);
    }
    const prefix = ObjectKeyPolicy.normalizePrefix(expectedPrefix);
    if (objectKey.indexOf(`${prefix}/`) !== 0) {
      throw new FileTransferError('sourceInvalid', 'preparing', '该文件无法上传，请重新选择。', false);
    }
  }

  static fingerprint(objectKey: string): string {
    if (objectKey.length === 0) {
      return `${ObjectKeyPolicy.POLICY_VERSION}:empty:keyBytes=0`;
    }
    const digest = FileHashUtil.sha256HexOfString(objectKey);
    // keyBytes = object key 的 UTF-8 长度，不是文件内容大小。
    const keyBytes = ObjectKeyPolicy.utf8ByteLength(objectKey);
    return `${ObjectKeyPolicy.POLICY_VERSION}:${digest.substring(0, 16)}:keyBytes=${keyBytes}`;
  }

  static utf8ByteLength(text: string): number {
    const encoder = new util.TextEncoder();
    return encoder.encodeInto(text).length;
  }

  static truncateUtf8Bytes(text: string, maxBytes: number): string {
    if (ObjectKeyPolicy.utf8ByteLength(text) <= maxBytes) {
      return text;
    }
    let end = text.length;
    while (end > 0 && ObjectKeyPolicy.utf8ByteLength(text.substring(0, end)) > maxBytes) {
      end -= 1;
    }
    const out = text.substring(0, end).trim();
    return out.length > 0 ? out : 'unnamed_file';
  }

  private static assertUuid(fileUuid: string): void {
    const cleaned = fileUuid.trim();
    if (!/^[0-9a-fA-F-]{32,40}$/.test(cleaned) || cleaned.indexOf('-') < 0) {
      throw new FileTransferError('sourceInvalid', 'preparing', '该文件无法上传，请重新选择。', false);
    }
  }
}

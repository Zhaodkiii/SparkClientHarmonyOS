import { huks } from '@kit.UniversalKeystoreKit';
import { SecureRandom } from './SecureRandom';

const KEY_ALIAS: string = 'SupportClient.DeviceCredential.AES';
const AAD_TEXT: string = 'SupportClient.device.cred';
const TAG_LEN: number = 16;

/**
 * HUKS AES-GCM：密钥不出 HUKS；文件侧只存 nonce+密文。
 */
export class HuksAesGcmCipher {
  static async ensureKey(): Promise<void> {
    const exists = await HuksAesGcmCipher.keyExists();
    if (exists) {
      return;
    }
    const options: huks.HuksOptions = {
      properties: [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        {
          tag: huks.HuksTag.HUKS_TAG_PURPOSE,
          value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
        },
        { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
        { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE }
      ]
    };
    await huks.generateKeyItem(KEY_ALIAS, options);
  }

  static async encryptToPayload(plainText: string): Promise<string> {
    await HuksAesGcmCipher.ensureKey();
    const nonce = SecureRandom.bytes(12);
    const plain = HuksAesGcmCipher.stringToBytes(plainText);
    const encProps: Array<huks.HuksParam> = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
      { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: HuksAesGcmCipher.stringToBytes(AAD_TEXT) }
    ];
    const options: huks.HuksOptions = { properties: encProps, inData: plain };
    const handleResult = await huks.initSession(KEY_ALIAS, options);
    const finished = await huks.finishSession(handleResult.handle, options);
    const cipher = finished.outData as Uint8Array;
    const payload: Record<string, string | number> = {};
    payload['v'] = 1;
    payload['nonce'] = HuksAesGcmCipher.toBase64(nonce);
    payload['cipher'] = HuksAesGcmCipher.toBase64(cipher);
    return JSON.stringify(payload);
  }

  static async decryptFromPayload(payloadJson: string): Promise<string> {
    await HuksAesGcmCipher.ensureKey();
    const obj = JSON.parse(payloadJson) as Record<string, string | number>;
    const nonceB64 = `${obj['nonce'] ?? ''}`;
    const cipherB64 = `${obj['cipher'] ?? ''}`;
    const nonce = HuksAesGcmCipher.fromBase64(nonceB64);
    const cipher = HuksAesGcmCipher.fromBase64(cipherB64);
    if (cipher.length < TAG_LEN) {
      throw new Error('HuksAesGcmCipher: cipher too short');
    }
    const aeTag = cipher.slice(cipher.length - TAG_LEN);
    const encBody = cipher.slice(0, cipher.length - TAG_LEN);
    const decProps: Array<huks.HuksParam> = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
      { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: HuksAesGcmCipher.stringToBytes(AAD_TEXT) },
      { tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: aeTag }
    ];
    const options: huks.HuksOptions = { properties: decProps, inData: encBody };
    const handleResult = await huks.initSession(KEY_ALIAS, options);
    const finished = await huks.finishSession(handleResult.handle, options);
    return HuksAesGcmCipher.bytesToString(finished.outData as Uint8Array);
  }

  static isHuksPayload(text: string): boolean {
    if (!text || text.length === 0) {
      return false;
    }
    try {
      const obj = JSON.parse(text) as Record<string, Object>;
      return obj['v'] === 1 && typeof obj['nonce'] === 'string' && typeof obj['cipher'] === 'string';
    } catch (_e) {
      return false;
    }
  }

  private static async keyExists(): Promise<boolean> {
    try {
      const options: huks.HuksOptions = { properties: [] };
      return await huks.isKeyItemExist(KEY_ALIAS, options);
    } catch (_e) {
      return false;
    }
  }

  private static stringToBytes(text: string): Uint8Array {
    const arr = new Uint8Array(text.length);
    for (let i = 0; i < text.length; i++) {
      arr[i] = text.charCodeAt(i) & 0xff;
    }
    return arr;
  }

  private static bytesToString(bytes: Uint8Array): string {
    let value = '';
    for (let i = 0; i < bytes.length; i++) {
      value += String.fromCharCode(bytes[i]);
    }
    return value;
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
}

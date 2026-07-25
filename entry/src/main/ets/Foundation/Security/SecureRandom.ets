import { cryptoFramework } from '@kit.CryptoArchitectureKit';

/**
 * 安全随机数（替代 Math.random）。
 */
export class SecureRandom {
  static bytes(length: number): Uint8Array {
    const rand = cryptoFramework.createRandom();
    const data = rand.generateRandomSync(length);
    return data.data;
  }

  static hex(byteLen: number): string {
    const raw = SecureRandom.bytes(byteLen);
    let out = '';
    for (let i = 0; i < raw.length; i++) {
      const h = raw[i].toString(16);
      out += h.length === 1 ? `0${h}` : h;
    }
    return out;
  }
}

/**
 * 从 JWT access token payload 解析 exp（秒 → 毫秒）。
 */
export class JWTExpParser {
  static parseExpMs(accessToken: string): number | undefined {
    try {
      const parts = accessToken.split('.');
      if (parts.length < 2) {
        return undefined;
      }
      const payloadJson = JWTExpParser.base64UrlDecode(parts[1]);
      const payload = JSON.parse(payloadJson) as Record<string, number>;
      const exp = payload['exp'];
      if (typeof exp !== 'number' || exp <= 0) {
        return undefined;
      }
      return exp * 1000;
    } catch (_e) {
      return undefined;
    }
  }

  private static base64UrlDecode(input: string): string {
    let base64 = input.replace(/-/g, '+').replace(/_/g, '/');
    const pad = base64.length % 4;
    if (pad === 2) {
      base64 += '==';
    } else if (pad === 3) {
      base64 += '=';
    } else if (pad === 1) {
      base64 += '===';
    }
    const binary = JWTExpParser.decodeBase64(base64);
    let out = '';
    for (let i = 0; i < binary.length; i++) {
      out += String.fromCharCode(binary[i]);
    }
    return out;
  }

  private static decodeBase64(base64: string): number[] {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const bytes: number[] = [];
    let buffer = 0;
    let bits = 0;
    for (let i = 0; i < base64.length; i++) {
      const c = base64.charAt(i);
      if (c === '=') {
        break;
      }
      const idx = chars.indexOf(c);
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
    return bytes;
  }
}

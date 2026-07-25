import { AuthTokens, BackendErrorInfo, NetworkResponse, SupportNetworkError, normalizeMsg } from '../../SupportNetworkModels';
import { SessionInvalidation } from '../../SessionInvalidation';

export class SupportAPIResponseDecoder {
  static decodeWrappedData<T>(
    response: NetworkResponse,
    mapper: (data: Object | null) => T,
    invalidateSession: boolean = true
  ): T {
    let parsed: Object;
    try {
      parsed = JSON.parse(response.bodyText || 'null') as Object;
    } catch (e) {
      throw SupportNetworkError.decoding(`JSON parse failed: ${e}`, response.requestId);
    }
    if (!parsed || typeof parsed !== 'object') {
      throw SupportNetworkError.decoding('Expected object envelope', response.requestId);
    }
    const envelope = parsed as Record<string, Object | number | string>;
    if (Object.keys(envelope).indexOf('code') < 0) {
      throw SupportNetworkError.decoding('Missing code in wrapped response', response.requestId);
    }
    const code = Number(envelope['code']);
    const msg = normalizeMsg(envelope['msg'] as Object | string);
    if (code !== 0) {
      const backend = new BackendErrorInfo(code, msg, envelope['msg'] as Object);
      if (invalidateSession) {
        SessionInvalidation.postIfNeeded(response.statusCode, code, msg, 'SupportAPIResponseDecoder');
      }
      throw SupportNetworkError.business(backend, response.statusCode, response.requestId);
    }
    const data = (envelope['data'] ?? null) as Object | null;
    try {
      return mapper(data);
    } catch (e) {
      throw SupportNetworkError.decoding(`Data mapping failed: ${e}`, response.requestId);
    }
  }

  static decodeDirect<T>(response: NetworkResponse, mapper: (root: Object) => T): T {
    let parsed: Object;
    try {
      parsed = JSON.parse(response.bodyText || 'null') as Object;
    } catch (e) {
      throw SupportNetworkError.decoding(`JSON parse failed: ${e}`, response.requestId);
    }
    if (!parsed || typeof parsed !== 'object') {
      throw SupportNetworkError.decoding('Expected object root', response.requestId);
    }
    try {
      return mapper(parsed);
    } catch (e) {
      throw SupportNetworkError.decoding(`Direct mapping failed: ${e}`, response.requestId);
    }
  }

  static parseBackendError(bodyText: string): BackendErrorInfo | undefined {
    try {
      const parsed = JSON.parse(bodyText) as Record<string, Object | number | string>;
      if (typeof parsed['code'] !== 'number' && typeof parsed['code'] !== 'string') {
        return undefined;
      }
      return new BackendErrorInfo(Number(parsed['code']), normalizeMsg(parsed['msg'] as Object | string),
        parsed['msg'] as Object);
    } catch (_e) {
      return undefined;
    }
  }

  static asRecord(data: Object | null): Record<string, Object | string | number | boolean | null> {
    if (!data || typeof data !== 'object') {
      return {};
    }
    return data as Record<string, Object | string | number | boolean | null>;
  }

  static str(obj: Record<string, Object | string | number | boolean | null>, key: string, fallback: string = ''): string {
    const v = obj[key];
    if (v === null || v === undefined) {
      return fallback;
    }
    return `${v}`;
  }

  static strAny(
    obj: Record<string, Object | string | number | boolean | null>,
    keys: string[],
    fallback: string = ''
  ): string {
    for (let i = 0; i < keys.length; i++) {
      const v = obj[keys[i]];
      if (v !== null && v !== undefined) {
        return `${v}`;
      }
    }
    return fallback;
  }

  static num(obj: Record<string, Object | string | number | boolean | null>, key: string, fallback: number = 0): number {
    const v = obj[key];
    if (typeof v === 'number') {
      return v;
    }
    if (typeof v === 'string' && v.length > 0) {
      const n = Number(v);
      return Number.isNaN(n) ? fallback : n;
    }
    return fallback;
  }

  static numAny(
    obj: Record<string, Object | string | number | boolean | null>,
    keys: string[],
    fallback: number = 0
  ): number {
    for (let i = 0; i < keys.length; i++) {
      const value = SupportAPIResponseDecoder.optNum(obj, keys[i]);
      if (value !== undefined) {
        return value;
      }
    }
    return fallback;
  }

  static bool(obj: Record<string, Object | string | number | boolean | null>, key: string, fallback: boolean = false): boolean {
    const v = obj[key];
    if (typeof v === 'boolean') {
      return v;
    }
    return fallback;
  }

  static boolAny(
    obj: Record<string, Object | string | number | boolean | null>,
    keys: string[],
    fallback: boolean = false
  ): boolean {
    for (let i = 0; i < keys.length; i++) {
      const value = SupportAPIResponseDecoder.optBool(obj, keys[i]);
      if (value !== undefined) {
        return value;
      }
    }
    return fallback;
  }

  static optStr(obj: Record<string, Object | string | number | boolean | null>, key: string): string | undefined {
    const v = obj[key];
    if (v === null || v === undefined) {
      return undefined;
    }
    return `${v}`;
  }

  static optStrAny(
    obj: Record<string, Object | string | number | boolean | null>,
    keys: string[]
  ): string | undefined {
    for (let i = 0; i < keys.length; i++) {
      const value = SupportAPIResponseDecoder.optStr(obj, keys[i]);
      if (value !== undefined) {
        return value;
      }
    }
    return undefined;
  }

  static optNum(obj: Record<string, Object | string | number | boolean | null>, key: string): number | undefined {
    const v = obj[key];
    if (v === null || v === undefined) {
      return undefined;
    }
    if (typeof v === 'number') {
      return v;
    }
    if (typeof v === 'string' && v.length > 0) {
      const n = Number(v);
      return Number.isNaN(n) ? undefined : n;
    }
    return undefined;
  }

  static optNumAny(
    obj: Record<string, Object | string | number | boolean | null>,
    keys: string[]
  ): number | undefined {
    for (let i = 0; i < keys.length; i++) {
      const value = SupportAPIResponseDecoder.optNum(obj, keys[i]);
      if (value !== undefined) {
        return value;
      }
    }
    return undefined;
  }

  static optBool(obj: Record<string, Object | string | number | boolean | null>, key: string): boolean | undefined {
    const v = obj[key];
    if (typeof v === 'boolean') {
      return v;
    }
    return undefined;
  }

  static optBoolAny(
    obj: Record<string, Object | string | number | boolean | null>,
    keys: string[]
  ): boolean | undefined {
    for (let i = 0; i < keys.length; i++) {
      const value = SupportAPIResponseDecoder.optBool(obj, keys[i]);
      if (value !== undefined) {
        return value;
      }
    }
    return undefined;
  }

  static tokensFromLogin(obj: Record<string, Object | string | number | boolean | null>): AuthTokens {
    const access = SupportAPIResponseDecoder.strAny(obj, ['accessToken', 'access_token', 'access']);
    const refresh = SupportAPIResponseDecoder.strAny(obj, ['refreshToken', 'refresh_token', 'refresh']);
    const expiresIn = SupportAPIResponseDecoder.numAny(obj, ['expiresIn', 'expires_in'], 0);
    const tokenType = SupportAPIResponseDecoder.strAny(obj, ['tokenType', 'token_type'], 'Bearer') || 'Bearer';
    return new AuthTokens(access, refresh, Date.now() + expiresIn * 1000, tokenType);
  }
}

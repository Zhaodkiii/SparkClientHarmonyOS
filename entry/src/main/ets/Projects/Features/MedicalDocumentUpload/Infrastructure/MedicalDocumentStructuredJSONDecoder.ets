import { MedicalDocumentTypeResponseDecoder } from './MedicalDocumentTypeResponseDecoder';

/** JSON 解码结果：对象或数组均保留规范化字符串。 */
export class MedicalDocumentStructuredJSONDecodeResult {
  ok: boolean = false;
  canonicalJSON: string = '';
  isArray: boolean = false;
  fieldPath: string = '';
  errorMessage: string = '';
  /** 顶层对象字段（数组时为空）。 */
  objectFields: Map<string, string> = new Map();
}

/**
 * 结构化 JSON 解码器：剥离 code fence，严格 parse，不允许弱判断。
 * 对齐 iOS StructuredJSONStreamDecoder 的稳定性目标（本阶段不做 Codable 强类型）。
 */
export class MedicalDocumentStructuredJSONDecoder {
  decode(rawText: string): MedicalDocumentStructuredJSONDecodeResult {
    const result = new MedicalDocumentStructuredJSONDecodeResult();
    if (rawText.trim().length === 0) {
      result.errorMessage = 'AI 输出为空';
      result.fieldPath = 'root';
      return result;
    }

    const stripped = MedicalDocumentTypeResponseDecoder.stripCodeFence(rawText).trim();
    let payload: Object | Object[] | string | number | boolean | null = null;
    try {
      payload = JSON.parse(stripped) as Object | Object[] | string | number | boolean | null;
    } catch (_e) {
      const startObj = stripped.indexOf('{');
      const startArr = stripped.indexOf('[');
      let start = -1;
      let end = -1;
      if (startObj >= 0 && (startArr < 0 || startObj < startArr)) {
        start = startObj;
        end = stripped.lastIndexOf('}');
      } else if (startArr >= 0) {
        start = startArr;
        end = stripped.lastIndexOf(']');
      }
      if (start < 0 || end <= start) {
        result.errorMessage = 'AI 输出不是合法 JSON';
        result.fieldPath = 'root';
        return result;
      }
      try {
        payload = JSON.parse(stripped.substring(start, end + 1)) as Object | Object[];
      } catch (__e) {
        result.errorMessage = 'AI 输出 JSON 解析失败';
        result.fieldPath = 'root';
        return result;
      }
    }

    if (payload === null || typeof payload === 'string' || typeof payload === 'number' ||
      typeof payload === 'boolean') {
      result.errorMessage = '抽取结果必须是 JSON 对象或数组';
      result.fieldPath = 'root';
      return result;
    }

    if (Array.isArray(payload)) {
      result.isArray = true;
      result.canonicalJSON = JSON.stringify(payload);
      result.ok = true;
      return result;
    }

    // 普通对象
    result.isArray = false;
    result.canonicalJSON = JSON.stringify(payload);
    const record = payload as Record<string, Object | string | number | boolean | null>;
    const keys = Object.keys(record);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = record[key];
      if (value === null || value === undefined) {
        result.objectFields.set(key, '');
      } else if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
        result.objectFields.set(key, `${value}`);
      } else {
        result.objectFields.set(key, JSON.stringify(value));
      }
    }
    result.ok = true;
    return result;
  }
}

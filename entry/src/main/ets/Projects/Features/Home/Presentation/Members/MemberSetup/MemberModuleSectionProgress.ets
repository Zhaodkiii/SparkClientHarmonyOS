/**
 * 模块小节进度编解码。与 iOS MemberModuleSectionProgressCodec 对齐。
 * extra.section_progress 内存嵌套 JSON 字符串。
 */
export enum MemberModuleSectionStatus {
  NOT_STARTED = 'notStarted',
  INCOMPLETE = 'incomplete',
  COMPLETED = 'completed'
}

export class MemberModuleSectionProgressRecord {
  sectionCode: string = '';
  summary: string = '';
  status: MemberModuleSectionStatus = MemberModuleSectionStatus.NOT_STARTED;
}

export class MemberModuleSectionProgressCodec {
  static readonly EXTRA_KEY: string = 'section_progress';

  static decode(extra?: Record<string, string>): Record<string, MemberModuleSectionProgressRecord> {
    const out: Record<string, MemberModuleSectionProgressRecord> = {};
    if (!extra) {
      return out;
    }
    const json = extra[MemberModuleSectionProgressCodec.EXTRA_KEY];
    if (!json || json.length === 0) {
      return out;
    }
    try {
      const parsed = JSON.parse(json) as Object;
      if (Array.isArray(parsed)) {
        const arr = parsed as Object[];
        for (let i = 0; i < arr.length; i++) {
          const rec = MemberModuleSectionProgressCodec.recordFromObject(arr[i]);
          if (rec.sectionCode.length > 0) {
            out[rec.sectionCode] = rec;
          }
        }
        return out;
      }
      if (parsed && typeof parsed === 'object') {
        const map = parsed as Record<string, Object>;
        const keys = Object.keys(map);
        for (let i = 0; i < keys.length; i++) {
          const k = keys[i];
          const rec = MemberModuleSectionProgressCodec.recordFromObject(map[k]);
          if (rec.sectionCode.length === 0) {
            rec.sectionCode = k;
          }
          out[rec.sectionCode] = rec;
        }
      }
    } catch (_e) {
      return out;
    }
    return out;
  }

  static encode(records: Record<string, MemberModuleSectionProgressRecord>): string {
    const keys = Object.keys(records);
    if (keys.length === 0) {
      return '{}';
    }
    const map: Record<string, Object> = {};
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      const r = records[k];
      const item: Record<string, string> = {};
      item['sectionCode'] = r.sectionCode;
      item['summary'] = r.summary;
      item['status'] = r.status;
      map[k] = item;
    }
    try {
      return JSON.stringify(map);
    } catch (_e) {
      return '{}';
    }
  }

  static mergeIntoExtra(
    extra: Record<string, string> | undefined,
    progressMap: Record<string, MemberModuleSectionProgressRecord>
  ): Record<string, string> {
    const merged: Record<string, string> = {};
    if (extra) {
      const keys = Object.keys(extra);
      for (let i = 0; i < keys.length; i++) {
        merged[keys[i]] = extra[keys[i]];
      }
    }
    merged[MemberModuleSectionProgressCodec.EXTRA_KEY] =
      MemberModuleSectionProgressCodec.encode(progressMap);
    return merged;
  }

  private static recordFromObject(raw: Object | null | undefined): MemberModuleSectionProgressRecord {
    const rec = new MemberModuleSectionProgressRecord();
    if (!raw || typeof raw !== 'object') {
      return rec;
    }
    const obj = raw as Record<string, Object | string>;
    rec.sectionCode = `${obj['sectionCode'] ?? ''}`;
    rec.summary = `${obj['summary'] ?? ''}`;
    const statusRaw = `${obj['status'] ?? ''}`;
    if (statusRaw === MemberModuleSectionStatus.COMPLETED) {
      rec.status = MemberModuleSectionStatus.COMPLETED;
    } else if (statusRaw === MemberModuleSectionStatus.INCOMPLETE) {
      rec.status = MemberModuleSectionStatus.INCOMPLETE;
    } else {
      rec.status = MemberModuleSectionStatus.NOT_STARTED;
    }
    return rec;
  }
}

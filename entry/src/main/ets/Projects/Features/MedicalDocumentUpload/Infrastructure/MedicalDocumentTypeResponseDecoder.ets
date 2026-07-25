import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import {
  MedicalDocumentTypeResolutionFactory,
  MedicalDocumentTypeResolutionSource
} from '../Domain/MedicalDocumentTypeResolverProtocol';
import { MedicalDocumentTypeResolution } from '../Domain/MedicalDocumentTypedModels';

/**
 * AI 类型判定 JSON 解码：剥离 Markdown 代码块，仅接受白名单 kind。
 * 对齐 iOS DefaultMedicalDocumentTypeResolver.parseAIResponse。
 */
export class MedicalDocumentTypeResponseDecoder {
  decode(rawText: string): MedicalDocumentTypeResolution | undefined {
    if (rawText.trim().length === 0) {
      return undefined;
    }
    const jsonText = MedicalDocumentTypeResponseDecoder.stripCodeFence(rawText).trim();
    let parsed: Record<string, Object | string | number | undefined> | undefined = undefined;
    try {
      parsed = JSON.parse(jsonText) as Record<string, Object | string | number | undefined>;
    } catch (_e) {
      // 尝试截取第一个 { ... }
      const start = jsonText.indexOf('{');
      const end = jsonText.lastIndexOf('}');
      if (start < 0 || end <= start) {
        return undefined;
      }
      try {
        parsed = JSON.parse(jsonText.substring(start, end + 1)) as
          Record<string, Object | string | number | undefined>;
      } catch (__e) {
        return undefined;
      }
    }
    if (parsed === undefined) {
      return undefined;
    }

    const kindRaw = `${parsed['kind'] ?? parsed['type'] ?? ''}`.trim();
    const kind = MedicalDocumentTypeResponseDecoder.mapKind(kindRaw);
    if (kind === undefined) {
      return undefined;
    }

    let confidence = 0.5;
    const confRaw = parsed['confidence'];
    if (typeof confRaw === 'number') {
      confidence = confRaw;
    } else if (typeof confRaw === 'string') {
      const n = Number(confRaw);
      if (!(n !== n)) {
        confidence = n;
      }
    }
    confidence = MedicalDocumentTypeResolutionFactory.clamp(confidence);
    const reason = `${parsed['reason'] ?? 'ai_type_recognition'}`.trim();
    return MedicalDocumentTypeResolutionFactory.make(
      kind,
      MedicalDocumentTypeResolutionSource.AI,
      reason.length > 0 ? reason : 'ai_type_recognition',
      confidence
    );
  }

  static mapKind(raw: string): MedicalDocumentKind | undefined {
    const key = raw.trim().toLowerCase().replace(/-/g, '_');
    switch (key) {
      case 'case_document':
      case 'casedocument':
      case 'case':
        return MedicalDocumentKind.CASE_DOCUMENT;
      case 'health_exam_report':
      case 'healthexamreport':
      case 'health_exam':
        return MedicalDocumentKind.HEALTH_EXAM_REPORT;
      case 'medical_report':
      case 'medicalreport':
      case 'examination_report':
        return MedicalDocumentKind.MEDICAL_REPORT;
      case 'prescription':
        return MedicalDocumentKind.PRESCRIPTION;
      case 'medication_plan':
      case 'medicationplan':
      case 'medication':
        return MedicalDocumentKind.MEDICATION_PLAN;
      case 'medicine_box':
      case 'medicinebox':
        return MedicalDocumentKind.MEDICINE_BOX;
      default:
        return undefined;
    }
  }

  static stripCodeFence(text: string): string {
    let out = text.trim();
    if (out.indexOf('```') < 0) {
      return out;
    }
    // ```json ... ``` 或 ``` ... ```
    const fenceStart = out.indexOf('```');
    if (fenceStart >= 0) {
      let body = out.substring(fenceStart + 3);
      const nl = body.indexOf('\n');
      if (nl >= 0) {
        const maybeLang = body.substring(0, nl).trim().toLowerCase();
        if (maybeLang === 'json' || maybeLang === '') {
          body = body.substring(nl + 1);
        }
      }
      const fenceEnd = body.lastIndexOf('```');
      if (fenceEnd >= 0) {
        body = body.substring(0, fenceEnd);
      }
      out = body.trim();
    }
    return out;
  }
}

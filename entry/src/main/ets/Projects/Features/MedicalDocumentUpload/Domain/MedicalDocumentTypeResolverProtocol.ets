import { AIRuntimeCancellationToken } from '../../../../Core/AI/Runtime/AIRuntimeCancellation';
import { MedicalDocumentKind, medicalDocumentKindPickerLabel } from './MedicalDocumentKind';
import { MedicalDocumentTypeResolution } from './MedicalDocumentTypedModels';

/** 对齐 iOS MedicalDocumentTypeResolution.Source：仅 manual / localRules / ai。 */
export enum MedicalDocumentTypeResolutionSource {
  MANUAL = 'manual',
  LOCAL_RULES = 'localRules',
  AI = 'ai'
}

export function medicalDocumentTypeSourceLabel(source: MedicalDocumentTypeResolutionSource): string {
  switch (source) {
    case MedicalDocumentTypeResolutionSource.MANUAL:
      return '手动选择';
    case MedicalDocumentTypeResolutionSource.LOCAL_RULES:
      return '本地规则';
    case MedicalDocumentTypeResolutionSource.AI:
      return 'AI 判定';
    default:
      return `${source}`;
  }
}

/** 类型判定协议：Default / Local / 测试桩统一入口。 */
export interface MedicalDocumentTypeResolving {
  resolve(
    selectedKind: MedicalDocumentKind,
    mergedOCRText: string,
    cancellationToken?: AIRuntimeCancellationToken
  ): Promise<MedicalDocumentTypeResolution>;
}

/** 结果工厂：统一 confidence / source / reason。 */
export class MedicalDocumentTypeResolutionFactory {
  static make(
    kind: MedicalDocumentKind,
    source: MedicalDocumentTypeResolutionSource,
    reason: string,
    confidence: number
  ): MedicalDocumentTypeResolution {
    const resolution = new MedicalDocumentTypeResolution();
    resolution.kind = kind;
    resolution.kindLabel = medicalDocumentKindPickerLabel(kind);
    resolution.source = source;
    resolution.sourceLabel = medicalDocumentTypeSourceLabel(source);
    resolution.confidence = MedicalDocumentTypeResolutionFactory.clamp(confidence);
    resolution.reason = reason;
    return resolution;
  }

  static manual(kind: MedicalDocumentKind): MedicalDocumentTypeResolution {
    return MedicalDocumentTypeResolutionFactory.make(
      kind,
      MedicalDocumentTypeResolutionSource.MANUAL,
      'manual_selected',
      1
    );
  }

  static aiFallbackDefault(): MedicalDocumentTypeResolution {
    return MedicalDocumentTypeResolutionFactory.make(
      MedicalDocumentKind.MEDICAL_REPORT,
      MedicalDocumentTypeResolutionSource.AI,
      'ai_fallback_default',
      0.4
    );
  }

  static clamp(value: number): number {
    if (value < 0) {
      return 0;
    }
    if (value > 1) {
      return 1;
    }
    return value;
  }
}
